<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\FixedAssets\AssetCatalogService;
use App\Services\FixedAssets\AssetCountService;
use App\Services\FixedAssets\AssetQueryService;
use App\Services\FixedAssets\DepreciationRunService;
use App\Services\FixedAssets\FixedAssetService;
use App\Support\FinanceAccess;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** Fixed assets API (finance/assets/*). See docs/finance/FIXED_ASSETS_AND_PARTNERS.md. */
class FixedAssetController extends Controller
{
    public function __construct(
        private readonly FixedAssetService $assets,
        private readonly AssetQueryService $queries,
        private readonly AssetCatalogService $catalog,
        private readonly DepreciationRunService $runs,
        private readonly AssetCountService $counts,
    ) {}

    // ------------------------------------------------------------ settings / catalog

    public function settings(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->catalog->settings(TenantContext::id($request))]);
    }

    public function saveSettings(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate(['depreciationFrequency' => ['required', 'in:monthly,quarterly,semiannual,annual'], 'defaultMethod' => ['nullable', 'in:straight_line,declining_balance,none']]);
        $this->catalog->saveSettings($tenant, $data, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->catalog->settings($tenant)]);
    }

    public function categories(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->catalog->categories(TenantContext::id($request))]);
    }

    public function storeCategory(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->catalog->saveCategory($tenant, $this->categoryData($request), null, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->catalog->categories($tenant)], 201);
    }

    public function updateCategory(Request $request, int $category): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->catalog->saveCategory($tenant, $this->categoryData($request), $category, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->catalog->categories($tenant)]);
    }

    public function deleteCategory(Request $request, int $category): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->catalog->deleteCategory($tenant, $category);

        return response()->json(['data' => $this->catalog->categories($tenant)]);
    }

    public function seedCategories(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $created = $this->catalog->seedFromChart($tenant, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->catalog->categories($tenant), 'meta' => ['created' => $created]]);
    }

    public function locations(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->catalog->locations(TenantContext::id($request))]);
    }

    public function storeLocation(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->catalog->saveLocation($tenant, $this->locationData($request), null);

        return response()->json(['data' => $this->catalog->locations($tenant)], 201);
    }

    public function updateLocation(Request $request, int $location): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->catalog->saveLocation($tenant, $this->locationData($request), $location);

        return response()->json(['data' => $this->catalog->locations($tenant)]);
    }

    // ------------------------------------------------------------ assets

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $filters = $request->validate(['q' => ['nullable', 'string', 'max:120'], 'status' => ['nullable', 'in:draft,active,fully_depreciated,disposed'],
            'categoryId' => ['nullable', 'integer'], 'branchId' => ['nullable', 'string'], 'asOf' => ['nullable', 'date_format:Y-m-d'], 'includeDisposed' => ['nullable', 'boolean']]);
        [$owner, $branches] = $this->scope($request, $tenant);

        return response()->json(['data' => $this->queries->register($tenant, $filters, $branches, $owner)]);
    }

    public function show(Request $request, int $asset): JsonResponse
    {
        return response()->json(['data' => $this->queries->card(TenantContext::id($request), $asset)]);
    }

    public function store(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $id = $this->assets->create($request, $tenant, $this->assetData($request), FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->queries->card($tenant, $id)], 201);
    }

    public function update(Request $request, int $asset): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->assets->update($request, $tenant, $asset, $this->assetData($request, true), FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->queries->card($tenant, $asset)]);
    }

    public function destroy(Request $request, int $asset): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->assets->delete($request, $tenant, $asset, FinancialActor::id($request, $tenant));

        return response()->json(['data' => ['deleted' => true]]);
    }

    public function activate(Request $request, int $asset): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate(['generateEntry' => ['nullable', 'boolean']] + $this->paymentRules());
        $this->assets->activate($request, $tenant, $asset, ['generateEntry' => $data['generateEntry'] ?? true, 'payments' => $data['payments'] ?? null], FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->queries->card($tenant, $asset)]);
    }

    public function addition(Request $request, int $asset): JsonResponse
    {
        return $this->outlay($request, $asset, 'addition');
    }

    public function maintenance(Request $request, int $asset): JsonResponse
    {
        return $this->outlay($request, $asset, 'maintenance');
    }

    public function expense(Request $request, int $asset): JsonResponse
    {
        return $this->outlay($request, $asset, 'expense');
    }

    private function outlay(Request $request, int $asset, string $kind): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $this->outlayData($request, $kind);
        $this->assets->{$kind}($request, $tenant, $asset, $data, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->queries->card($tenant, $asset)], 201);
    }

    public function disposal(Request $request, int $asset): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate(['date' => ['required', 'date_format:Y-m-d'], 'kind' => ['nullable', 'in:sale,scrap'], 'proceeds' => ['nullable', 'numeric', 'min:0'],
            'counterAccountId' => ['nullable', 'integer'], 'costAmount' => ['nullable', 'numeric', 'gt:0'], 'description' => ['nullable', 'string', 'max:500']]);
        $this->assets->disposal($request, $tenant, $asset, $data, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->queries->card($tenant, $asset)], 201);
    }

    public function transfer(Request $request, int $asset): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate(['date' => ['required', 'date_format:Y-m-d'], 'toBranchId' => ['nullable', 'integer'], 'toLocationId' => ['nullable', 'integer'], 'description' => ['nullable', 'string', 'max:500']]);
        $this->assets->transfer($request, $tenant, $asset, $data, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->queries->card($tenant, $asset)], 201);
    }

    public function reverseTransaction(Request $request, int $asset, int $transaction): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->assets->reverseTransaction($request, $tenant, $asset, $transaction, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->queries->card($tenant, $asset)]);
    }

    public function schedule(Request $request, int $asset): JsonResponse
    {
        return response()->json(['data' => $this->queries->schedule(TenantContext::id($request), $asset)]);
    }

    public function alerts(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate(['days' => ['nullable', 'integer', 'min:1', 'max:730']]);
        [$owner, $branches] = $this->scope($request, $tenant);

        return response()->json(['data' => $this->queries->alerts($tenant, (int) ($data['days'] ?? 60), $branches, $owner)]);
    }

    public function operations(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $filters = $request->validate(['dateFrom' => ['required', 'date_format:Y-m-d'], 'dateTo' => ['required', 'date_format:Y-m-d', 'after_or_equal:dateFrom'],
            'type' => ['nullable', 'in:opening,acquisition,addition,maintenance,expense,depreciation,disposal,transfer'], 'branchId' => ['nullable', 'string'], 'assetId' => ['nullable', 'integer']]);

        return response()->json(['data' => $this->queries->operations($tenant, $filters)]);
    }

    // ------------------------------------------------------------ depreciation runs

    public function runs(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $rows = DB::table('depreciation_runs')->where('tenant_id', $tenant)->orderByDesc('period_end')->orderByDesc('id')->limit(500)->get();

        return response()->json(['data' => $rows->map(fn ($r) => $this->runs->runView($r))->values()]);
    }

    public function showRun(Request $request, int $run): JsonResponse
    {
        return response()->json(['data' => $this->runs->show(TenantContext::id($request), $run)]);
    }

    public function previewRun(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);

        return response()->json(['data' => $this->runs->previewPayload($tenant, $this->runFilters($request))]);
    }

    public function storeRun(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $id = $this->runs->run($request, $tenant, $this->runFilters($request), FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->runs->show($tenant, (int) $id)], 201);
    }

    public function reverseRun(Request $request, int $run): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->runs->reverse($request, $tenant, $run, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->runs->show($tenant, $run)]);
    }

    // ------------------------------------------------------------ validation

    private function scope(Request $request, int $tenant): array
    {
        $actor = FinanceAccess::actor($request);
        if ($actor->isOwner()) {
            return [true, []];
        }

        return [false, FinancialActor::operationalBranchIds((int) $actor->id, $tenant)];
    }

    private function runFilters(Request $request): array
    {
        $data = $request->validate(['periodEnd' => ['required', 'date_format:Y-m-d'], 'branchId' => ['nullable', 'string'], 'categoryId' => ['nullable', 'integer'],
            'assetId' => ['nullable', 'integer'], 'description' => ['nullable', 'string', 'max:500']]);
        $branch = $data['branchId'] ?? null;
        $data['companyOnly'] = $branch === 'company';
        $data['branchId'] = $branch && $branch !== 'company' ? (int) $branch : null;

        return $data;
    }

    private function categoryData(Request $request): array
    {
        return $request->validate([
            'code' => ['nullable', 'string', 'max:40'], 'nameAr' => ['required', 'string', 'max:255'], 'nameEn' => ['nullable', 'string', 'max:255'],
            'parentId' => ['nullable', 'integer'], 'assetAccountId' => ['nullable', 'integer'], 'accumulatedAccountId' => ['nullable', 'integer'],
            'expenseAccountId' => ['nullable', 'integer'], 'gainAccountId' => ['nullable', 'integer'], 'lossAccountId' => ['nullable', 'integer'],
            'defaultMethod' => ['nullable', 'in:straight_line,declining_balance,none'], 'defaultLifeMonths' => ['nullable', 'integer', 'min:1', 'max:1200'],
            'defaultSalvagePercent' => ['nullable', 'numeric', 'min:0', 'max:100'], 'isActive' => ['nullable', 'boolean'],
        ]);
    }

    private function locationData(Request $request): array
    {
        return $request->validate(['name' => ['required', 'string', 'max:255'], 'branchId' => ['nullable', 'integer'], 'isActive' => ['nullable', 'boolean']]);
    }

    private function assetData(Request $request, bool $partial = false): array
    {
        $req = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'code' => ['nullable', 'string', 'max:40'], 'nameAr' => [$req, 'string', 'max:255'], 'nameEn' => ['nullable', 'string', 'max:255'],
            'barcode' => ['nullable', 'string', 'max:80'], 'serialNumber' => ['nullable', 'string', 'max:120'],
            'categoryId' => ['nullable', 'integer'], 'branchId' => ['nullable', 'integer'], 'locationId' => ['nullable', 'integer'],
            'acquisitionDate' => [$req, 'date_format:Y-m-d'], 'depreciationStartDate' => ['nullable', 'date_format:Y-m-d'],
            'acquisitionCost' => [$req, 'numeric', 'min:0'], 'salvageValue' => ['nullable', 'numeric', 'min:0'],
            'usefulLifeMonths' => ['nullable', 'integer', 'min:0', 'max:1200'], 'method' => ['nullable', 'in:straight_line,declining_balance,none'],
            'assetAccountId' => ['nullable', 'integer'], 'accumulatedAccountId' => ['nullable', 'integer'], 'expenseAccountId' => ['nullable', 'integer'],
            'gainAccountId' => ['nullable', 'integer'], 'lossAccountId' => ['nullable', 'integer'], 'fundingAccountId' => ['nullable', 'integer'],
            'supplierId' => ['nullable', 'integer'], 'isOpening' => ['nullable', 'boolean'], 'openingAccumulated' => ['nullable', 'numeric', 'min:0'],
            'openingDepreciatedUntil' => ['nullable', 'date_format:Y-m-d'], 'manufacturer' => ['nullable', 'string', 'max:255'],
            'warrantyEndDate' => ['nullable', 'date_format:Y-m-d'], 'notes' => ['nullable', 'string', 'max:2000'],
            'activate' => ['nullable', 'boolean'], 'generateEntry' => ['nullable', 'boolean'],
            'componentsMode' => ['nullable', 'in:manual,equal'], 'components' => ['nullable', 'array', 'max:200'],
            'components.*.name' => ['required_with:components', 'string', 'max:255'], 'components.*.cost' => ['nullable', 'numeric', 'min:0'],
        ] + $this->paymentRules());
    }

    private function paymentRules(): array
    {
        return [
            'payments' => ['nullable', 'array', 'max:20'], 'payments.*.accountId' => ['required_with:payments', 'integer'],
            'payments.*.amount' => ['required_with:payments', 'numeric', 'gt:0'],
        ];
    }

    /** Shared by addition / maintenance / expense: amount, payments (one or many), allocation to the items. */
    private function outlayData(Request $request, string $kind): array
    {
        $rules = [
            'date' => ['required', 'date_format:Y-m-d'], 'amount' => ['required', 'numeric', 'gt:0'], 'counterAccountId' => ['nullable', 'integer'],
            'description' => ['nullable', 'string', 'max:500'],
            'scope' => ['nullable', 'in:asset,new_component'], 'distribution' => ['nullable', 'in:equal,manual'], 'componentName' => ['nullable', 'string', 'max:255'],
            'allocations' => ['nullable', 'array', 'max:200'], 'allocations.*.componentId' => ['required_with:allocations', 'integer'],
            'allocations.*.amount' => ['required_with:allocations', 'numeric', 'min:0'],
        ] + $this->paymentRules();
        if ($kind === 'maintenance') {
            $rules['lifeExtensionMonths'] = ['required', 'integer', 'min:0', 'max:600'];
        } elseif ($kind === 'addition') {
            $rules['lifeExtensionMonths'] = ['nullable', 'integer', 'min:0', 'max:600'];
        } else {
            $rules['expenseAccountId'] = ['nullable', 'integer'];
            $rules['capitalize'] = ['nullable', 'boolean'];
        }

        return $request->validate($rules);
    }

    // ------------------------------------------------------------ physical counts

    public function counts(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->counts->list(TenantContext::id($request))]);
    }

    public function showCount(Request $request, int $count): JsonResponse
    {
        return response()->json(['data' => $this->counts->show(TenantContext::id($request), $count)]);
    }

    public function startCount(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate(['branchId' => ['nullable', 'integer'], 'countDate' => ['nullable', 'date_format:Y-m-d'], 'notes' => ['nullable', 'string', 'max:2000']]);
        $id = $this->counts->start($request, $tenant, FinancialActor::id($request, $tenant), $data);

        return response()->json(['data' => $this->counts->show($tenant, $id)], 201);
    }

    public function scanCount(Request $request, int $count): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate(['code' => ['required', 'string', 'max:120']]);
        $scan = $this->counts->scan($tenant, $count, $data['code']);

        return response()->json(['data' => $scan + ['count' => $this->counts->show($tenant, $count)['summary']]]);
    }

    public function updateCountLine(Request $request, int $count, int $line): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $data = $request->validate(['status' => ['nullable', 'in:pending,found,missing'], 'note' => ['nullable', 'string', 'max:500']]);

        return response()->json(['data' => $this->counts->setLine($tenant, $count, $line, $data)]);
    }

    public function closeCount(Request $request, int $count): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->counts->close($request, $tenant, $count, FinancialActor::id($request, $tenant));

        return response()->json(['data' => $this->counts->show($tenant, $count)]);
    }

    public function cancelCount(Request $request, int $count): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $this->counts->cancel($tenant, $count);

        return response()->json(['data' => $this->counts->show($tenant, $count)]);
    }
}
