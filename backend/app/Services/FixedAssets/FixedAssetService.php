<?php

namespace App\Services\FixedAssets;

use App\Services\AccountingPostingService;
use App\Services\JournalEntryService;
use App\Services\OperationalAuditService;
use App\Support\FinancialActor;
use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * The asset card and its life cycle: create (draft / opening balance), activate (acquisition
 * entry), addition, disposal (sale / scrap, full or partial), transfer between branches, and
 * reversal of the latest operation. Every operation that touches money posts a journal entry
 * and appends one ledger row; nothing edits a posted figure.
 */
final class FixedAssetService
{
    public function __construct(
        private readonly AssetBook $book,
        private readonly DepreciationRunService $runs,
        private readonly AccountingPostingService $posting,
        private readonly JournalEntryService $entries,
        private readonly OperationalAuditService $audit,
        private readonly ComponentBook $components,
        private readonly PaymentSplit $payments,
    ) {}

    // ---------------------------------------------------------------- card

    public function create(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        return DB::transaction(function () use ($request, $tenantId, $data, $actorId): int {
            $payload = $this->cardPayload($tenantId, $data, null, $actorId);
            $now = now();
            $id = (int) DB::table('fixed_assets')->insertGetId($payload + [
                'tenant_id' => $tenantId,
                'code' => $this->resolveCode($tenantId, $data['code'] ?? null),
                'status' => 'draft',
                'created_by' => $actorId,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            $this->audit->record($request, $tenantId, 'fixed_asset.created', 'fixed_asset', $id, [], $payload, $payload['branch_id'] ?? null, $actorId);
            if (! empty($data['components'])) {
                $this->components->replaceDraft($tenantId, $id, (array) $data['components'], (string) ($data['componentsMode'] ?? 'manual'), Money::cents((string) $payload['acquisition_cost']));
            }
            if (! empty($data['activate'])) {
                $this->activate($request, $tenantId, $id, ['generateEntry' => (bool) ($data['generateEntry'] ?? true), 'payments' => $data['payments'] ?? null], $actorId);
            }

            return $id;
        });
    }

    public function update(Request $request, int $tenantId, int $assetId, array $data, ?int $actorId): void
    {
        DB::transaction(function () use ($request, $tenantId, $assetId, $data, $actorId): void {
            $asset = $this->book->asset($tenantId, $assetId, true);
            if ($asset->status === 'disposed') {
                throw ValidationException::withMessages(['status' => 'لا يمكن تعديل أصل مستبعد.']);
            }
            if ($asset->status === 'draft') {
                $payload = $this->cardPayload($tenantId, $data, $asset, $actorId);
                if (! empty($data['code']) && $data['code'] !== $asset->code) {
                    $payload['code'] = $this->resolveCode($tenantId, $data['code']);
                }
                $cost = Money::cents((string) $payload['acquisition_cost']);
                if (array_key_exists('components', $data)) {
                    $this->components->replaceDraft($tenantId, $assetId, (array) $data['components'], (string) ($data['componentsMode'] ?? 'manual'), $cost);
                } else {
                    $this->components->assertDraftBalanced($tenantId, $assetId, $cost);
                }
            } else {
                // Active asset: descriptive fields + change of estimate (life, salvage, method) only.
                // Category, branch, cost and accounts move only through operations (transfer, addition…).
                $allowed = ['nameAr' => 'name_ar', 'nameEn' => 'name_en', 'barcode' => 'barcode', 'serialNumber' => 'serial_number',
                    'manufacturer' => 'manufacturer', 'warrantyEndDate' => 'warranty_end_date', 'notes' => 'notes',
                    'usefulLifeMonths' => 'useful_life_months', 'salvageValue' => 'salvage_value', 'method' => 'method', 'locationId' => 'location_id'];
                $payload = [];
                foreach ($allowed as $in => $column) {
                    if (array_key_exists($in, $data)) {
                        $payload[$column] = $data[$in];
                    }
                }
                if (isset($payload['salvage_value'])) {
                    $payload['salvage_value'] = Money::decimal(Money::cents((string) $payload['salvage_value'], 'salvageValue'));
                    $book = $this->book->totals($tenantId, $assetId);
                    if (Money::cents($payload['salvage_value']) > $book['cost'] - $book['accumulated']) {
                        throw ValidationException::withMessages(['salvageValue' => 'قيمة الخردة أكبر من القيمة الدفترية الحالية.']);
                    }
                }
                if (isset($payload['method']) && ! in_array($payload['method'], DepreciationCalculator::METHODS, true)) {
                    throw ValidationException::withMessages(['method' => 'طريقة اهتلاك غير مدعومة.']);
                }
                if (array_key_exists('location_id', $payload)) {
                    $this->assertLocation($tenantId, $payload['location_id'], $asset->branch_id ? (int) $asset->branch_id : null);
                }
                if (($payload['status'] ?? null) === null && $asset->status === 'fully_depreciated'
                    && (isset($payload['useful_life_months']) || isset($payload['salvage_value']))) {
                    $book = $this->book->totals($tenantId, $assetId);
                    $remaining = $book['cost'] - Money::cents((string) ($payload['salvage_value'] ?? $asset->salvage_value)) - $book['accumulated'];
                    if ($remaining > 0) {
                        $payload['status'] = 'active';
                    }
                }
            }
            $payload['updated_by'] = $actorId;
            $payload['updated_at'] = now();
            DB::table('fixed_assets')->where('id', $assetId)->update($payload);
            $this->audit->record($request, $tenantId, 'fixed_asset.updated', 'fixed_asset', $assetId, (array) $asset, $payload, $asset->branch_id, $actorId);
        });
    }

    public function delete(Request $request, int $tenantId, int $assetId, ?int $actorId): void
    {
        DB::transaction(function () use ($request, $tenantId, $assetId, $actorId): void {
            $asset = $this->book->asset($tenantId, $assetId, true);
            if ($asset->status !== 'draft') {
                throw ValidationException::withMessages(['status' => 'يُحذف الأصل وهو مسودة فقط. الأصل المفعّل يُستبعد أو يُعكس تفعيله.']);
            }
            DB::table('fixed_assets')->where('id', $assetId)->update(['deleted_at' => now(), 'updated_by' => $actorId]);
            $this->audit->record($request, $tenantId, 'fixed_asset.deleted', 'fixed_asset', $assetId, (array) $asset, [], $asset->branch_id, $actorId);
        });
    }

    // ---------------------------------------------------------------- operations

    /** Draft → active. Posts Dr asset / Cr funding unless the cost was already posted elsewhere. */
    public function activate(Request $request, int $tenantId, int $assetId, array $data, ?int $actorId): void
    {
        DB::transaction(function () use ($request, $tenantId, $assetId, $data, $actorId): void {
            $asset = $this->book->asset($tenantId, $assetId, true);
            if ($asset->status !== 'draft') {
                throw ValidationException::withMessages(['status' => 'الأصل مفعّل مسبقًا.']);
            }
            if (! $asset->category_id) {
                throw ValidationException::withMessages(['categoryId' => 'حدد صنف الأصل قبل التفعيل.']);
            }
            $needs = DepreciationCalculator::depreciates($asset->method) ? ['asset', 'accumulated', 'expense'] : ['asset'];
            if (DepreciationCalculator::depreciates($asset->method) && (int) $asset->useful_life_months <= 0) {
                throw ValidationException::withMessages(['usefulLifeMonths' => 'حدد العمر الإنتاجي بالأشهر.']);
            }
            $accounts = $this->book->requireAccounts($tenantId, $asset, $needs);
            $cost = Money::cents((string) $asset->acquisition_cost);
            $now = now();
            $base = [
                'tenant_id' => $tenantId, 'fixed_asset_id' => $assetId, 'transaction_date' => $asset->acquisition_date,
                'cost_amount' => Money::decimal($cost), 'branch_id' => $asset->branch_id, 'previous_status' => 'draft',
                'previous_depreciated_until' => $asset->depreciated_until, 'created_by' => $actorId, 'created_at' => $now, 'updated_at' => $now,
            ];

            if ($asset->is_opening) {
                DB::table('fixed_asset_transactions')->insert([
                    'transaction_date' => $asset->depreciated_until ?? $asset->acquisition_date,
                ] + $base + [
                    'type' => 'opening',
                    'depreciation_amount' => Money::decimal(Money::cents((string) $asset->opening_accumulated)),
                    'description' => 'رصيد افتتاحي (بدون قيد — الرصيد موجود بالدفتر)',
                ]);
            } else {
                $txId = (int) DB::table('fixed_asset_transactions')->insertGetId($base + [
                    'type' => 'acquisition',
                    'counter_account_id' => $asset->funding_account_id,
                    'description' => $asset->supplier_invoice_id ? 'شراء عبر فاتورة مورد' : 'إدخال أصل',
                ]);
                $journalId = null;
                if ($asset->supplier_invoice_id) {
                    $journalId = DB::table('supplier_invoices')->where('id', $asset->supplier_invoice_id)->value('journal_entry_id');
                } elseif (($data['generateEntry'] ?? true) && $cost > 0) {
                    if (empty($data['payments']) && ! $asset->funding_account_id) {
                        throw ValidationException::withMessages(['fundingAccountId' => 'حدد حساب الإدخال (الصندوق، المورد أو الشريك) أو ألغِ «توليد سند إدخال».']);
                    }
                    $branch = $asset->branch_id ? (int) $asset->branch_id : null;
                    $split = $this->payments->normalize($tenantId, $data['payments'] ?? null, $asset->funding_account_id ? (int) $asset->funding_account_id : null, $cost);
                    $journalId = $this->posting->post($request, $tenantId, [
                        'sourceType' => 'asset_acquisition', 'sourceId' => $txId, 'sourceEvent' => 'POSTED',
                        'branchId' => $branch, 'entryDate' => $asset->acquisition_date,
                        'description' => "إدخال أصل {$asset->code} — {$asset->name_ar}",
                        'lines' => array_merge(
                            [['accountId' => $accounts['asset'], 'branchId' => $branch, 'debit' => Money::decimal($cost), 'credit' => '0.00']],
                            $this->payments->creditLines($split, $branch),
                        ),
                    ], $actorId);
                    $this->payments->store($tenantId, $assetId, $txId, $split);
                    DB::table('fixed_asset_transactions')->where('id', $txId)->update(['counter_account_id' => count($split) === 1 ? $split[0]['accountId'] : null]);
                }
                DB::table('fixed_asset_transactions')->where('id', $txId)->update(['journal_entry_id' => $journalId]);
            }
            DB::table('fixed_assets')->where('id', $assetId)->update(['status' => 'active', 'activated_at' => $now, 'updated_by' => $actorId, 'updated_at' => $now]);
            $this->audit->record($request, $tenantId, 'fixed_asset.activated', 'fixed_asset', $assetId, [], ['cost' => Money::decimal($cost)], $asset->branch_id, $actorId);
        });
    }

    /** Capitalised addition to the asset cost (optionally extending the life). */
    public function addition(Request $request, int $tenantId, int $assetId, array $data, ?int $actorId): int
    {
        return $this->outlay($request, $tenantId, $assetId, $data, $actorId, 'addition');
    }

    /** Maintenance: capitalised like an addition and extends the useful life. */
    public function maintenance(Request $request, int $tenantId, int $assetId, array $data, ?int $actorId): int
    {
        return $this->outlay($request, $tenantId, $assetId, $data, $actorId, 'maintenance');
    }

    /** Expense on the asset: never extends the life; expensed to P&L (default) or capitalised when `capitalize` is set. */
    public function expense(Request $request, int $tenantId, int $assetId, array $data, ?int $actorId): int
    {
        return $this->outlay($request, $tenantId, $assetId, $data, $actorId, 'expense');
    }

    private const OUTLAYS = [
        'addition' => ['source' => 'asset_addition', 'label' => 'إضافة على الأصل', 'name' => 'قيمة الإضافة'],
        'maintenance' => ['source' => 'asset_maintenance', 'label' => 'صيانة الأصل', 'name' => 'قيمة الصيانة'],
        'expense' => ['source' => 'asset_expense', 'label' => 'مصروف على الأصل', 'name' => 'قيمة المصروف'],
    ];

    /**
     * One money-in-the-asset operation. Paid from one or several accounts (payments); allocated to the whole
     * asset or to one new item (components). The three kinds differ only in what they do to cost and life.
     */
    private function outlay(Request $request, int $tenantId, int $assetId, array $data, ?int $actorId, string $kind): int
    {
        return DB::transaction(function () use ($request, $tenantId, $assetId, $data, $actorId, $kind): int {
            $meta = self::OUTLAYS[$kind];
            $asset = $this->operable($tenantId, $assetId);
            $date = $data['date'];
            $amount = Money::cents((string) $data['amount'], 'amount');
            if ($amount <= 0) {
                throw ValidationException::withMessages(['amount' => $meta['name'].' يجب أن تكون أكبر من صفر.']);
            }
            $capitalize = $kind !== 'expense' || ! empty($data['capitalize']);
            $life = $kind === 'expense' ? 0 : max(0, (int) ($data['lifeExtensionMonths'] ?? 0));
            if (! $capitalize && ($data['scope'] ?? 'asset') === 'new_component') {
                throw ValidationException::withMessages(['scope' => 'المصروف لا يضيف بندًا جديدًا إلى الأصل؛ استخدم «إضافة» أو فعّل «رسملة المصروف».']);
            }
            $expenseAccount = null;
            if (! $capitalize) {
                if (empty($data['expenseAccountId'])) {
                    throw ValidationException::withMessages(['expenseAccountId' => 'حدد حساب المصروف.']);
                }
                $expenseAccount = $this->assertPostable($tenantId, (int) $data['expenseAccountId'], 'expenseAccountId');
            } else {
                $this->assertAfterLastMovement($tenantId, $asset, $date);
            }
            $split = $this->payments->normalize($tenantId, $data['payments'] ?? null, ! empty($data['counterAccountId']) ? (int) $data['counterAccountId'] : null, $amount);
            if ($capitalize) {
                $this->catchUp($request, $tenantId, $asset, CarbonImmutable::parse($date)->subDay()->toDateString(), $actorId, 'addition');
            }
            $asset = $this->book->asset($tenantId, $assetId, true);
            $debitAccount = $capitalize ? $this->book->requireAccounts($tenantId, $asset, ['asset'])['asset'] : $expenseAccount;
            $branch = $asset->branch_id ? (int) $asset->branch_id : null;
            $now = now();
            $costBefore = $this->book->totals($tenantId, $assetId)['cost'];
            $txId = (int) DB::table('fixed_asset_transactions')->insertGetId([
                'tenant_id' => $tenantId, 'fixed_asset_id' => $assetId, 'type' => $kind, 'transaction_date' => $date,
                'cost_amount' => Money::decimal($capitalize ? $amount : 0), 'expense_amount' => Money::decimal($capitalize ? 0 : $amount),
                'expense_account_id' => $expenseAccount, 'life_change_months' => $life,
                'branch_id' => $branch, 'counter_account_id' => count($split) === 1 ? $split[0]['accountId'] : null, 'description' => $data['description'] ?? null,
                'previous_status' => $asset->status, 'previous_depreciated_until' => $asset->depreciated_until,
                'created_by' => $actorId, 'created_at' => $now, 'updated_at' => $now,
            ]);
            $scope = $this->components->allocate($tenantId, $assetId, $txId, $amount, $capitalize, $data, $costBefore);
            $journalId = $this->posting->post($request, $tenantId, [
                'sourceType' => $meta['source'], 'sourceId' => $txId, 'sourceEvent' => 'POSTED', 'branchId' => $branch, 'entryDate' => $date,
                'description' => "{$meta['label']} {$asset->code} — {$asset->name_ar}".(! empty($data['description']) ? ' — '.$data['description'] : ''),
                'lines' => array_merge(
                    [['accountId' => $debitAccount, 'branchId' => $branch, 'debit' => Money::decimal($amount), 'credit' => '0.00']],
                    $this->payments->creditLines($split, $branch),
                ),
            ], $actorId);
            $this->payments->store($tenantId, $assetId, $txId, $split);
            DB::table('fixed_asset_transactions')->where('id', $txId)->update(['journal_entry_id' => $journalId, 'component_scope' => $scope]);
            if ($capitalize) {
                DB::table('fixed_assets')->where('id', $assetId)->update(['status' => 'active', 'updated_at' => $now, 'updated_by' => $actorId]);
            }
            $this->audit->record($request, $tenantId, "fixed_asset.{$kind}", 'fixed_asset', $assetId, [], ['amount' => Money::decimal($amount), 'capitalized' => $capitalize, 'lifeExtensionMonths' => $life], $branch, $actorId);

            return $txId;
        });
    }

    /** Sale or scrap, full or partial (costAmount). Depreciates up to the date first. */
    public function disposal(Request $request, int $tenantId, int $assetId, array $data, ?int $actorId): int
    {
        return DB::transaction(function () use ($request, $tenantId, $assetId, $data, $actorId): int {
            $asset = $this->operable($tenantId, $assetId);
            $date = $data['date'];
            $this->assertAfterLastMovement($tenantId, $asset, $date, true);
            $this->catchUp($request, $tenantId, $asset, $date, $actorId, 'disposal');
            $asset = $this->book->asset($tenantId, $assetId, true);
            $book = $this->book->totals($tenantId, $assetId);
            if ($book['cost'] <= 0) {
                throw ValidationException::withMessages(['asset' => 'لا توجد كلفة متبقية لهذا الأصل.']);
            }
            $cost = isset($data['costAmount']) && $data['costAmount'] !== null && $data['costAmount'] !== ''
                ? Money::cents((string) $data['costAmount'], 'costAmount') : $book['cost'];
            if ($cost <= 0 || $cost > $book['cost']) {
                throw ValidationException::withMessages(['costAmount' => 'الكلفة المستبعدة يجب أن تكون بين صفر وكلفة الأصل الحالية.']);
            }
            $full = $cost === $book['cost'];
            if (! $full && $this->components->hasComponents($tenantId, $assetId)) {
                throw ValidationException::withMessages(['costAmount' => 'الأصل مقسّم إلى بنود؛ الاستبعاد الجزئي غير مدعوم له حاليًا. استبعد الأصل كاملًا.']);
            }
            $acc = $full ? $book['accumulated'] : (int) round($book['accumulated'] * $cost / $book['cost']);
            $proceeds = Money::cents((string) ($data['proceeds'] ?? '0'), 'proceeds');
            if ($proceeds < 0) {
                throw ValidationException::withMessages(['proceeds' => 'سعر البيع لا يمكن أن يكون سالبًا.']);
            }
            $counter = $proceeds > 0 ? $this->assertPostable($tenantId, (int) ($data['counterAccountId'] ?? 0), 'counterAccountId') : null;
            $accounts = $this->book->requireAccounts($tenantId, $asset, ['asset', 'accumulated', 'gain', 'loss']);
            $gain = $proceeds - ($cost - $acc);
            $branch = $asset->branch_id ? (int) $asset->branch_id : null;
            $now = now();
            $kind = ($data['kind'] ?? ($proceeds > 0 ? 'sale' : 'scrap')) === 'sale' ? 'sale' : 'scrap';
            $txId = (int) DB::table('fixed_asset_transactions')->insertGetId([
                'tenant_id' => $tenantId, 'fixed_asset_id' => $assetId, 'type' => 'disposal', 'transaction_date' => $date,
                'cost_amount' => Money::decimal(-$cost), 'depreciation_amount' => Money::decimal(-$acc),
                'branch_id' => $branch, 'proceeds' => Money::decimal($proceeds), 'gain_loss' => Money::decimal($gain),
                'counter_account_id' => $counter,
                'description' => trim(($kind === 'sale' ? 'بيع' : 'إتلاف/استبعاد').($full ? '' : ' جزئي').(! empty($data['description']) ? ' — '.$data['description'] : '')),
                'previous_status' => $asset->status, 'previous_depreciated_until' => $asset->depreciated_until,
                'created_by' => $actorId, 'created_at' => $now, 'updated_at' => $now,
            ]);
            $lines = [];
            if ($acc > 0) {
                $lines[] = ['accountId' => $accounts['accumulated'], 'branchId' => $branch, 'debit' => Money::decimal($acc), 'credit' => '0.00'];
            }
            if ($proceeds > 0) {
                $lines[] = ['accountId' => $counter, 'branchId' => $branch, 'debit' => Money::decimal($proceeds), 'credit' => '0.00'];
            }
            if ($gain < 0) {
                $lines[] = ['accountId' => $accounts['loss'], 'branchId' => $branch, 'debit' => Money::decimal(-$gain), 'credit' => '0.00'];
            }
            $lines[] = ['accountId' => $accounts['asset'], 'branchId' => $branch, 'debit' => '0.00', 'credit' => Money::decimal($cost)];
            if ($gain > 0) {
                $lines[] = ['accountId' => $accounts['gain'], 'branchId' => $branch, 'debit' => '0.00', 'credit' => Money::decimal($gain)];
            }
            $journalId = $this->posting->post($request, $tenantId, [
                'sourceType' => 'asset_disposal', 'sourceId' => $txId, 'sourceEvent' => 'POSTED', 'branchId' => $branch, 'entryDate' => $date,
                'description' => ($kind === 'sale' ? 'بيع' : 'استبعاد')." الأصل {$asset->code} — {$asset->name_ar}",
                'lines' => $lines,
            ], $actorId);
            DB::table('fixed_asset_transactions')->where('id', $txId)->update(['journal_entry_id' => $journalId]);
            if ($full) {
                DB::table('fixed_assets')->where('id', $assetId)->update(['status' => 'disposed', 'updated_at' => $now, 'updated_by' => $actorId]);
            }
            $this->audit->record($request, $tenantId, 'fixed_asset.disposed', 'fixed_asset', $assetId, [], ['cost' => Money::decimal($cost), 'proceeds' => Money::decimal($proceeds), 'gain' => Money::decimal($gain)], $branch, $actorId);

            return $txId;
        });
    }

    /** Move to another branch (and/or sub-location). Cost and accumulated depreciation follow the asset. */
    public function transfer(Request $request, int $tenantId, int $assetId, array $data, ?int $actorId): int
    {
        return DB::transaction(function () use ($request, $tenantId, $assetId, $data, $actorId): int {
            $asset = $this->operable($tenantId, $assetId);
            $date = $data['date'];
            $this->assertAfterLastMovement($tenantId, $asset, $date);
            $from = $asset->branch_id ? (int) $asset->branch_id : null;
            $to = ! empty($data['toBranchId']) ? (int) $data['toBranchId'] : null;
            if ($to !== null) {
                $this->assertBranch($tenantId, $to, $actorId);
            }
            $toLocation = ! empty($data['toLocationId']) ? (int) $data['toLocationId'] : null;
            $this->assertLocation($tenantId, $toLocation, $to);
            if ($from === $to && (int) $asset->location_id === (int) $toLocation) {
                throw ValidationException::withMessages(['toBranchId' => 'الأصل موجود أصلًا في هذا الفرع/الموقع.']);
            }
            $journalId = null;
            if ($from !== $to) {
                $this->catchUp($request, $tenantId, $asset, CarbonImmutable::parse($date)->subDay()->toDateString(), $actorId, 'transfer');
                $asset = $this->book->asset($tenantId, $assetId, true);
            }
            $book = $this->book->totals($tenantId, $assetId);
            $now = now();
            $txId = (int) DB::table('fixed_asset_transactions')->insertGetId([
                'tenant_id' => $tenantId, 'fixed_asset_id' => $assetId, 'type' => 'transfer', 'transaction_date' => $date,
                'branch_id' => $from, 'to_branch_id' => $to, 'from_location_id' => $asset->location_id, 'to_location_id' => $toLocation,
                'description' => $data['description'] ?? null, 'previous_status' => $asset->status, 'previous_depreciated_until' => $asset->depreciated_until,
                'created_by' => $actorId, 'created_at' => $now, 'updated_at' => $now,
            ]);
            if ($from !== $to && $book['cost'] > 0) {
                $accounts = $this->book->requireAccounts($tenantId, $asset, $book['accumulated'] > 0 ? ['asset', 'accumulated'] : ['asset']);
                $lines = [
                    ['accountId' => $accounts['asset'], 'branchId' => $to, 'debit' => Money::decimal($book['cost']), 'credit' => '0.00'],
                    ['accountId' => $accounts['asset'], 'branchId' => $from, 'debit' => '0.00', 'credit' => Money::decimal($book['cost'])],
                ];
                if ($book['accumulated'] > 0) {
                    $lines[] = ['accountId' => $accounts['accumulated'], 'branchId' => $from, 'debit' => Money::decimal($book['accumulated']), 'credit' => '0.00'];
                    $lines[] = ['accountId' => $accounts['accumulated'], 'branchId' => $to, 'debit' => '0.00', 'credit' => Money::decimal($book['accumulated'])];
                }
                $journalId = $this->posting->post($request, $tenantId, [
                    'sourceType' => 'asset_transfer', 'sourceId' => $txId, 'sourceEvent' => 'POSTED', 'branchId' => null, 'entryDate' => $date,
                    'description' => "نقل الأصل {$asset->code} — {$asset->name_ar} من {$this->branchName($tenantId, $from)} إلى {$this->branchName($tenantId, $to)}",
                    'lines' => $lines, 'autoBalanceBranches' => true,
                ], $actorId);
            }
            DB::table('fixed_asset_transactions')->where('id', $txId)->update(['journal_entry_id' => $journalId]);
            DB::table('fixed_assets')->where('id', $assetId)->update(['branch_id' => $to, 'location_id' => $toLocation, 'updated_at' => $now, 'updated_by' => $actorId]);
            $this->audit->record($request, $tenantId, 'fixed_asset.transferred', 'fixed_asset', $assetId, ['branchId' => $from], ['branchId' => $to], $to, $actorId);

            return $txId;
        });
    }

    /** Undo the asset's latest operation (acquisition, opening, addition, disposal, transfer). */
    public function reverseTransaction(Request $request, int $tenantId, int $assetId, int $txId, ?int $actorId): void
    {
        DB::transaction(function () use ($request, $tenantId, $assetId, $txId, $actorId): void {
            $asset = $this->book->asset($tenantId, $assetId, true);
            $tx = DB::table('fixed_asset_transactions')->where('tenant_id', $tenantId)->where('fixed_asset_id', $assetId)->where('id', $txId)->lockForUpdate()->first();
            abort_unless($tx, 404, 'الحركة غير موجودة.');
            if ($tx->voided_at) {
                throw ValidationException::withMessages(['transaction' => 'الحركة معكوسة مسبقًا.']);
            }
            if ($tx->type === 'depreciation') {
                throw ValidationException::withMessages(['transaction' => 'الاهتلاك يُعكس من شاشة مذكرات الاهتلاك.']);
            }
            $latest = $this->book->latestTransaction($tenantId, $assetId);
            if (! $latest || (int) $latest->id !== $txId) {
                throw ValidationException::withMessages(['transaction' => 'يمكن عكس آخر حركة على الأصل فقط. اعكس الحركات الأحدث أولًا.']);
            }
            $reversal = null;
            if ($tx->journal_entry_id && ! ($tx->type === 'acquisition' && $asset->supplier_invoice_id)) {
                $reversal = $this->entries->reverse($request, $tenantId, (int) $tx->journal_entry_id, $actorId, true, $tx->transaction_date);
            }
            $now = now();
            DB::table('fixed_asset_transactions')->where('id', $txId)->update(['voided_at' => $now, 'voided_by' => $actorId, 'reversal_journal_entry_id' => $reversal, 'updated_at' => $now]);
            $this->components->voidCreatedBy($tenantId, $assetId, $txId);
            $patch = ['status' => $tx->previous_status ?? 'active', 'updated_at' => $now, 'updated_by' => $actorId];
            if ($tx->type === 'transfer') {
                $patch['branch_id'] = $tx->branch_id;
                $patch['location_id'] = $tx->from_location_id;
            }
            if (in_array($tx->type, ['acquisition', 'opening'], true)) {
                $patch['status'] = 'draft';
                $patch['activated_at'] = null;
            }
            DB::table('fixed_assets')->where('id', $assetId)->update($patch);
            $this->audit->record($request, $tenantId, 'fixed_asset.transaction_reversed', 'fixed_asset', $assetId, (array) $tx, ['reversalJournalId' => $reversal], $asset->branch_id, $actorId);
        });
    }

    /** Draft assets for every 'asset' line of a just-posted supplier invoice (cost already posted by the invoice). */
    public function draftsFromSupplierInvoice(int $tenantId, int $invoiceId, ?int $actorId): int
    {
        $invoice = DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('id', $invoiceId)->first();
        if (! $invoice) {
            return 0;
        }
        $lines = DB::table('supplier_invoice_lines')->where('tenant_id', $tenantId)->where('supplier_invoice_id', $invoiceId)->where('line_type', 'asset')->orderBy('line_number')->get();
        $category = DB::table('asset_categories')->where('tenant_id', $tenantId)->where('asset_account_id', $invoice->debit_account_id)->whereNull('deleted_at')->where('is_active', true)->first();
        $created = 0;
        $now = now();
        foreach ($lines as $line) {
            if (DB::table('fixed_assets')->where('tenant_id', $tenantId)->where('supplier_invoice_line_id', $line->id)->whereNull('deleted_at')->exists()) {
                continue;
            }
            $cost = Money::cents((string) $line->line_total) + Money::cents((string) $line->tax_amount);
            DB::table('fixed_assets')->insert([
                'tenant_id' => $tenantId, 'code' => $this->resolveCode($tenantId, null), 'name_ar' => mb_substr((string) $line->description, 0, 250),
                'category_id' => $category?->id, 'branch_id' => $invoice->branch_id, 'status' => 'draft',
                'acquisition_date' => $invoice->invoice_date, 'depreciation_start_date' => $invoice->invoice_date,
                'acquisition_cost' => Money::decimal($cost), 'useful_life_months' => (int) ($category->default_life_months ?? 0),
                'method' => $category->default_method ?? 'straight_line',
                'salvage_value' => Money::decimal((int) round($cost * (float) ($category->default_salvage_percent ?? 0) / 100)),
                'asset_account_id' => $invoice->debit_account_id, 'supplier_id' => $invoice->supplier_id,
                'supplier_invoice_id' => $invoice->id, 'supplier_invoice_line_id' => $line->id,
                'notes' => 'من فاتورة المورد '.($invoice->internal_reference ?? $invoice->id).((float) $line->quantity != 1.0 ? ' — الكمية '.$line->quantity : ''),
                'created_by' => $actorId, 'created_at' => $now, 'updated_at' => $now,
            ]);
            $created++;
        }

        return $created;
    }

    /** Called before a supplier invoice is reversed: drop its draft assets, refuse when one is active. */
    public function releaseSupplierInvoice(int $tenantId, int $invoiceId): void
    {
        $assets = DB::table('fixed_assets')->where('tenant_id', $tenantId)->where('supplier_invoice_id', $invoiceId)->whereNull('deleted_at')->get();
        foreach ($assets as $asset) {
            if ($asset->status !== 'draft') {
                throw ValidationException::withMessages(['status' => "الأصل «{$asset->name_ar}» المرتبط بالفاتورة مفعّل. اعكس تفعيله من بطاقة الأصل أولًا."]);
            }
        }
        DB::table('fixed_assets')->where('tenant_id', $tenantId)->where('supplier_invoice_id', $invoiceId)->whereNull('deleted_at')->update(['deleted_at' => now()]);
    }

    // ---------------------------------------------------------------- helpers

    private function cardPayload(int $tenantId, array $data, ?object $existing, ?int $actorId): array
    {
        $get = fn (string $key, $default = null) => array_key_exists($key, $data) ? $data[$key] : ($default);
        $categoryId = $get('categoryId', $existing?->category_id);
        $category = null;
        if ($categoryId) {
            $category = DB::table('asset_categories')->where('tenant_id', $tenantId)->where('id', $categoryId)->whereNull('deleted_at')->first();
            if (! $category) {
                throw ValidationException::withMessages(['categoryId' => 'صنف الأصل غير موجود.']);
            }
        }
        $branchId = $get('branchId', $existing?->branch_id);
        $branchId = $branchId ? (int) $branchId : null;
        if ($branchId !== null) {
            $this->assertBranch($tenantId, $branchId, $actorId);
        }
        $locationId = $get('locationId', $existing?->location_id);
        $locationId = $locationId ? (int) $locationId : null;
        $this->assertLocation($tenantId, $locationId, $branchId);

        $acquisitionDate = $get('acquisitionDate', $existing?->acquisition_date) ?? now()->toDateString();
        $cost = Money::cents((string) $get('acquisitionCost', $existing?->acquisition_cost ?? '0'), 'acquisitionCost');
        if ($cost < 0) {
            throw ValidationException::withMessages(['acquisitionCost' => 'الكلفة لا يمكن أن تكون سالبة.']);
        }
        $method = $get('method', $existing?->method ?? $category?->default_method ?? 'straight_line');
        if (! in_array($method, DepreciationCalculator::METHODS, true)) {
            throw ValidationException::withMessages(['method' => 'طريقة اهتلاك غير مدعومة.']);
        }
        $life = (int) $get('usefulLifeMonths', $existing?->useful_life_months ?? $category?->default_life_months ?? 0);
        $salvageInput = $get('salvageValue');
        $salvage = $salvageInput !== null && $salvageInput !== ''
            ? Money::cents((string) $salvageInput, 'salvageValue')
            : ($existing ? Money::cents((string) $existing->salvage_value) : (int) round($cost * (float) ($category->default_salvage_percent ?? 0) / 100));
        if ($salvage < 0 || $salvage > $cost) {
            throw ValidationException::withMessages(['salvageValue' => 'قيمة الخردة يجب أن تكون بين صفر والكلفة.']);
        }
        $isOpening = (bool) $get('isOpening', $existing?->is_opening ?? false);
        $openingAcc = $isOpening ? Money::cents((string) $get('openingAccumulated', $existing?->opening_accumulated ?? '0'), 'openingAccumulated') : 0;
        if ($openingAcc < 0 || $openingAcc > $cost - $salvage) {
            throw ValidationException::withMessages(['openingAccumulated' => 'مجمع الاهتلاك الافتتاحي يجب أن يكون بين صفر و(الكلفة − الخردة).']);
        }
        $depreciatedUntil = $isOpening ? $get('openingDepreciatedUntil', $existing?->depreciated_until) : null;
        if ($isOpening && $openingAcc > 0 && ! $depreciatedUntil) {
            throw ValidationException::withMessages(['openingDepreciatedUntil' => 'حدد تاريخ آخر اهتلاك مسجّل لهذا الرصيد الافتتاحي.']);
        }

        $payload = [
            'name_ar' => trim((string) $get('nameAr', $existing?->name_ar ?? '')),
            'name_en' => $get('nameEn', $existing?->name_en),
            'barcode' => $get('barcode', $existing?->barcode),
            'serial_number' => $get('serialNumber', $existing?->serial_number),
            'category_id' => $category?->id,
            'branch_id' => $branchId,
            'location_id' => $locationId,
            'acquisition_date' => $acquisitionDate,
            'depreciation_start_date' => $get('depreciationStartDate', $existing?->depreciation_start_date) ?? $acquisitionDate,
            'acquisition_cost' => Money::decimal($cost),
            'salvage_value' => Money::decimal($salvage),
            'useful_life_months' => max(0, $life),
            'method' => $method,
            'funding_account_id' => $get('fundingAccountId', $existing?->funding_account_id),
            'supplier_id' => $get('supplierId', $existing?->supplier_id),
            'is_opening' => $isOpening,
            'opening_accumulated' => Money::decimal($openingAcc),
            'depreciated_until' => $depreciatedUntil,
            'manufacturer' => $get('manufacturer', $existing?->manufacturer),
            'warranty_end_date' => $get('warrantyEndDate', $existing?->warranty_end_date),
            'notes' => $get('notes', $existing?->notes),
            'updated_by' => $actorId,
        ];
        if ($payload['name_ar'] === '') {
            throw ValidationException::withMessages(['nameAr' => 'اسم الأصل مطلوب.']);
        }
        foreach (['assetAccountId' => 'asset_account_id', 'accumulatedAccountId' => 'accumulated_account_id', 'expenseAccountId' => 'expense_account_id', 'gainAccountId' => 'gain_account_id', 'lossAccountId' => 'loss_account_id'] as $in => $column) {
            $value = $get($in, $existing?->{$column});
            $payload[$column] = $value ? $this->assertPostable($tenantId, (int) $value, $in) : null;
        }
        if ($payload['funding_account_id']) {
            $payload['funding_account_id'] = $this->assertPostable($tenantId, (int) $payload['funding_account_id'], 'fundingAccountId');
        }
        if (CarbonImmutable::parse($payload['depreciation_start_date'])->lt(CarbonImmutable::parse($acquisitionDate)->subYears(100))) {
            throw ValidationException::withMessages(['depreciationStartDate' => 'تاريخ بدء الاهتلاك غير صالح.']);
        }

        return $payload;
    }

    private function resolveCode(int $tenantId, ?string $requested): string
    {
        $requested = trim((string) $requested);
        $exists = fn (string $code) => DB::table('fixed_assets')->where('tenant_id', $tenantId)->where('code', $code)->exists();
        if ($requested !== '' && ! $exists($requested)) {
            return $requested;
        }
        $max = DB::table('fixed_assets')->where('tenant_id', $tenantId)->pluck('code')->filter(fn ($c) => ctype_digit((string) $c))->map(fn ($c) => (int) $c)->max() ?? 0;
        for ($n = $max + 1; ; $n++) {
            if (! $exists((string) $n)) {
                return (string) $n;
            }
        }
    }

    private function operable(int $tenantId, int $assetId): object
    {
        $asset = $this->book->asset($tenantId, $assetId, true);
        if (! in_array($asset->status, ['active', 'fully_depreciated'], true)) {
            throw ValidationException::withMessages(['status' => $asset->status === 'draft' ? 'فعّل الأصل أولًا.' : 'الأصل مستبعد.']);
        }

        return $asset;
    }

    private function assertAfterLastMovement(int $tenantId, object $asset, string $date, bool $sameDayAsDepreciationOk = false): void
    {
        $latest = $this->book->latestTransaction($tenantId, (int) $asset->id);
        if ($latest && $date < $latest->transaction_date) {
            throw ValidationException::withMessages(['date' => 'التاريخ يسبق آخر حركة على الأصل ('.$latest->transaction_date.').']);
        }
        if ($asset->depreciated_until && ($sameDayAsDepreciationOk ? $date < $asset->depreciated_until : $date <= $asset->depreciated_until)) {
            throw ValidationException::withMessages(['date' => 'تم اهتلاك الأصل حتى '.$asset->depreciated_until.'؛ اختر تاريخًا بعده أو اعكس المذكرة.']);
        }
    }

    /** Depreciates this one asset up to $to (inclusive) when anything is due. */
    private function catchUp(Request $request, int $tenantId, object $asset, string $to, ?int $actorId, string $trigger): void
    {
        if ($asset->status !== 'active' || ! DepreciationCalculator::depreciates($asset->method) || $to < $asset->depreciation_start_date) {
            return;
        }
        $this->runs->run($request, $tenantId, ['periodEnd' => $to, 'assetId' => (int) $asset->id, 'description' => 'اهتلاك تلقائي قبل '.$this->triggerLabel($trigger)], $actorId, $trigger, true);
    }

    private function triggerLabel(string $trigger): string
    {
        return ['addition' => 'الإضافة', 'disposal' => 'الاستبعاد', 'transfer' => 'النقل'][$trigger] ?? $trigger;
    }

    private function assertPostable(int $tenantId, int $accountId, string $field): int
    {
        if (! DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $accountId)->where('is_active', true)->whereNull('deleted_at')->exists()) {
            throw ValidationException::withMessages([$field => 'الحساب غير موجود أو غير مفعّل.']);
        }

        return $accountId;
    }

    private function assertBranch(int $tenantId, int $branchId, ?int $actorId): void
    {
        if (! DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->whereNull('deleted_at')->exists()) {
            throw ValidationException::withMessages(['branchId' => 'الفرع غير موجود.']);
        }
        if ($actorId) {
            FinancialActor::assertBranchAccess($actorId, $tenantId, $branchId);
        }
    }

    private function assertLocation(int $tenantId, mixed $locationId, ?int $branchId): void
    {
        if (! $locationId) {
            return;
        }
        $location = DB::table('asset_locations')->where('tenant_id', $tenantId)->where('id', $locationId)->whereNull('deleted_at')->first();
        if (! $location || ($location->branch_id ? (int) $location->branch_id : null) !== $branchId) {
            throw ValidationException::withMessages(['locationId' => 'الموقع الفرعي لا يتبع لفرع الأصل.']);
        }
    }

    private function branchName(int $tenantId, ?int $branchId): string
    {
        return $branchId ? (string) DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->value('name') : 'الإدارة العامة';
    }
}
