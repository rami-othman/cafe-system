<?php

namespace Database\Seeders;

use App\Models\User;
use App\Services\CashTransferService;
use App\Services\AccountingPeriodService;
use App\Services\DailyClosingService;
use App\Services\ExpenseService;
use App\Services\FinancialReconciliationQueryService;
use App\Services\FinancialReconciliationService;
use App\Services\FinancialSetupService;
use App\Services\SupplierInvoiceService;
use App\Services\SupplierPaymentService;
use App\Services\SupplierService;
use Illuminate\Database\Seeder;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use App\Support\Money;
use RuntimeException;

/**
 * Service-backed finance activity for the normal local Cafe 618 tenant.
 *
 * This deliberately complements, rather than replaces,
 * FinanceOperationsDemoSeeder: that seeder remains the isolated integration
 * fixture used by its existing test suite.  All mutable finance effects here
 * have a deterministic per-day scenario key and are created through the same
 * services used by production requests.
 */
final class Cafe618FinanceOperationsDemoSeeder extends Seeder
{
    private int $tenantId;
    private int $ownerId;
    private int $branchId;
    private Carbon $today;

    public function run(): void
    {
        if (! app()->environment(['local', 'development', 'testing'])) {
            throw new RuntimeException('Cafe618FinanceOperationsDemoSeeder is restricted to local, development, and testing environments.');
        }

        $this->today = now()->startOfDay();
        $this->tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $owner = User::query()->where('tenant_id', $this->tenantId)->where('role', 'owner')->first();
        $branch = DB::table('branches')->where('tenant_id', $this->tenantId)->whereNull('deleted_at')->orderBy('id')->first();
        if (! $this->tenantId || ! $owner || ! $branch) {
            return;
        }

        $this->ownerId = (int) $owner->id;
        $this->branchId = (int) $branch->id;
        app(FinancialSetupService::class)->ensureForTenant($this->tenantId, $this->branchId, $this->ownerId);
        $this->ensureBankPaymentMethod();

        $request = Request::create('/seed/cafe-618/finance-operations', 'POST');
        $request->attributes->set('tenant_id', $this->tenantId);
        $request->attributes->set('auth_user', $owner);

        $this->seedExpenseWorkflow($request);
        $this->seedAccountsPayable($request);
        $this->seedCashTransfers($request);
        $this->seedFinancialControls($request);
    }

    private function scenario(string $name): string
    {
        return 'cafe-618-finance-'.$this->today->format('Ymd').'-'.$name;
    }

    private function date(int $daysAgo): string
    {
        return $this->today->copy()->subDays($daysAgo)->toDateString();
    }

    private function ensureBankPaymentMethod(): void
    {
        $account = DB::table('financial_accounts')->where('tenant_id', $this->tenantId)->where('code', '1030')->value('id');
        $location = DB::table('financial_locations')->where('tenant_id', $this->tenantId)->where('code', 'BANK')->value('id');
        if (! $account || ! $location) {
            throw new RuntimeException('Cafe 618 financial setup is missing the Bank account/location.');
        }

        DB::table('payment_methods')->updateOrInsert(
            ['tenant_id' => $this->tenantId, 'code' => 'BANK'],
            [
                'name' => 'Bank Transfer',
                'type' => 'bank',
                'financial_account_id' => $account,
                'financial_location_id' => $location,
                'is_active' => true,
                'sort_order' => 3,
                'created_by' => $this->ownerId,
                'updated_by' => $this->ownerId,
                'created_at' => now(),
                'updated_at' => now(),
            ],
        );
    }

    /** @return array<string, int> */
    private function categories(): array
    {
        $definitions = [
            'RENT' => ['Rent', '6100'],
            'UTILITIES' => ['Utilities', '6120'],
            'MAINTENANCE' => ['Maintenance', '6130'],
            'MARKETING' => ['Marketing', '6140'],
            'TRANSPORT' => ['Transport and deliveries', '6190'],
            'OPERATIONS' => ['Other Operating Expenses', '6190'],
        ];
        $result = [];
        foreach ($definitions as $code => [$name, $accountCode]) {
            $accountId = DB::table('financial_accounts')->where('tenant_id', $this->tenantId)->where('code', $accountCode)->value('id');
            if (! $accountId) {
                throw new RuntimeException("Cafe 618 is missing financial account {$accountCode}.");
            }
            DB::table('expense_categories')->updateOrInsert(
                ['tenant_id' => $this->tenantId, 'code' => 'CAFE618-'.$code],
                ['name' => $name, 'financial_account_id' => $accountId, 'is_active' => true, 'sort_order' => count($result) + 1, 'created_by' => $this->ownerId, 'updated_by' => $this->ownerId, 'created_at' => now(), 'updated_at' => now()],
            );
            $result[$code] = (int) DB::table('expense_categories')->where('tenant_id', $this->tenantId)->where('code', 'CAFE618-'.$code)->value('id');
        }

        return $result;
    }

