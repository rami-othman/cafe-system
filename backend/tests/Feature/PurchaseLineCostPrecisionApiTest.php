<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * D1 — a purchase line's gross total ("إجمالي البند") is the client's natural
 * input; the server derives the canonical (repeating-decimal-safe) unit cost.
 * See SupplierInvoiceService::buildLines()/InventoryDecimal::unitCostFromTotal().
 */
class PurchaseLineCostPrecisionApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_repeating_decimal_unit_cost_is_derived_from_quantity_and_line_gross_amount(): void
    {
        $tenant = $this->tenant('d1-precision-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers, 'kg');
        $warehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->value('id');

        // 350 / 1850 = 0.189189189... — the exact repeating decimal from the
        // reported client issue. The client never types this; only quantity
        // and the line's total are sent.
        $created = $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'D1-PREC-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01',
            'invoiceType' => 'inventory',
            'lines' => [[
                'lineType' => 'inventory', 'description' => 'Bulk material', 'inventoryItemId' => $itemId, 'warehouseId' => $warehouseId,
                'quantity' => '1850.000', 'lineGrossAmount' => '350.00',
            ]],
        ], $headers)->assertCreated();

        $line = $created->json('data.lines.0');
        $this->assertSame('350.00', $line['lineGrossAmount']);
        // Rounded half-up to the stored 4dp unit-cost precision.
        $this->assertSame('0.1892', $line['unitPrice']);
        $this->assertSame('350.00', $line['lineTotal']);
    }

    public function test_third_line_invalid_input_does_not_fail_merely_because_its_index_is_two(): void
    {
        $tenant = $this->tenant('d1-precision-2');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers, 'kg');
        $warehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->value('id');

        $line = fn (string $qty, string $gross) => [
            'lineType' => 'inventory', 'description' => 'Material', 'inventoryItemId' => $itemId, 'warehouseId' => $warehouseId,
            'quantity' => $qty, 'lineGrossAmount' => $gross,
        ];

        // Three valid lines post successfully — the third line's index (2) is
        // not itself an obstacle.
        $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'D1-PREC-002', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01',
            'invoiceType' => 'inventory',
            'lines' => [$line('10.000', '100.00'), $line('20.000', '200.00'), $line('1850.000', '350.00')],
        ], $headers)->assertCreated()->assertJsonCount(3, 'data.lines');

        // A malformed third line (more than 4 decimal places on unitCost)
        // produces a clear validation error, not a silent partial post.
        $response = $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'D1-PREC-003', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01',
            'invoiceType' => 'inventory',
            'lines' => [
                $line('10.000', '100.00'),
                $line('20.000', '200.00'),
                ['lineType' => 'inventory', 'description' => 'Bad', 'inventoryItemId' => $itemId, 'warehouseId' => $warehouseId,
                    'quantity' => '5.000', 'unitCost' => '0.189189189'],
            ],
        ], $headers)->assertStatus(422);
        $response->assertJsonValidationErrors(['lines.2.unitCost']);
        $this->assertSame(0, DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('invoice_number', 'D1-PREC-003')->count());
    }

    public function test_numeric_input_forms_accepted_by_the_backend_normalization_path(): void
    {
        $tenant = $this->tenant('d1-precision-3');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers, 'kg');
        $warehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->value('id');

        // The backend only ever receives ASCII-normalized decimal strings
        // (Flutter normalizes Arabic digits/separators before submit); this
        // proves the plain "0.4" form the normalizer produces is accepted.
        $created = $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'D1-PREC-004', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01',
            'invoiceType' => 'inventory',
            'lines' => [[
                'lineType' => 'inventory', 'description' => 'Small unit', 'inventoryItemId' => $itemId, 'warehouseId' => $warehouseId,
                'quantity' => '2.000', 'unitCost' => '0.4',
            ]],
        ], $headers)->assertCreated();

        $this->assertSame('0.4000', $created->json('data.lines.0.unitPrice'));
        $this->assertSame('0.80', $created->json('data.lines.0.lineGrossAmount'));
    }

    public function test_discount_and_wac_behaviour_is_unchanged_for_gross_amount_input(): void
    {
        $tenant = $this->tenant('d1-precision-5');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers, 'kg');
        $warehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->value('id');
        DB::table('inventory_item_warehouses')->insert(['tenant_id' => $tenant, 'inventory_item_id' => $itemId, 'warehouse_id' => $warehouseId, 'created_at' => now(), 'updated_at' => now()]);
        $beforeCost = DB::table('inventory_items')->where('id', $itemId)->value('latest_unit_cost');

        $created = $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'D1-PREC-006', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01',
            'invoiceType' => 'inventory', 'receiptMode' => 'immediate', 'branchId' => (int) DB::table('branches')->where('tenant_id', $tenant)->value('id'),
            'lines' => [[
                'lineType' => 'inventory', 'description' => 'Discounted material', 'inventoryItemId' => $itemId, 'warehouseId' => $warehouseId,
                'quantity' => '100.000', 'lineGrossAmount' => '1000.00', 'discountType' => 'fixed', 'discountValue' => '100.00',
            ]],
        ], $headers)->assertCreated();
        $invoiceId = $created->json('data.id');

        $line = $created->json('data.lines.0');
        // Net of the 100.00 discount: (1000-100)/100 = 9.0000 unit cost.
        $this->assertSame('9.0000', $line['unitPrice']);
        $this->assertSame('900.00', $line['lineTotal']);

        $this->postJson("/api/v1/finance/supplier-invoices/$invoiceId/post", ['idempotencyKey' => 'd1-prec-006-post'], $headers)->assertOk();
        $afterCost = DB::table('inventory_items')->where('id', $itemId)->value('latest_unit_cost');
        $this->assertNotSame($beforeCost, $afterCost);
        $this->assertSame('9.0000', $afterCost);
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
        $plainToken = "purchasing-precision-test-$tenantId-$userId";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'purchasing-precision-test'], ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }

    private function supplier(array $headers): int
    {
        return (int) $this->postJson('/api/v1/finance/suppliers', ['name' => 'Purchasing Precision Supplier '.uniqid()], $headers)->assertCreated()->json('data.id');
    }

    private function inventoryItem(array $headers, string $unit): int
    {
        $itemId = (int) $this->postJson('/api/v1/inventory/items', [
            'nameAr' => 'صنف اختبار', 'nameEn' => 'Purchasing Precision Item '.uniqid(), 'sku' => 'PUR-PREC-'.strtoupper(uniqid()),
            'itemType' => 'raw_material', 'unit' => $unit, 'minimumStock' => '0.000', 'reorderLevel' => '0.000',
            'latestUnitCost' => '1.0000', 'isActive' => true,
        ], $headers)->assertCreated()->json('data.id');
        $tenantId = (int) DB::table('inventory_items')->where('id', $itemId)->value('tenant_id');
        if (! DB::table('warehouses')->where('tenant_id', $tenantId)->exists()) {
            $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->value('id');
            $this->postJson('/api/v1/warehouses', ['name' => 'Main Warehouse', 'code' => 'WH-'.strtoupper(uniqid()), 'type' => 'other', 'branchId' => $branchId, 'isActive' => true], $headers)->assertCreated();
        }

        return $itemId;
    }
}
