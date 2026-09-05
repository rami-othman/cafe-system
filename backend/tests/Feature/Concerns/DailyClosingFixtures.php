<?php

namespace Tests\Feature\Concerns;

use Illuminate\Support\Facades\DB;
use App\Support\FinanceAccess;

/**
 * Shared fixture builders for the Phase 9 Daily Closing test suite. Every
 * helper writes directly to the query-builder-only schema (no Eloquent
 * models exist in this codebase) so tests can construct precisely-dated
 * financial rows without going through the full POS/expense/supplier HTTP
 * flows already covered by their own Phase 3-8 test suites.
 */
trait DailyClosingFixtures
{
    protected function tenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
    }

    protected function branchId(int $tenant, string $name = 'Downtown'): int
    {
        return (int) DB::table('branches')->where('tenant_id', $tenant)->where('name', $name)->value('id');
    }

    protected function headers(int $tenant, string $role = 'owner', string $tag = 'dc', ?int $branch = null): array
    {
        $email = "$tag-$role-$tenant@test.local";
        $userId = (int) DB::table('users')->where('tenant_id', $tenant)->where('email', $email)->value('id');
        if (! $userId) {
            $userId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => ucfirst($tag), 'email' => $email, 'password' => bcrypt('x'), 'role' => $role, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        }
        if ($role !== 'owner' && $branch) {
            DB::table('user_branches')->updateOrInsert(['tenant_id' => $tenant, 'user_id' => $userId, 'branch_id' => $branch], ['created_at' => now(), 'updated_at' => now()]);
        }
        if ($role === 'manager') {
            foreach (FinanceAccess::defaultPermissionsForRole('manager') as $permission) {
                DB::table('finance_role_permissions')->updateOrInsert(['tenant_id' => $tenant, 'role' => 'manager', 'permission' => $permission], ['created_at' => now(), 'updated_at' => now()]);
            }
        }
        $token = "$tag-$role-$tenant-token";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenant, 'user_id' => $userId, 'name' => $tag], ['token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $token", 'X-Tenant-Id' => $tenant];
    }

    protected function accountId(int $tenant, string $code): int
    {
        return (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', $code)->value('id');
    }

    protected function locationId(int $tenant, string $code): int
    {
        return (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', $code)->value('id');
    }

    /** A new active card payment method, backed by its own settlement account, active/independent per test. */
    protected function makeCardPaymentMethod(int $tenant, string $code): array
    {
        $accountId = (int) DB::table('financial_accounts')->insertGetId(['tenant_id' => $tenant, 'code' => $code, 'name_ar' => $code, 'name_en' => $code, 'account_group' => 'assets', 'normal_balance' => 'debit', 'is_active' => true, 'is_system_protected' => false, 'created_at' => now(), 'updated_at' => now()]);
        $methodId = (int) DB::table('payment_methods')->insertGetId(['tenant_id' => $tenant, 'code' => $code, 'name' => $code, 'type' => 'card', 'financial_account_id' => $accountId, 'is_active' => true, 'sort_order' => 5, 'created_at' => now(), 'updated_at' => now()]);

        return ['methodId' => $methodId, 'accountId' => $accountId];
    }

    protected function makeOrder(int $tenant, int $branch, string $amount, string $closedAt, string $paymentStatus = 'paid'): int
    {
        return (int) DB::table('orders')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'order_number' => 'DC-'.uniqid(), 'type' => 'takeaway',
            'status' => 'closed', 'payment_status' => $paymentStatus, 'subtotal' => $amount, 'discount_total' => '0.00',
            'tax_total' => '0.00', 'service_total' => '0.00', 'total' => $amount, 'closed_at' => $closedAt,
            'created_at' => $closedAt, 'updated_at' => $closedAt,
        ]);
    }

    protected function makePayment(int $tenant, int $branch, int $orderId, string $amount, string $paidAt, string $method = 'cash', ?int $paymentMethodId = null): int
    {
        // Most fixtures model the configured default cash method. Tests that
        // exercise legacy/unmapped methods insert those rows explicitly.
        if ($paymentMethodId === null && $method === 'cash') {
            $paymentMethodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id') ?: null;
        }

        return (int) DB::table('payments')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'order_id' => $orderId, 'method' => $method,
            'payment_method_id' => $paymentMethodId, 'amount' => $amount, 'status' => 'completed', 'paid_at' => $paidAt,
            'created_at' => $paidAt, 'updated_at' => $paidAt,
        ]);
    }

    protected function makeRefund(int $tenant, int $branch, int $orderId, ?int $paymentId, string $amount, string $refundedAt, string $type = 'partial'): int
    {
        return (int) DB::table('payment_refunds')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'order_id' => $orderId, 'payment_id' => $paymentId,
            'refund_number' => 'DCR-'.uniqid(), 'type' => $type, 'amount' => $amount, 'status' => 'completed',
            'refunded_at' => $refundedAt, 'created_at' => $refundedAt, 'updated_at' => $refundedAt,
        ]);
    }

    protected function makeShift(int $tenant, int $branch, int $userId, string $openingCash, string $openedAt, ?string $closedAt = null, string $status = 'closed'): int
    {
        return (int) DB::table('shifts')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'user_id' => $userId, 'opening_cash' => $openingCash,
            'closing_cash' => $closedAt ? $openingCash : null, 'status' => $status, 'opened_at' => $openedAt,
            'closed_at' => $closedAt, 'created_at' => $openedAt, 'updated_at' => $closedAt ?? $openedAt,
        ]);
    }

    protected function expenseCategoryId(int $tenant, string $accountCode = '6190'): int
    {
        $code = 'DC-CAT';
        $existing = (int) DB::table('expense_categories')->where('tenant_id', $tenant)->where('code', $code)->value('id');
        if ($existing) {
            return $existing;
        }

        return (int) DB::table('expense_categories')->insertGetId([
            'tenant_id' => $tenant, 'code' => $code, 'name' => 'Daily Closing Test Category',
            'financial_account_id' => $this->accountId($tenant, $accountCode), 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    protected function makeExpense(int $tenant, int $branch, string $amount, string $expenseDate, string $status = 'paid', ?string $locationCode = 'CASH-DRAWER'): int
    {
        $paidLocationId = $locationCode ? $this->locationId($tenant, $locationCode) : null;

        return (int) DB::table('expenses')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'expense_number' => 'DCE-'.uniqid(),
            'expense_category_id' => $this->expenseCategoryId($tenant), 'amount' => $amount, 'tax_amount' => '0.00',
            'total_amount' => $amount, 'expense_date' => $expenseDate, 'description' => 'Daily closing test expense',
            'status' => $status, 'payment_status' => $status === 'paid' ? 'paid' : 'unpaid',
            'paid_from_financial_location_id' => $status === 'paid' ? $paidLocationId : null,
            'paid_at' => $status === 'paid' ? $expenseDate : null,
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    /** Posts a real, ledger-effective expense (draft -> pending_approval -> approved -> paid) via ExpenseService, for tests that need actual journal_entry_lines against an expenses-group account. */
    protected function postExpense(int $tenant, int $branch, string $date, string $amount, string $locationCode = 'CASH-DRAWER'): int
    {
        $request = \Illuminate\Http\Request::create('/expenses-test', 'POST');
        $actor = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        $category = $this->expenseCategoryId($tenant);
        $location = $this->locationId($tenant, $locationCode);
        $accountId = (int) DB::table('financial_locations')->where('id', $location)->value('financial_account_id');
        $method = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('financial_account_id', $accountId)->value('id');
        if (! $method) {
            $method = (int) DB::table('payment_methods')->insertGetId(['tenant_id' => $tenant, 'code' => $locationCode.'-PM', 'name' => $locationCode, 'type' => $locationCode === 'BANK' ? 'bank_transfer' : 'cash', 'financial_account_id' => $accountId, 'financial_location_id' => $location, 'is_active' => true, 'sort_order' => 9, 'created_at' => now(), 'updated_at' => now()]);
        }
        $service = app(\App\Services\ExpenseService::class);
        $expenseId = $service->create($request, $tenant, ['branchId' => $branch, 'expenseCategoryId' => $category, 'amount' => $amount, 'taxAmount' => '0.00', 'expenseDate' => $date, 'description' => 'Dashboard test expense', 'idempotencyKey' => 'dash-exp-'.uniqid()], $actor)->id;
        $service->transition($request, $tenant, $expenseId, 'submit', [], $actor);
        $service->transition($request, $tenant, $expenseId, 'approve', [], $actor);
        $service->pay($request, $tenant, $expenseId, ['paymentMethodId' => $method, 'financialLocationId' => $location, 'paymentDate' => $date, 'idempotencyKey' => 'dash-exp-pay-'.uniqid()], $actor);

        return $expenseId;
    }

    protected function supplierId(int $tenant): int
    {
        return (int) DB::table('suppliers')->insertGetId([
            'tenant_id' => $tenant, 'supplier_number' => 'DCS-'.uniqid(), 'name' => 'Daily Closing Test Supplier',
            'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    protected function makeSupplierInvoice(int $tenant, int $branch, int $supplier, string $amount, string $invoiceDate): int
    {
        return (int) DB::table('supplier_invoices')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'supplier_id' => $supplier,
            'internal_reference' => 'DCI-'.uniqid(), 'invoice_number' => 'INV-'.uniqid(),
            'invoice_date' => $invoiceDate, 'due_date' => $invoiceDate, 'invoice_type' => 'other',
            'debit_account_id' => $this->accountId($tenant, '6190'), 'subtotal' => $amount, 'tax_amount' => '0.00',
            'total_amount' => $amount, 'status' => 'posted', 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    protected function makeSupplierPayment(int $tenant, int $branch, int $supplier, string $amount, string $paymentDate, string $locationCode = 'CASH-DRAWER'): int
    {
        $method = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');

        return (int) DB::table('supplier_payments')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'supplier_id' => $supplier, 'payment_number' => 'DCP-'.uniqid(),
            'payment_date' => $paymentDate, 'amount' => $amount, 'payment_method_id' => $method,
            'financial_location_id' => $this->locationId($tenant, $locationCode), 'status' => 'posted',
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    /** Direct fixture insert (bypasses InventoryPostingService/InventoryAccountingMapper) for simulating a legacy/broken posting state. */
    protected function makeStockMovementRaw(int $tenant, int $branch, string $type, string $totalCost, string $occurredAt, string $quantityOut = '0.000'): int
    {
        $warehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', 'BR-'.$branch.'-MAIN')->value('id');
        if (! $warehouseId) {
            $warehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', 'CENTRAL')->value('id');
        }
        $itemId = $this->inventoryItemId($tenant);

        return (int) DB::table('stock_movements')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'warehouse_id' => $warehouseId, 'inventory_item_id' => $itemId,
            'type' => $type, 'quantity' => '1.000', 'quantity_in' => $quantityOut === '0.000' ? '1.000' : '0.000',
            'quantity_out' => $quantityOut, 'quantity_before' => '10.000', 'quantity_after' => '9.000',
            'unit_cost' => $totalCost, 'total_cost' => $totalCost, 'reason' => 'Daily closing test fixture',
            'occurred_at' => $occurredAt, 'created_at' => $occurredAt, 'updated_at' => $occurredAt,
        ]);
    }

    protected function inventoryItemId(int $tenant): int
    {
        $existing = (int) DB::table('inventory_items')->where('tenant_id', $tenant)->where('sku', 'DC-ITEM')->value('id');
        if ($existing) {
            return $existing;
        }

        return (int) DB::table('inventory_items')->insertGetId([
            'tenant_id' => $tenant, 'name' => 'DC Item', 'name_ar' => 'DC Item', 'name_en' => 'DC Item', 'sku' => 'DC-ITEM',
            'catalog_identity' => 'dc-item', 'item_type' => 'raw_material', 'unit' => 'unit', 'minimum_stock' => '0.000',
            'reorder_level' => '0.000', 'cost_per_unit' => '0.0000', 'latest_unit_cost' => '0.0000', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    protected function completeCashReconciliation(int $tenant, int $branch, string $date, string $accountCode = '1010'): int
    {
        return (int) DB::table('financial_reconciliations')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'financial_account_id' => $this->accountId($tenant, $accountCode),
            'reference' => 'DCR-'.uniqid(), 'type' => 'cash', 'status' => 'completed', 'date_from' => $date, 'date_to' => $date,
            'book_opening_balance' => '0.00', 'book_closing_balance' => '0.00', 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    protected function makeJournal(int $tenant, ?int $branch, string $entryDate, string $status, string $postedAt, string $sourceType = 'manual', ?int $sourceId = null): int
    {
        return (int) DB::table('journal_entries')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'entry_number' => 'DCJ-'.uniqid(), 'entry_date' => $entryDate,
            'source_type' => $sourceType, 'source_id' => $sourceId, 'status' => $status,
            'posted_at' => $status === 'posted' ? $postedAt : null, 'created_at' => $postedAt, 'updated_at' => $postedAt,
        ]);
    }
}
