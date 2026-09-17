<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Purchasing Phase 3 — additional charges (landed cost / standalone expense)
 * and the whole-invoice discount, layered onto the Phase 1 lines-based
 * invoice without touching the "one line_type per invoice" constraint:
 * charges are a structurally separate array, not another `lines[]` entry.
 */
class PurchasingPhase3ApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_capitalized_charge_is_allocated_by_value_and_raises_derived_unit_cost(): void
    {
        $tenant = $this->tenant('phase3-landed-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $beansId = $this->inventoryItem($headers, 'kg');
        $milkId = $this->inventoryItem($headers, 'liter');

        $payload = [
            'supplierId' => $supplierId, 'invoiceNumber' => 'LANDED-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory',
            'lines' => [
                ['lineType' => 'inventory', 'description' => 'Beans', 'inventoryItemId' => $beansId, 'quantity' => '10.000', 'lineGrossAmount' => '300.00'],
                ['lineType' => 'inventory', 'description' => 'Milk', 'inventoryItemId' => $milkId, 'quantity' => '10.000', 'lineGrossAmount' => '700.00'],
            ],
            'charges' => [
                ['description' => 'Transport', 'treatment' => 'capitalize', 'amount' => '100.00'],
            ],
        ];
        $created = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertCreated();
        // Beans: 30% share -> +30.00 landed cost -> net 330.00 / qty 10 = 33.0000; Milk: 70% -> +70.00 -> 770.00 / 10 = 77.0000.
        $created->assertJsonPath('data.lines.0.allocatedLandedCost', '30.00')
            ->assertJsonPath('data.lines.0.unitPrice', '33.0000')
            ->assertJsonPath('data.lines.1.allocatedLandedCost', '70.00')
            ->assertJsonPath('data.lines.1.unitPrice', '77.0000')
            // Line totals (the commercial/AP amount) are untouched by a capitalized charge.
            ->assertJsonPath('data.lines.0.lineTotal', '300.00')
            ->assertJsonPath('data.lines.1.lineTotal', '700.00')
            ->assertJsonPath('data.chargesAmount', '100.00')
            ->assertJsonPath('data.totalAmount', '1100.00');
        $this->assertSame(1, count($created->json('data.charges')));
        $this->assertSame('capitalize', $created->json('data.charges.0.treatment'));
    }

    public function test_expense_only_charge_never_touches_inventory_cost_and_posts_to_its_own_account(): void
    {
        $tenant = $this->tenant('phase3-expense-charge-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers, 'kg');
        $rentCategoryId = $this->expenseCategory($tenant, $headers, '6100');

        $payload = [
            'supplierId' => $supplierId, 'invoiceNumber' => 'HOSP-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory',
            'lines' => [
                ['lineType' => 'inventory', 'description' => 'Beans', 'inventoryItemId' => $itemId, 'quantity' => '10.000', 'lineGrossAmount' => '300.00'],
            ],
            'charges' => [
                ['description' => 'Hospitality', 'treatment' => 'expense', 'expenseCategoryId' => $rentCategoryId, 'amount' => '50.00'],
            ],
        ];
        $id = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertCreated()
            ->assertJsonPath('data.lines.0.allocatedLandedCost', '0.00')
            ->assertJsonPath('data.lines.0.unitPrice', '30.0000')
            ->assertJsonPath('data.chargesAmount', '50.00')
            ->assertJsonPath('data.totalAmount', '350.00')
            ->json('data.id');

        $this->postJson("/api/v1/finance/supplier-invoices/{$id}/post", ['idempotencyKey' => 'hosp-post-1'], $headers)->assertOk();

        $inventoryAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1100')->value('id');
        $rentAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6100')->value('id');
        $journalId = DB::table('supplier_invoices')->where('id', $id)->value('journal_entry_id');
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $journalId)->get();
        $this->assertSame(300.0, (float) $lines->firstWhere('financial_account_id', $inventoryAccountId)->debit);
        $this->assertSame(50.0, (float) $lines->firstWhere('financial_account_id', $rentAccountId)->debit);
        $apAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '2000')->value('id');
        $this->assertSame(350.0, (float) $lines->firstWhere('financial_account_id', $apAccountId)->credit);

        // Inventory quantity/cost is still untouched by posting — only a Goods Receipt moves WAC.
        $this->assertSame('1.0000', DB::table('inventory_items')->where('id', $itemId)->value('latest_unit_cost'));
    }

    public function test_capitalize_treatment_is_rejected_when_the_invoice_lines_are_not_inventory(): void
    {
        $tenant = $this->tenant('phase3-reject-capitalize-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $categoryId = $this->expenseCategory($tenant, $headers, '6120');

        $payload = [
            'supplierId' => $supplierId, 'invoiceNumber' => 'SVC-CHG-1', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01',
            'invoiceType' => 'expense', 'expenseCategoryId' => $categoryId,
            'lines' => [['lineType' => 'expense', 'description' => 'Internet', 'quantity' => '1', 'lineGrossAmount' => '100.00']],
            'charges' => [['description' => 'Delivery', 'treatment' => 'capitalize', 'amount' => '10.00']],
        ];
        $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertUnprocessable()->assertJsonValidationErrors('charges');
    }

    public function test_invoice_level_discount_is_allocated_proportionally_and_reduces_line_totals(): void
    {
        $tenant = $this->tenant('phase3-invoice-discount-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $beansId = $this->inventoryItem($headers, 'kg');
        $milkId = $this->inventoryItem($headers, 'liter');

        $payload = [
            'supplierId' => $supplierId, 'invoiceNumber' => 'DISC-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory',
            'discountType' => 'fixed', 'discountValue' => '100.00',
            'lines' => [
                ['lineType' => 'inventory', 'description' => 'Beans', 'inventoryItemId' => $beansId, 'quantity' => '10.000', 'lineGrossAmount' => '300.00'],
                ['lineType' => 'inventory', 'description' => 'Milk', 'inventoryItemId' => $milkId, 'quantity' => '10.000', 'lineGrossAmount' => '700.00'],
            ],
        ];
        $created = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertCreated();
        // 30/70 split of the 100.00 discount -> Beans 30.00, Milk 70.00.
        $created->assertJsonPath('data.lines.0.allocatedDiscount', '30.00')
            ->assertJsonPath('data.lines.0.lineTotal', '270.00')
            ->assertJsonPath('data.lines.0.unitPrice', '27.0000')
            ->assertJsonPath('data.lines.1.allocatedDiscount', '70.00')
            ->assertJsonPath('data.lines.1.lineTotal', '630.00')
            ->assertJsonPath('data.lines.1.unitPrice', '63.0000')
            ->assertJsonPath('data.discountAmount', '100.00')
            ->assertJsonPath('data.subtotal', '900.00')
            ->assertJsonPath('data.totalAmount', '900.00');
    }

    public function test_invoice_discount_cannot_exceed_the_items_net_total(): void
    {
        $tenant = $this->tenant('phase3-discount-cap-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers, 'kg');

        $payload = [
            'supplierId' => $supplierId, 'invoiceNumber' => 'DISC-CAP-1', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory',
            'discountType' => 'fixed', 'discountValue' => '999.00',
            'lines' => [['lineType' => 'inventory', 'description' => 'Beans', 'inventoryItemId' => $itemId, 'quantity' => '1', 'lineGrossAmount' => '100.00']],
        ];
        $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertUnprocessable()->assertJsonValidationErrors('discountValue');
    }

    public function test_landed_cost_adjusted_unit_cost_flows_into_wac_on_goods_receipt(): void
    {
        $tenant = $this->tenant('phase3-wac-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $warehouseId = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'kg', [$warehouseId]);

        $payload = [
            'supplierId' => $supplierId, 'invoiceNumber' => 'WAC-LANDED-1', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory',
            'lines' => [
                ['lineType' => 'inventory', 'description' => 'Beans', 'inventoryItemId' => $itemId, 'quantity' => '10.000', 'lineGrossAmount' => '300.00', 'warehouseId' => $warehouseId],
            ],
            'charges' => [['description' => 'Transport', 'treatment' => 'capitalize', 'amount' => '30.00']],
        ];
        $invoiceId = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertCreated()
            // (300 + 30) / 10 = 33.0000 per kg.
            ->assertJsonPath('data.lines.0.unitPrice', '33.0000')->json('data.id');
        $this->postJson("/api/v1/finance/supplier-invoices/{$invoiceId}/post", ['idempotencyKey' => 'wac-landed-post-1'], $headers)->assertOk();
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');

        $receiptId = $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', [
            'idempotencyKey' => 'wac-landed-grn-1', 'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '10.000', 'warehouseId' => $warehouseId]],
        ], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/purchase-receipts/{$receiptId}/post", ['idempotencyKey' => 'wac-landed-grn-1-post'], $headers)->assertOk();

        $this->assertSame('33.0000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $itemId)->value('average_unit_cost'));
    }

    private function warehouse(array $headers): int
    {
        return (int) $this->postJson('/api/v1/warehouses', [
            'name' => 'Central Warehouse '.uniqid(), 'code' => 'WH-'.strtoupper(uniqid()), 'type' => 'central', 'branchId' => null, 'isActive' => true,
        ], $headers)->assertCreated()->json('data.id');
    }

    private function tenant(string $slug): int
    {
        $tenantId = DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['tenant_id' => $tenantId, 'name' => 'Central Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(\App\Services\FinancialSetupService::class)->ensureForTenant($tenantId);

        return (int) $tenantId;
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        if (! $userId) {
            $userId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantId, 'name' => 'Purchasing Owner', 'email' => "purchasing-owner-$tenantId@example.test", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        }
        $plainToken = "purchasing-test-$tenantId-$userId";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'purchasing-feature-test'], ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }

    private function supplier(array $headers): int
    {
        return (int) $this->postJson('/api/v1/finance/suppliers', ['name' => 'Purchasing Test Supplier '.uniqid()], $headers)->assertCreated()->json('data.id');
    }

    private function expenseCategory(int $tenant, array $headers, string $accountCode): int
    {
        $account = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', $accountCode)->value('id');

        return (int) $this->postJson('/api/v1/finance/expense-categories', ['code' => 'PCAT-'.uniqid(), 'name' => 'Purchasing Category', 'financialAccountId' => $account, 'isActive' => true], $headers)->assertCreated()->json('data.id');
    }

    private function inventoryItem(array $headers, string $unit, array $warehouseIds = []): int
    {
        return (int) $this->postJson('/api/v1/inventory/items', [
            'nameAr' => 'صنف اختبار', 'nameEn' => 'Purchasing Test Item '.uniqid(), 'sku' => 'PUR-'.strtoupper(uniqid()),
            'itemType' => 'raw_material', 'unit' => $unit, 'minimumStock' => '0.000', 'reorderLevel' => '0.000',
            'latestUnitCost' => '1.0000', 'isActive' => true, 'warehouseIds' => $warehouseIds,
        ], $headers)->assertCreated()->json('data.id');
    }
}
