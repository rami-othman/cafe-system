<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

final class InventoryItemTabsTest extends TestCase
{
    use DailyClosingFixtures;
    use RefreshDatabase;

    public function test_posted_purchase_line_is_visible_before_receipt_with_explicit_status(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $headers = $this->headers($tenant, 'owner', 'item-tabs');
        $warehouse = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('branch_id', $branch)->where('is_active', true)->value('id');
        $item = (int) DB::table('inventory_items')->insertGetId([
            'tenant_id' => $tenant, 'name' => 'مادة اختبار', 'name_ar' => 'مادة اختبار',
            'sku' => 'TABS-'.uniqid(), 'unit' => 'kg', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $supplier = $this->supplierId($tenant);
        $invoice = $this->makeSupplierInvoice($tenant, $branch, $supplier, '25.00', '2026-09-28');
        DB::table('supplier_invoice_lines')->insert([
            'tenant_id' => $tenant, 'supplier_invoice_id' => $invoice, 'line_number' => 1,
            'line_type' => 'inventory', 'inventory_item_id' => $item, 'warehouse_id' => $warehouse,
            'description' => 'مادة اختبار', 'purchase_unit' => 'kg', 'quantity' => '5.000',
            'base_quantity' => '5.000', 'unit_price' => '5.0000', 'line_total' => '25.00',
            'received_quantity' => '0.000', 'created_at' => now(), 'updated_at' => now(),
        ]);

        $this->getJson("/api/v1/inventory/items/{$item}/purchase-history", $headers)->assertOk()
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.invoiceId', $invoice)
            ->assertJsonPath('data.0.receivedQuantity', '0.000')
            ->assertJsonPath('data.0.receiptStatus', 'not_received');
    }
}