    private function seedExpenseWorkflow(Request $request): void
    {
        $categories = $this->categories();
        $this->expense($request, $categories['UTILITIES'], 'Electricity bill', '185.00', 35, 'paid');
        $this->expense($request, $categories['RENT'], 'Monthly rent', '1,250.00', 28, 'paid');
        $this->expense($request, $categories['MAINTENANCE'], 'Espresso machine maintenance', '145.00', 18, 'approved');
        $this->expense($request, $categories['MARKETING'], 'Neighborhood social media campaign', '95.00', 7, 'pending');
        $this->expense($request, $categories['TRANSPORT'], 'Supplier delivery and transport', '48.00', 12, 'paid');
        $this->expense($request, $categories['OPERATIONS'], 'Counter supplies delivery', '38.00', 0, 'paid');
        $this->expense($request, $categories['OPERATIONS'], 'Cleaning service invoice', '72.50', 4, 'rejected');
        $this->expense($request, $categories['UTILITIES'], 'Internet subscription', '55.00', 1, 'draft');
    }

    private function expense(Request $request, int $categoryId, string $description, string $amount, int $daysAgo, string $targetState): void
    {
        $key = $this->scenario('expense-'.strtolower(str_replace(' ', '-', $description)));
        $service = app(ExpenseService::class);
        $expense = $service->create($request, $this->tenantId, [
            'branchId' => $this->branchId,
            'expenseCategoryId' => $categoryId,
            'amount' => str_replace(',', '', $amount),
            'expenseDate' => $this->date($daysAgo),
            'description' => $description,
            'idempotencyKey' => $key,
        ], $this->ownerId);

        if ($targetState === 'draft' || $expense->status === 'paid' || $expense->status === 'rejected') {
            return;
        }
        if ($expense->status === 'draft') {
            $expense = $service->transition($request, $this->tenantId, $expense->id, 'submit', [], $this->ownerId);
        }
        if ($targetState === 'rejected' && $expense->status === 'pending_approval') {
            $service->transition($request, $this->tenantId, $expense->id, 'reject', ['rejectionReason' => 'Vendor quotation needs a revised scope.'], $this->ownerId);
            return;
        }
        if (in_array($targetState, ['approved', 'paid'], true) && $expense->status === 'pending_approval') {
            $expense = $service->transition($request, $this->tenantId, $expense->id, 'approve', [], $this->ownerId);
        }
        if ($targetState === 'paid' && $expense->status === 'approved') {
            $service->pay($request, $this->tenantId, $expense->id, [
                'paymentMethodId' => $this->paymentMethod('CASH'),
                'financialLocationId' => $this->location('CASH-DRAWER'),
                'paymentDate' => $this->date($daysAgo),
                'idempotencyKey' => $key.'-payment',
            ], $this->ownerId);
        }
    }

    private function seedAccountsPayable(Request $request): void
    {
        $roaster = $this->supplier($request, 'Damascus Coffee Roasters', 'orders@damascus-roasters.local', 15);
        $dairy = $this->supplier($request, 'Levant Dairy Supply', 'accounts@levant-dairy.local', 7);
        $packaging = $this->supplier($request, 'Cedar Packaging Co.', 'billing@cedar-packaging.local', 30);
        $maintenance = $this->supplier($request, 'Barista Equipment Services', 'service@barista-equipment.local', 30);

        $beans = $this->invoice($request, $roaster, 'BEANS-'.$this->today->format('Ymd'), 'Coffee beans invoice', '420.00', 42, 20);
        $this->payment($request, $roaster, [$beans => '210.00'], '210.00', 25, 'partial-beans');
        $milk = $this->invoice($request, $dairy, 'DAIRY-'.$this->today->format('Ymd'), 'Fresh milk and oat milk supply', '185.00', 19, 12);
        $this->payment($request, $dairy, [$milk => '185.00'], '185.00', 10, 'paid-dairy');
        $this->invoice($request, $packaging, 'PACK-'.$this->today->format('Ymd'), '12oz cups, lids, and sleeves', '310.00', 16, 2);
        $this->invoice($request, $maintenance, 'MAINT-'.$this->today->format('Ymd'), 'Grinder calibration and preventive maintenance', '160.00', 5, 25);
        $draft = $this->invoice($request, $packaging, 'PACK-DRAFT-'.$this->today->format('Ymd'), 'Next delivery quotation awaiting verification', '95.00', 1, 14, false);
        unset($draft);
        $filters = $this->invoice($request, $roaster, 'FILTERS-'.$this->today->format('Ymd'), 'Paper filters and cleaning tablets', '180.00', 14, 14);
        $syrups = $this->invoice($request, $roaster, 'SYRUPS-'.$this->today->format('Ymd'), 'Seasonal syrup restock', '120.00', 14, 14);
        $this->payment($request, $roaster, [$filters => '125.00', $syrups => '75.00'], '200.00', 8, 'multi-invoice-roaster');
    }

