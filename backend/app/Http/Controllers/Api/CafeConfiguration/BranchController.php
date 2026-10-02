<?php

namespace App\Http\Controllers\Api\CafeConfiguration;

use App\Http\Controllers\Controller;
use App\Http\Requests\CafeConfiguration\StoreBranchRequest;
use App\Http\Requests\CafeConfiguration\UpdateBranchRequest;
use App\Http\Resources\CafeConfiguration\BranchResource;
use App\Models\Branch;
use App\Services\CafeConfigurationPolicy;
use App\Services\FinancialSetupService;
use App\Services\PosInventoryWarehouseResolver;
use App\Services\ShiftDrawerReadinessService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class BranchController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        return BranchResource::collection(
            Branch::query()
                ->where('tenant_id', TenantContext::id($request))
                ->whereNull('deleted_at')
                ->with(['posInventoryWarehouse', 'warehouses' => fn ($query) => $query->where('is_active', true)->whereNull('deleted_at')->orderBy('name')])
                ->orderBy('id')
                ->get(),
        )->response();
    }

    public function store(StoreBranchRequest $request, FinancialSetupService $financialSetup): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $request->validated();
        $warehouseName = $data['warehouseName'] ?? null;
        unset($data['warehouseName']);
        $data['branch_type'] = $data['branchType'] ?? 'cafe';
        unset($data['branchType']);
        $this->mapVarianceAccounts($tenantId, $data);
        $branch = DB::transaction(function () use ($data, $tenantId, $financialSetup, $warehouseName, $request): Branch {
            $branch = Branch::query()->create([
                ...$data,
                'tenant_id' => $tenantId,
                'currency' => 'SYP',
                'is_active' => true,
            ]);
            $financialSetup->ensureBranchWarehouse($tenantId, $branch->id, $warehouseName, $request->attributes->get('auth_user')->id);
            $financialSetup->ensureBranchCashDrawer($tenantId, $branch->id, $request->attributes->get('auth_user')->id);
            $financialSetup->ensureDefaultShiftCloseDestination($tenantId, $branch->id);

            return $branch;
        });

        return (new BranchResource($this->withPosWarehouses($branch->fresh())))->response()->setStatusCode(201);
    }

    public function show(Request $request, int $branch): BranchResource
    {
        return new BranchResource($this->withPosWarehouses($this->branch($request, $branch)));
    }

    public function update(UpdateBranchRequest $request, int $branch, PosInventoryWarehouseResolver $posWarehouses, FinancialSetupService $financialSetup, ShiftDrawerReadinessService $readiness): BranchResource
    {
        $branch = $this->branch($request, $branch);
        $data = $request->validated();
        $actor = $request->attributes->get('auth_user');
        if (! $actor->isOwner()) {
            // cafe.configuration.printing already confirmed the actor is at
            // least a Manager; a non-Owner caller may only ever persist the
            // printer fields through this shared endpoint. Everything else
            // in $data (name, financial wiring, shift settings, POS
            // warehouse, ...) is silently dropped rather than rejected,
            // since the Flutter Printing screen always submits the full
            // branch draft even though it only edited printer fields.
            $data = array_intersect_key($data, array_flip(CafeConfigurationPolicy::PRINTER_FIELDS));
        }
        if (array_key_exists('posInventoryWarehouseId', $data)) {
            if (($data['branchType'] ?? $branch->branch_type) === 'factory') {
                \App\Support\FactoryWarehouseScope::assertWarehouseForBranch((int) $branch->tenant_id, (int) $branch->id, $data['posInventoryWarehouseId']);
                $data['default_warehouse_id'] = $data['posInventoryWarehouseId'];
                $data['pos_inventory_warehouse_id'] = null;
            } else {
            $posWarehouses->assertEligible((int) $branch->tenant_id, (int) $branch->id, $data['posInventoryWarehouseId']);
            $data['pos_inventory_warehouse_id'] = $data['posInventoryWarehouseId'];
            $data['default_warehouse_id'] = $data['posInventoryWarehouseId'];
            }
            unset($data['posInventoryWarehouseId']);
        }
        if (array_key_exists('branchType', $data)) {
            $data['branch_type'] = $data['branchType'];
            unset($data['branchType']);
        }
        // Drawer / close configuration is validated by the same canonical
        // service shift open uses, but only when one of those fields changes.
        $touchesCashConfig = array_intersect_key($data, array_flip(['posCashFinancialLocationId', 'shiftCloseDestinationFinancialLocationId', 'shiftClosingFloatAmount'])) !== [];
        if ($touchesCashConfig) {
            $drawerId = array_key_exists('posCashFinancialLocationId', $data) ? (int) $data['posCashFinancialLocationId'] : ($branch->pos_cash_financial_location_id ? (int) $branch->pos_cash_financial_location_id : null);
            $destinationId = array_key_exists('shiftCloseDestinationFinancialLocationId', $data)
                ? ($data['shiftCloseDestinationFinancialLocationId'] === null ? null : (int) $data['shiftCloseDestinationFinancialLocationId'])
                : ($branch->shift_close_destination_financial_location_id ? (int) $branch->shift_close_destination_financial_location_id : null);
            $float = $data['shiftClosingFloatAmount'] ?? $branch->shift_closing_float_amount;
            $issues = $readiness->configurationIssues((int) $branch->tenant_id, (object) $branch->getAttributes(), $drawerId, $destinationId, $float);
            if ($issues !== []) {
                // In this screen the drawer field is posCashFinancialLocationId.
                $issues = array_map(fn (array $issue): array => $issue['field'] === ShiftDrawerReadinessService::FIELD_DRAWER
                    ? ['field' => 'posCashFinancialLocationId'] + $issue : $issue, $issues);
                throw $readiness->exception($issues);
            }
        }
        if (array_key_exists('posCashFinancialLocationId', $data)) {
            $data['pos_cash_financial_location_id'] = (int) $data['posCashFinancialLocationId'];
            unset($data['posCashFinancialLocationId']);
        }
        if (array_key_exists('shiftCloseDestinationFinancialLocationId', $data)) {
            $data['shift_close_destination_financial_location_id'] = $data['shiftCloseDestinationFinancialLocationId'];
            unset($data['shiftCloseDestinationFinancialLocationId']);
        }
        $this->mapVarianceAccounts((int) $branch->tenant_id, $data);
        foreach (['shiftClosingFloatAmount' => 'shift_closing_float_amount', 'shiftCloseTime' => 'shift_close_time'] as $input => $column) {
            if (array_key_exists($input, $data)) {
                $data[$column] = $data[$input];
                unset($data[$input]);
            }
        }
        foreach ([
            'receiptPrintingEnabled' => 'receipt_printing_enabled',
            'defaultPaperWidth' => 'default_paper_width',
            'autoPrintAfterPayment' => 'auto_print_after_payment',
            'defaultPrinterName' => 'default_printer_name',
            'defaultPrinterIp' => 'default_printer_ip',
            'defaultPrinterPort' => 'default_printer_port',
        ] as $input => $column) {
            if (array_key_exists($input, $data)) {
                $data[$column] = $data[$input];
                unset($data[$input]);
            }
        }
        if (($data['receipt_printing_enabled'] ?? $branch->receipt_printing_enabled) === true) {
            $printerIp = $data['default_printer_ip'] ?? $branch->default_printer_ip;
            $printerPort = $data['default_printer_port'] ?? $branch->default_printer_port;
            if (blank($printerIp) || $printerPort === null) {
                throw ValidationException::withMessages([
                    'defaultPrinterIp' => 'A printer IP address or host and port are required when receipt printing is enabled.',
                ]);
            }
        }
        DB::transaction(function () use ($branch, $data, $financialSetup, $request): void {
            $branch->update($data);
            if ($branch->is_active) {
                $financialSetup->ensureBranchCashDrawer((int) $branch->tenant_id, (int) $branch->id, $request->attributes->get('auth_user')->id);
            }
        });

        return new BranchResource($this->withPosWarehouses($branch->fresh()));
    }

    private function branch(Request $request, int $branchId): Branch
    {
        return Branch::query()
            ->where('tenant_id', TenantContext::id($request))
            ->whereNull('deleted_at')
            ->findOrFail($branchId);
    }

    private function withPosWarehouses(Branch $branch): Branch
    {
        return $branch->load(['posInventoryWarehouse', 'warehouses' => fn ($query) => $query->where('is_active', true)->whereNull('deleted_at')->orderBy('name')]);
    }

    /**
     * Maps the shortage / overage account inputs to columns. Shortage must be an expense account and overage a
     * revenue account (each its own account), and both must be active leaf accounts that are not a cash box.
     */
    private function mapVarianceAccounts(int $tenantId, array &$data): void
    {
        foreach (['cashVarianceAccountId' => ['cash_variance_account_id', 'حساب عجز الصندوق', 'expenses'], 'cashOverAccountId' => ['cash_over_account_id', 'حساب زيادة الصندوق', 'revenue']] as $input => [$column, $label, $group]) {
            if (! array_key_exists($input, $data)) {
                continue;
            }
            if ($data[$input] !== null) {
                $accountId = (int) $data[$input];
                $isCashLocationAccount = DB::table('financial_locations')
                    ->where('tenant_id', $tenantId)->where('financial_account_id', $accountId)->exists();
                $account = DB::table('financial_accounts')
                    ->where('tenant_id', $tenantId)->where('id', $accountId)
                    ->where('is_active', true)->whereNull('deleted_at')->first(['id', 'account_group']);
                if (! $account || $isCashLocationAccount) {
                    throw ValidationException::withMessages([
                        $input => $isCashLocationAccount
                            ? $label.' لا يمكن أن يكون صندوقاً أو خزنة.'
                            : 'الحساب المحدد غير صالح.',
                    ]);
                }
                if ($account->account_group !== $group) {
                    throw ValidationException::withMessages([$input => $label.($group === 'expenses' ? ' يجب أن يكون من حسابات المصاريف.' : ' يجب أن يكون من حسابات الإيرادات.')]);
                }
                if (DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('parent_account_id', $accountId)->whereNull('deleted_at')->exists()) {
                    throw ValidationException::withMessages([$input => $label.' يجب أن يكون حساباً فرعياً (نهائياً) وليس حساباً رئيسياً.']);
                }
            }
            $data[$column] = $data[$input];
            unset($data[$input]);
        }
    }
}