    private function supplier(Request $request, string $name, string $email, int $terms): int
    {
        $existing = DB::table('suppliers')->where('tenant_id', $this->tenantId)->where('email', $email)->whereNull('deleted_at')->value('id');
        if ($existing) {
            return (int) $existing;
        }

        return app(SupplierService::class)->create($request, $this->tenantId, ['name' => $name, 'email' => $email, 'paymentTermsDays' => $terms], $this->ownerId);
    }

    private function invoice(Request $request, int $supplierId, string $number, string $description, string $subtotal, int $daysAgo, int $dueInDays, bool $post = true): int
    {
        $key = $this->scenario('invoice-'.strtolower($number));
        $date = $this->today->copy()->subDays($daysAgo);
        $service = app(SupplierInvoiceService::class);
        $invoice = $service->create($request, $this->tenantId, [
            'branchId' => $this->branchId,
            'supplierId' => $supplierId,
            'invoiceNumber' => $number,
            'invoiceDate' => $date->toDateString(),
            'dueDate' => $date->copy()->addDays($dueInDays)->toDateString(),
            'invoiceType' => 'inventory',
            'subtotal' => $subtotal,
            'description' => $description,
            'idempotencyKey' => $key,
        ], $this->ownerId);
        if ($post && $invoice->status === 'draft') {
            $invoice = $service->post($request, $this->tenantId, $invoice->id, ['idempotencyKey' => $key.'-post'], $this->ownerId);
        }

        return (int) $invoice->id;
    }

    /** @param array<int, string> $allocations */
    private function payment(Request $request, int $supplierId, array $allocations, string $amount, int $daysAgo, string $name): void
    {
        $key = $this->scenario('supplier-payment-'.$name);
        app(SupplierPaymentService::class)->pay($request, $this->tenantId, [
            'branchId' => $this->branchId,
            'supplierId' => $supplierId,
            'paymentMethodId' => $this->paymentMethod('BANK'),
            'financialLocationId' => $this->location('BANK'),
            'paymentDate' => $this->date($daysAgo),
            'amount' => $amount,
            'allocations' => collect($allocations)->map(fn (string $value, int $id) => ['invoiceId' => $id, 'amount' => $value])->values()->all(),
            'idempotencyKey' => $key,
        ], $this->ownerId);
    }

    private function seedCashTransfers(Request $request): void
    {
        $service = app(CashTransferService::class);
        foreach ([
            ['cash-to-bank', 'CASH-DRAWER', 'BANK', '320.00', 14, 'Cash banking deposit'],
            ['bank-to-cash', 'BANK', 'CASH-DRAWER', '150.00', 3, 'Weekend cash float replenishment'],
        ] as [$name, $from, $to, $amount, $daysAgo, $description]) {
            $service->create($request, $this->tenantId, [
                'branchId' => $this->branchId,
                'fromFinancialLocationId' => $this->location($from),
                'toFinancialLocationId' => $this->location($to),
                'amount' => $amount,
                'transferDate' => $this->date($daysAgo),
                'description' => $description,
                'idempotencyKey' => $this->scenario('cash-transfer-'.$name),
            ], $this->ownerId);
        }
    }

    /**
     * Complete two historical cash reconciliations and daily closings, then
     * expose both a locked historic period and the current open period.  The
     * rows are deliberately created through the operational services so the
     * dashboard exercises the same readiness rules as production.
     */
    private function seedFinancialControls(Request $request): void
    {
        foreach ([4, 2] as $daysAgo) {
            $date = $this->date($daysAgo);
            $this->completeCashReconciliation($request, $date);
            $this->closeBusinessDay($request, $date);
        }

        $periods = app(AccountingPeriodService::class);
        $july = DB::table('accounting_periods')
            ->where('tenant_id', $this->tenantId)
            ->where('name', 'Cafe 618 July 2026')
            ->first();
        if (! $july) {
            $july = $periods->create($request, $this->tenantId, [
                'name' => 'Cafe 618 July 2026',
                'startDate' => '2026-07-01',
                'endDate' => '2026-07-31',
                'notes' => 'Locked historical demo period with posted Cafe 618 sales activity.',
            ], $this->ownerId);
        }
        if ($july->status === 'open') {
            $readiness = $periods->readiness($this->tenantId, (int) $july->id);
            if (! $readiness['canClose']) {
                throw new RuntimeException('Cafe 618 July accounting period is not ready: '.json_encode($readiness['blockers'], JSON_THROW_ON_ERROR));
            }
            $july = $periods->close($request, $this->tenantId, (int) $july->id, $this->ownerId);
        }
        if ($july->status === 'closed') {
            $periods->lock($request, $this->tenantId, (int) $july->id, $this->ownerId);
        }

        $start = $this->today->copy()->startOfMonth()->toDateString();
        $end = $this->today->copy()->endOfMonth()->toDateString();
        $current = DB::table('accounting_periods')->where('tenant_id', $this->tenantId)
            ->where('start_date', '<=', $end)->where('end_date', '>=', $start)->first();
        if (! $current) {
            $periods->create($request, $this->tenantId, [
                'name' => 'Cafe 618 '.$this->today->format('F Y').' — Current',
                'startDate' => $start,
                'endDate' => $end,
                'notes' => 'Open operating period for the current Cafe 618 demo data.',
            ], $this->ownerId);
        }
    }

    private function completeCashReconciliation(Request $request, string $date): void
    {
        $locationId = $this->location('CASH-DRAWER');
        $accountId = (int) DB::table('financial_locations')->where('id', $locationId)->value('financial_account_id');
        $completed = DB::table('financial_reconciliations')->where('tenant_id', $this->tenantId)
            ->where('financial_account_id', $accountId)->where('status', 'completed')
            ->whereDate('date_from', '<=', $date)->whereDate('date_to', '>=', $date)->exists();
        if ($completed) {
            return;
        }

        $service = app(FinancialReconciliationService::class);
        $key = $this->scenario('cash-reconciliation-'.$date);
        $session = $service->create($request, $this->tenantId, [
            'type' => 'cash',
            'financialLocationId' => $locationId,
            'dateFrom' => $date,
            'dateTo' => $date,
            'notes' => 'Cafe 618 verified cash drawer count for '.$date,
            'idempotencyKey' => $key,
        ], $this->ownerId);
        if ($session->status === 'completed') {
            return;
        }
        $session = $service->update($request, $this->tenantId, (int) $session->id, [
            'actualCashCount' => Money::decimal(Money::cents($session->book_closing_balance)),
        ], $this->ownerId);
        $service->complete($request, $this->tenantId, (int) $session->id, $this->ownerId, app(FinancialReconciliationQueryService::class));
    }

    private function closeBusinessDay(Request $request, string $date): void
    {
        $service = app(DailyClosingService::class);
        $closing = $service->getOrCreate($request, $this->tenantId, $this->branchId, $date, $this->ownerId);
        if ($closing->status === 'closed') {
            return;
        }
        $preview = $service->preview($request, $this->tenantId, $this->branchId, $date, $this->ownerId);
        $service->update($request, $this->tenantId, (int) $closing->id, [
            'actualCash' => $preview['cash']['expectedCash'],
            'notes' => 'Cafe 618 verified cash count for '.$date,
        ], $this->ownerId);
        $preview = $service->preview($request, $this->tenantId, $this->branchId, $date, $this->ownerId);
        if (! $preview['canClose']) {
            throw new RuntimeException('Cafe 618 daily closing is not ready for '.$date.': '.json_encode(array_column($preview['blockers'], 'code'), JSON_THROW_ON_ERROR));
        }
        $service->close($request, $this->tenantId, (int) $closing->id, [
            'actualCash' => $preview['cash']['expectedCash'],
            'notes' => 'Cafe 618 completed and reconciled daily close for '.$date,
        ], $this->ownerId);
    }

    private function paymentMethod(string $code): int
    {
        return (int) DB::table('payment_methods')->where('tenant_id', $this->tenantId)->where('code', $code)->where('is_active', true)->value('id');
    }

    private function location(string $code): int
    {
        return (int) DB::table('financial_locations')->where('tenant_id', $this->tenantId)->where('code', $code)->where('is_active', true)->value('id');
    }
}
