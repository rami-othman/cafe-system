<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use App\Services\ShiftCashSummaryService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Purchasing Phase 2 — Goods Receipt / partial & multiple receiving /
 * inventory stock-in / WAC integration. The accounting boundary under test
 * throughout this file: Supplier Invoice keeps owning 100% of the AP
 * liability and its one journal entry; a Goods Receipt owns 100% of the
 * physical stock/WAC effect and must post ZERO journal entries (stock_in
 * stays NOT_APPLICABLE per InventoryAccountingMapper — see
 * PurchasingPhase1ApiTest's inverse assertion and this file's own explicit
 * zero-journal checks).
 */
class PurchasingPhase2ApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_full_lifecycle_partial_then_multiple_receipts_update_stock_wac_and_receipt_status(): void
    {
        $tenant = $this->tenant('phase2-lifecycle');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $warehouseId = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'kg', [$warehouseId]);

        // Seed an existing balance so the WAC blend is verifiable: 10kg @ $10.
        $this->stockIn($headers, $itemId, $warehouseId, '10.000', '10.0000');

        $invoiceId = $this->postedInventoryInvoice($headers, $supplierId, $itemId, $warehouseId, '100.000', '16.0000');
        $invoiceLineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');

        $journalsBefore = DB::table('journal_entries')->where('tenant_id', $tenant)->count();

        // Receipt #1 — partial (60kg).
        $receipt1 = $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', [
            'idempotencyKey' => 'grn-1-create',
            'lines' => [['supplierInvoiceLineId' => $invoiceLineId, 'quantity' => '60.000', 'warehouseId' => $warehouseId]],
        ], $headers)->assertCreated()->json('data');
        $this->assertSame('draft', $receipt1['status']);
        $this->assertMatchesRegularExpression('/^GRN-\d{4}-\d{6}$/', $receipt1['receiptNumber']);

        $posted1 = $this->postJson("/api/v1/finance/purchase-receipts/{$receipt1['id']}/post", ['idempotencyKey' => 'grn-1-post'], $headers)
            ->assertOk()->json('data');
        $this->assertSame('posted', $posted1['status']);

        $this->assertSame('60.000', DB::table('supplier_invoice_lines')->where('id', $invoiceLineId)->value('received_quantity'));
        $this->assertSame('partially_received', DB::table('supplier_invoices')->where('id', $invoiceId)->value('receipt_status'));
        $balance1 = DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $itemId)->first();
        $this->assertSame('70.000', $balance1->quantity_on_hand); // 10 + 60
        // WAC blend: (10*10 + 60*16) / 70 = (100+960)/70 = 15.142857.. -> integer cost math rounds to 15.1428
        $this->assertEqualsWithDelta(15.1428, (float) $balance1->average_unit_cost, 0.0002);
        $this->assertSame('16.0000', DB::table('inventory_items')->where('id', $itemId)->value('last_purchase_cost'));

        // Receipt #2 — the remaining 40kg, completing the invoice.
        $receipt2 = $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', [
            'idempotencyKey' => 'grn-2-create',
            'lines' => [['supplierInvoiceLineId' => $invoiceLineId, 'quantity' => '40.000', 'warehouseId' => $warehouseId]],
        ], $headers)->assertCreated()->json('data');
        $this->postJson("/api/v1/finance/purchase-receipts/{$receipt2['id']}/post", ['idempotencyKey' => 'grn-2-post'], $headers)->assertOk();

        $this->assertSame('100.000', DB::table('supplier_invoice_lines')->where('id', $invoiceLineId)->value('received_quantity'));
        $this->assertSame('received', DB::table('supplier_invoices')->where('id', $invoiceId)->value('receipt_status'));
        $balance2 = DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $itemId)->first();
        $this->assertSame('110.000', $balance2->quantity_on_hand); // 70 + 40

        // Receipt history stays visible — never overwritten.
        $history = $this->getJson("/api/v1/finance/purchases/{$invoiceId}/receipts", $headers)->assertOk()->json('data');
        $this->assertCount(2, $history);

        // Critical regression invariant: exactly one financial journal from
        // the purchase (the invoice's own posting) — receiving added zero.
        $journalsAfter = DB::table('journal_entries')->where('tenant_id', $tenant)->count();
        $this->assertSame($journalsBefore, $journalsAfter);
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'supplier_invoice')->where('source_id', $invoiceId)->count());
        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'inventory_movement')->count());

        // AP/payment status is completely untouched by receiving.
        $purchase = $this->getJson("/api/v1/finance/purchases/{$invoiceId}", $headers)->assertOk()->json('data');
        $this->assertSame('unpaid', $purchase['paymentStatus']);
        $this->assertSame('1600.00', $purchase['remainingAmount']);
    }

    public function test_receiving_requires_the_invoice_to_be_posted_first(): void
    {
        $tenant = $this->tenant('phase2-draft-invoice');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $warehouseId = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'kg', [$warehouseId]);

        $draftId = $this->createInventoryInvoice($headers, $supplierId, $itemId, $warehouseId, '10.000', '5.0000');
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $draftId)->value('id');

        $response = $this->postJson('/api/v1/finance/purchases/'.$draftId.'/receipts', [
            'idempotencyKey' => 'grn-draft-1',
            'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '5.000', 'warehouseId' => $warehouseId]],
        ], $headers)->assertUnprocessable();
        $this->assertStringContainsString('لا يمكن ترحيل استلام المخزون قبل ترحيل فاتورة الشراء', json_encode($response->json(), JSON_UNESCAPED_UNICODE));
    }

    public function test_only_inventory_lines_are_receivable_and_service_invoice_cannot_be_received(): void
    {
        $tenant = $this->tenant('phase2-service-only');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $categoryId = $this->expenseCategory($tenant, $headers, '6140');

        $id = $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'SVC-P2-1', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01',
            'invoiceType' => 'expense', 'expenseCategoryId' => $categoryId,
            'lines' => [['lineType' => 'expense', 'description' => 'Internet', 'quantity' => '1', 'lineGrossAmount' => '50.00']],
        ], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/supplier-invoices/{$id}/post", ['idempotencyKey' => 'svc-post-1'], $headers)->assertOk();
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $id)->value('id');

        $this->postJson('/api/v1/finance/purchases/'.$id.'/receipts', [
            'idempotencyKey' => 'grn-svc-1',
            'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '1.000']],
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('lines');
    }

    public function test_over_receiving_is_rejected_and_cannot_be_bypassed_by_a_second_partial_receipt(): void
    {
        $tenant = $this->tenant('phase2-over-receive');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $warehouseId = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'kg', [$warehouseId]);
        $invoiceId = $this->postedInventoryInvoice($headers, $supplierId, $itemId, $warehouseId, '100.000', '10.0000');
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');

        // A single over-large receipt is rejected outright.
        $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', [
            'idempotencyKey' => 'grn-over-1',
            'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '150.000', 'warehouseId' => $warehouseId]],
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('lines');

        // Receive 80kg, leaving 20kg remaining...
        $r1 = $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', [
            'idempotencyKey' => 'grn-over-2',
            'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '80.000', 'warehouseId' => $warehouseId]],
        ], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/purchase-receipts/{$r1}/post", ['idempotencyKey' => 'grn-over-2-post'], $headers)->assertOk();

        // ...then attempt to receive 30kg (exceeds the 20kg left) must fail
        // even though 30 < the original 100kg invoice quantity.
        $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', [
            'idempotencyKey' => 'grn-over-3',
            'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '30.000', 'warehouseId' => $warehouseId]],
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('lines');

        $this->assertSame('80.000', DB::table('supplier_invoice_lines')->where('id', $lineId)->value('received_quantity'));
    }

    public function test_concurrent_over_receipt_is_prevented_by_the_row_locked_post_step(): void
    {
        $tenant = $this->tenant('phase2-concurrent');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $warehouseId = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'kg', [$warehouseId]);
        $invoiceId = $this->postedInventoryInvoice($headers, $supplierId, $itemId, $warehouseId, '100.000', '10.0000');
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');

        // Two drafts are each individually within the ordered quantity...
        $r1 = $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', ['idempotencyKey' => 'grn-race-1', 'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '60.000', 'warehouseId' => $warehouseId]]], $headers)->assertCreated()->json('data.id');

        // ...but a second draft for 60kg is rejected up front once the first
        // draft already claims 60kg of the 100kg ordered (draft-time UX
        // check), and even if it were somehow created, post() re-validates
        // under a row lock so the two together could never both succeed.
        $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', ['idempotencyKey' => 'grn-race-2', 'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '60.000', 'warehouseId' => $warehouseId]]], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('lines');

        $this->postJson("/api/v1/finance/purchase-receipts/{$r1}/post", ['idempotencyKey' => 'grn-race-1-post'], $headers)->assertOk();
        $this->assertSame('60.000', DB::table('supplier_invoice_lines')->where('id', $lineId)->value('received_quantity'));
    }

    public function test_zero_and_negative_quantity_rejected(): void
    {
        $tenant = $this->tenant('phase2-zero-qty');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $warehouseId = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'kg', [$warehouseId]);
        $invoiceId = $this->postedInventoryInvoice($headers, $supplierId, $itemId, $warehouseId, '10.000', '5.0000');
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');

        $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', ['idempotencyKey' => 'grn-zero-1', 'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '0.000', 'warehouseId' => $warehouseId]]], $headers)
            ->assertUnprocessable();
        $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', ['idempotencyKey' => 'grn-zero-2', 'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '-1.000', 'warehouseId' => $warehouseId]]], $headers)
            ->assertUnprocessable();
    }

    public function test_unit_conversion_is_applied_from_purchase_unit_to_base_unit_on_receipt(): void
    {
        $tenant = $this->tenant('phase2-unit-conv');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $warehouseId = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'bottle', [$warehouseId]);
        // 1 carton = 12 bottles.
        $this->postJson("/api/v1/inventory/items/{$itemId}/unit-conversions", [
            'sourceUnit' => 'carton', 'targetUnit' => 'bottle', 'factor' => '12.000000', 'isActive' => true,
        ], $headers)->assertCreated();

        $invoiceId = $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'CARTON-1', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory',
            'lines' => [['lineType' => 'inventory', 'description' => 'Bottled water', 'inventoryItemId' => $itemId, 'purchaseUnit' => 'carton', 'quantity' => '2', 'lineGrossAmount' => '48.00', 'warehouseId' => $warehouseId]],
        ], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/supplier-invoices/{$invoiceId}/post", ['idempotencyKey' => 'carton-post-1'], $headers)->assertOk();
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');
        $this->assertSame('24.000', DB::table('supplier_invoice_lines')->where('id', $lineId)->value('base_quantity'));

        $receiptId = $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', [
            'idempotencyKey' => 'grn-carton-1', 'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '2.000', 'warehouseId' => $warehouseId]],
        ], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/purchase-receipts/{$receiptId}/post", ['idempotencyKey' => 'grn-carton-1-post'], $headers)->assertOk();

        // Physical stock moved in BASE units (bottles): 2 cartons * 12 = 24 bottles.
        $this->assertSame('24.000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $itemId)->value('quantity_on_hand'));
        // Unit cost per base unit = 24.0000 / 12 = 2.0000 per bottle.
        $this->assertSame('2.0000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $itemId)->value('average_unit_cost'));
        $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $tenant)->where('inventory_item_id', $itemId)->count());
    }

    public function test_unassigned_warehouse_is_rejected(): void
    {
        $tenant = $this->tenant('phase2-warehouse-assign');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $assignedWarehouse = $this->warehouse($headers, 'WH-A');
        $unassignedWarehouse = $this->warehouse($headers, 'WH-B');
        $itemId = $this->inventoryItem($headers, 'kg', [$assignedWarehouse]);
        $invoiceId = $this->postedInventoryInvoice($headers, $supplierId, $itemId, $assignedWarehouse, '10.000', '5.0000');
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');

        $receiptId = $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', [
            'idempotencyKey' => 'grn-wh-1', 'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '5.000', 'warehouseId' => $unassignedWarehouse]],
        ], $headers)->assertCreated()->json('data.id');

        $this->postJson("/api/v1/finance/purchase-receipts/{$receiptId}/post", ['idempotencyKey' => 'grn-wh-1-post'], $headers)->assertUnprocessable();
    }

    public function test_posted_receipt_is_immutable(): void
    {
        $tenant = $this->tenant('phase2-immutable');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $warehouseId = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'kg', [$warehouseId]);
        $invoiceId = $this->postedInventoryInvoice($headers, $supplierId, $itemId, $warehouseId, '10.000', '5.0000');
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');

        $receiptId = $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', ['idempotencyKey' => 'grn-imm-1', 'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '5.000', 'warehouseId' => $warehouseId]]], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/purchase-receipts/{$receiptId}/post", ['idempotencyKey' => 'grn-imm-1-post'], $headers)->assertOk();

        $this->patchJson("/api/v1/finance/purchase-receipts/{$receiptId}", ['lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '1.000', 'warehouseId' => $warehouseId]]], $headers)
            ->assertUnprocessable();
    }

    public function test_idempotent_create_and_post_replay_does_not_duplicate(): void
    {
        $tenant = $this->tenant('phase2-idem');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $warehouseId = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'kg', [$warehouseId]);
        $invoiceId = $this->postedInventoryInvoice($headers, $supplierId, $itemId, $warehouseId, '10.000', '5.0000');
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');
        $payload = ['idempotencyKey' => 'grn-idem-1', 'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '5.000', 'warehouseId' => $warehouseId]]];

        $first = $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', $payload, $headers)->assertCreated()->json('data.id');
        $replay = $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', $payload, $headers)->assertCreated()->json('data.id');
        $this->assertSame($first, $replay);
        $this->assertSame(1, DB::table('purchase_receipts')->where('tenant_id', $tenant)->count());

        $this->postJson("/api/v1/finance/purchase-receipts/{$first}/post", ['idempotencyKey' => 'grn-idem-1-post'], $headers)->assertOk();
        $this->postJson("/api/v1/finance/purchase-receipts/{$first}/post", ['idempotencyKey' => 'grn-idem-1-post'], $headers)->assertOk();

        $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $tenant)->where('reference_type', 'purchase_receipt_line')->count());
        $this->assertSame('5.000', DB::table('supplier_invoice_lines')->where('id', $lineId)->value('received_quantity'));
    }

    public function test_tenant_isolation_rejects_cross_tenant_invoice_and_item(): void
    {
        $tenantA = $this->tenant('phase2-tenant-a');
        $headersA = $this->headers($tenantA);
        $supplierA = $this->supplier($headersA);
        $warehouseA = $this->warehouse($headersA);
        $itemA = $this->inventoryItem($headersA, 'kg', [$warehouseA]);
        $invoiceId = $this->postedInventoryInvoice($headersA, $supplierA, $itemA, $warehouseA, '10.000', '5.0000');
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');

        $tenantB = $this->tenant('phase2-tenant-b');
        $headersB = $this->headers($tenantB);

        // Tenant B cannot see or receive against tenant A's invoice.
        $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', ['idempotencyKey' => 'cross-1', 'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '1.000', 'warehouseId' => $warehouseA]]], $headersB)
            ->assertNotFound();
        $this->getJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', $headersB)->assertNotFound();

        // Tenant A cannot receive using tenant B's warehouse.
        $warehouseB = $this->warehouse($headersB);
        $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', ['idempotencyKey' => 'cross-2', 'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '1.000', 'warehouseId' => $warehouseB]]], $headersA)
            ->assertUnprocessable();
    }

    public function test_permission_is_required_to_receive_and_view_is_separate_from_receive(): void
    {
        $tenant = $this->tenant('phase2-permissions');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $warehouseId = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'kg', [$warehouseId]);
        $invoiceId = $this->postedInventoryInvoice($headers, $supplierId, $itemId, $warehouseId, '10.000', '5.0000');
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');

        DB::table('finance_role_permissions')->updateOrInsert(['tenant_id' => $tenant, 'role' => 'manager', 'permission' => 'finance.purchases.view'], ['created_at' => now(), 'updated_at' => now()]);
        $managerId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Viewer Manager', 'email' => 'viewer-p2@example.test', 'password' => bcrypt('password'), 'role' => 'manager', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $plainToken = "phase2-manager-$tenant";
        DB::table('api_tokens')->insert(['tenant_id' => $tenant, 'user_id' => $managerId, 'name' => 'manager-token', 'token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);
        $managerHeaders = ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenant];

        // Can view the purchase, but cannot create a receipt without finance.purchases.receive.
        $this->getJson("/api/v1/finance/purchases/{$invoiceId}", $managerHeaders)->assertOk();
        $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', ['idempotencyKey' => 'perm-1', 'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '5.000', 'warehouseId' => $warehouseId]]], $managerHeaders)
            ->assertForbidden();
    }

    public function test_purchasing_center_exposes_receipt_status_and_filter(): void
    {
        $tenant = $this->tenant('phase2-center');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $warehouseId = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'kg', [$warehouseId]);
        $invoiceId = $this->postedInventoryInvoice($headers, $supplierId, $itemId, $warehouseId, '5.000', '5.0000');
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');

        $row = $this->getJson("/api/v1/finance/purchases/{$invoiceId}", $headers)->assertOk()->json('data');
        $this->assertSame('not_received', $row['receiptStatus']);
        $this->assertContains('receive', $row['allowedActions']);
        $this->assertSame('5.000', $row['lines'][0]['remainingQuantity']);

        $receiptId = $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', ['idempotencyKey' => 'center-1', 'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '5.000', 'warehouseId' => $warehouseId]]], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/purchase-receipts/{$receiptId}/post", ['idempotencyKey' => 'center-1-post'], $headers)->assertOk();

        $this->getJson('/api/v1/finance/purchases?receiptStatus=received', $headers)->assertOk()->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/finance/purchases?receiptStatus=not_received', $headers)->assertOk()->assertJsonCount(0, 'data');

        $updated = $this->getJson("/api/v1/finance/purchases/{$invoiceId}", $headers)->assertOk()->json('data');
        $this->assertSame('received', $updated['receiptStatus']);
        $this->assertNotContains('receive', $updated['allowedActions']);
        $this->assertSame('0.000', $updated['lines'][0]['remainingQuantity']);
        $this->assertCount(1, $updated['receipts']);
        $this->assertSame('posted', $updated['receipts'][0]['status']);
    }

    public function test_goods_receipts_list_and_show_api(): void
    {
        $tenant = $this->tenant('phase2-list');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $warehouseId = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'kg', [$warehouseId]);
        $invoiceId = $this->postedInventoryInvoice($headers, $supplierId, $itemId, $warehouseId, '10.000', '5.0000');
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');
        $receiptId = $this->postJson('/api/v1/finance/purchases/'.$invoiceId.'/receipts', ['idempotencyKey' => 'list-1', 'reference' => 'REF-1', 'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '5.000', 'warehouseId' => $warehouseId]]], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/purchase-receipts/{$receiptId}/post", ['idempotencyKey' => 'list-1-post'], $headers)->assertOk();

        $list = $this->getJson('/api/v1/finance/purchase-receipts', $headers)->assertOk()->json('data');
        $this->assertCount(1, $list);
        $this->assertSame('posted', $list[0]['status']);
        $this->assertSame(1, $list[0]['lineCount']);

        $this->getJson('/api/v1/finance/purchase-receipts?status=draft', $headers)->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/finance/purchase-receipts?status=posted', $headers)->assertOk()->assertJsonCount(1, 'data');

        $detail = $this->getJson("/api/v1/finance/purchase-receipts/{$receiptId}", $headers)->assertOk()->json('data');
        $this->assertSame('REF-1', $detail['reference']);
        $this->assertCount(1, $detail['lines']);
        $this->assertSame('5.000', $detail['lines'][0]['receivedQuantity']);
        $this->assertNotNull($detail['lines'][0]['stockMovementId']);
    }

    public function test_unified_purchase_post_receives_pays_vouchers_and_is_idempotent(): void
    {
        $tenant = $this->tenant('unified-purchase-post');
        $headers = $this->headers($tenant);
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenant)->value('id');
        $supplierId = $this->supplier($headers);
        $warehouseId = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'kg', [$warehouseId]);

        $invoiceId = (int) $this->postJson('/api/v1/finance/supplier-invoices', [
            'branchId' => $branchId,
            'supplierId' => $supplierId,
            'invoiceNumber' => 'AUTO-260',
            'invoiceDate' => '2026-09-17',
            'dueDate' => '2026-09-17',
            'invoiceType' => 'inventory',
            'lines' => [[
                'lineType' => 'inventory',
                'description' => 'Auto received material',
                'inventoryItemId' => $itemId,
                'quantity' => '12.000',
                'lineGrossAmount' => '260.00',
                'warehouseId' => $warehouseId,
            ]],
        ], $headers)->assertCreated()->json('data.id');

        $posted = $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", ['idempotencyKey' => 'unified-1', 'financialLocationId' => $this->drawer($branchId)], $headers)
            ->assertOk()->json('data');
        $this->assertSame('paid', $posted['paymentStatus']);
        $this->assertSame('received', $posted['receiptStatus']);
        $this->assertSame('260.00', $posted['paidAmount']);
        $this->assertSame('0.00', $posted['remainingAmount']);
        $this->assertSame('12.000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $itemId)->value('quantity_on_hand'));
        $this->assertSame(1, DB::table('purchase_receipts')->where('tenant_id', $tenant)->where('supplier_invoice_id', $invoiceId)->where('status', 'posted')->count());
        $receiptLine = DB::table('purchase_receipt_lines as lines')
            ->join('purchase_receipts as receipts', 'receipts.id', '=', 'lines.purchase_receipt_id')
            ->where('receipts.tenant_id', $tenant)->where('receipts.supplier_invoice_id', $invoiceId)
            ->select('lines.id', 'lines.stock_movement_id')->first();
        $this->assertNotNull($receiptLine);
        $this->assertSame((int) $receiptLine->id, (int) DB::table('stock_movements')->where('id', $receiptLine->stock_movement_id)->where('reference_type', 'purchase_receipt_line')->value('reference_id'));
        $this->getJson("/api/v1/finance/purchases/{$invoiceId}", $headers)->assertOk();
        $this->assertSame('12.000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $itemId)->value('quantity_on_hand'));
        $this->assertSame(1, DB::table('supplier_payments')->where('tenant_id', $tenant)->where('supplier_id', $supplierId)->count());
        $this->assertSame(1, DB::table('finance_documents')->where('tenant_id', $tenant)->where('source_type', 'supplier_payment')->count());

        $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", ['idempotencyKey' => 'unified-double-click', 'financialLocationId' => $this->drawer($branchId)], $headers)->assertOk();
        $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $tenant)->where('reference_type', 'purchase_receipt_line')->count());
        $this->assertSame(1, DB::table('purchase_receipts')->where('tenant_id', $tenant)->where('supplier_invoice_id', $invoiceId)->count());
        $this->assertSame(1, DB::table('supplier_payments')->where('tenant_id', $tenant)->count());
        $this->assertSame(1, DB::table('finance_documents')->where('tenant_id', $tenant)->where('source_type', 'supplier_payment')->count());
    }

    /** C1/C2: the caller-supplied paymentDate/receiptDate must reach the
     * payment journal entry and the stock movement — not `now()`. */
    public function test_unified_purchase_post_honours_explicit_payment_and_receipt_dates(): void
    {
        [$tenant, $headers, $branchId, $invoiceId, $warehouseId, $itemId] = $this->unifiedInventoryFixture('explicit-dates');
        // Invoice date is 2026-09-17. Payment and receipt happen on different,
        // deliberately distinct, earlier-in-the-open-period dates.
        $posted = $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", [
            'idempotencyKey' => 'explicit-dates-1',
            'financialLocationId' => $this->drawer($branchId),
            'paymentDate' => '2026-09-20',
            'receiptDate' => '2026-09-21',
        ], $headers)->assertOk()->json('data');
        $this->assertSame('paid', $posted['paymentStatus']);

        $paymentId = (int) DB::table('payment_allocations')->where('tenant_id', $tenant)->where('supplier_invoice_id', $invoiceId)->value('supplier_payment_id');
        $this->assertNotSame(0, $paymentId, 'Expected an auto-created supplier payment.');
        $payment = DB::table('supplier_payments')->where('id', $paymentId)->first();
        $this->assertSame('2026-09-20', $payment->payment_date);
        $this->assertNotSame('2026-09-17', $payment->payment_date);

        $paymentJournal = DB::table('journal_entries')->where('id', $payment->journal_entry_id)->first();
        $this->assertNotNull($paymentJournal);
        $this->assertSame('2026-09-20', substr((string) $paymentJournal->entry_date, 0, 10));

        $receiptId = (int) DB::table('purchase_receipts')->where('tenant_id', $tenant)->where('supplier_invoice_id', $invoiceId)->value('id');
        $this->assertSame('2026-09-21', DB::table('purchase_receipts')->where('id', $receiptId)->value('receipt_date'));
        $movement = DB::table('stock_movements')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)
            ->where('inventory_item_id', $itemId)->where('type', 'stock_in')->first();
        $this->assertNotNull($movement);
        $this->assertSame('2026-09-21', substr((string) $movement->occurred_at, 0, 10));
    }

    /** C1: a payment date landing inside a closed accounting period must be
     * rejected — never silently moved to today. */
    public function test_unified_purchase_post_rejects_payment_date_in_a_closed_period(): void
    {
        [, $headers, $branchId, $invoiceId] = $this->unifiedInventoryFixture('closed-period-dates');
        $this->postJson('/api/v1/finance/accounting-periods', ['name' => 'August', 'startDate' => '2026-08-01', 'endDate' => '2026-08-31'], $headers)
            ->assertCreated();
        $period = (int) DB::table('accounting_periods')->where('name', 'August')->value('id');
        $this->postJson("/api/v1/finance/accounting-periods/{$period}/close", [], $headers)->assertOk();

        $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", [
            'idempotencyKey' => 'closed-period-1',
            'financialLocationId' => $this->drawer($branchId),
            'paymentDate' => '2026-08-15',
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('accountingPeriod');
    }

    public function test_direct_purchase_receives_all_stock_with_partial_or_no_payment(): void
    {
        foreach (['100.00' => 'partial', '0.00' => 'unpaid'] as $paid => $status) {
            [$tenant, $headers, $branchId, $invoiceId, $warehouseId, $itemId] = $this->unifiedInventoryFixture('direct-'.$status);
            DB::table('supplier_invoices')->where('id', $invoiceId)->update(['receipt_mode' => 'immediate']);
            $response = $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", [
                'idempotencyKey' => 'direct-'.$status,
                'paidAmount' => $paid,
                'financialLocationId' => $paid === '0.00' ? null : $this->drawer($branchId),
            ], $headers)->assertOk();
            $response->assertJsonPath('data.receiptStatus', 'received')
                ->assertJsonPath('data.paymentStatus', $status)
                ->assertJsonPath('data.paidAmount', $paid);
            $this->assertSame('12.000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $itemId)->value('quantity_on_hand'));
            $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", [
                'idempotencyKey' => 'retry-'.$status, 'paidAmount' => $paid,
            ], $headers)->assertOk();
            $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $tenant)->where('reference_type', 'purchase_receipt_line')->count());
        }
    }

    public function test_receive_later_purchase_keeps_partial_receipt_workflow(): void
    {
        [$tenant, $headers, , $invoiceId, $warehouseId, $itemId] = $this->unifiedInventoryFixture('receive-later');
        DB::table('supplier_invoices')->where('id', $invoiceId)->update(['receipt_mode' => 'receive_later']);
        $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", [
            'idempotencyKey' => 'later-post', 'paidAmount' => '0.00',
        ], $headers)->assertOk()->assertJsonPath('data.receiptStatus', 'not_received');
        $this->assertSame(0, DB::table('stock_movements')->where('tenant_id', $tenant)->count());
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');
        foreach ([['6.000', 'partially_received'], ['6.000', 'received']] as [$quantity, $status]) {
            $receiptId = (int) $this->postJson("/api/v1/finance/purchases/{$invoiceId}/receipts", [
                'idempotencyKey' => 'later-receipt-'.uniqid(),
                'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => $quantity, 'warehouseId' => $warehouseId]],
            ], $headers)->assertCreated()->json('data.id');
            $this->postJson("/api/v1/finance/purchase-receipts/{$receiptId}/post", ['idempotencyKey' => 'later-post-'.uniqid()], $headers)->assertOk();
            $this->getJson("/api/v1/finance/purchases/{$invoiceId}", $headers)->assertOk()->assertJsonPath('data.receiptStatus', $status);
        }
        $this->assertSame('12.000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $itemId)->value('quantity_on_hand'));
    }

    public function test_immediate_invoice_post_endpoint_also_receives_without_payment(): void
    {
        [$tenant, $headers, , $invoiceId, $warehouseId, $itemId] = $this->unifiedInventoryFixture('direct-supplier-post');
        DB::table('supplier_invoices')->where('id', $invoiceId)->update(['receipt_mode' => 'immediate']);
        $this->postJson("/api/v1/finance/supplier-invoices/{$invoiceId}/post", ['idempotencyKey' => 'direct-supplier-post'], $headers)->assertOk();
        $this->assertSame('12.000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $itemId)->value('quantity_on_hand'));
        $this->assertSame(0, DB::table('supplier_payments')->where('tenant_id', $tenant)->count());
    }

    public function test_direct_purchase_uses_selected_second_warehouse_with_partial_payment(): void
    {
        $tenant = $this->tenant('direct-second-warehouse');
        $headers = $this->headers($tenant);
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenant)->value('id');
        $supplierId = $this->supplier($headers);
        $warehouseA = $this->warehouse($headers);
        $warehouseB = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'kg', [$warehouseA, $warehouseB]);
        $invoiceId = (int) $this->postJson('/api/v1/finance/supplier-invoices', [
            'branchId' => $branchId, 'supplierId' => $supplierId, 'receiptMode' => 'immediate',
            'invoiceDate' => '2026-09-17', 'dueDate' => '2026-10-17', 'invoiceType' => 'inventory',
            'lines' => [[
                'lineType' => 'inventory', 'description' => 'Selected warehouse material',
                'inventoryItemId' => $itemId, 'quantity' => '13.000',
                'lineGrossAmount' => '169.00', 'warehouseId' => $warehouseB,
            ]],
        ], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", [
            'idempotencyKey' => 'direct-13', 'paidAmount' => '100.00',
            'financialLocationId' => $this->drawer($branchId),
        ], $headers)->assertOk()->assertJsonPath('data.remainingAmount', '69.00')
            ->assertJsonPath('data.receiptStatus', 'received');
        $this->assertNull(DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseA)->where('inventory_item_id', $itemId)->value('quantity_on_hand'));
        $this->assertSame('13.000', DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseB)->where('inventory_item_id', $itemId)->value('quantity_on_hand'));
    }

    public function test_purchase_list_labels_multiple_warehouses_without_selecting_the_first(): void
    {
        $tenant = $this->tenant('multiple-warehouses');
        $headers = $this->headers($tenant);
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenant)->value('id');
        $supplierId = $this->supplier($headers);
        $warehouseA = $this->warehouse($headers);
        $warehouseB = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'kg', [$warehouseA, $warehouseB]);
        $invoiceId = (int) $this->postJson('/api/v1/finance/supplier-invoices', [
            'branchId' => $branchId, 'supplierId' => $supplierId, 'receiptMode' => 'receive_later',
            'invoiceDate' => '2026-09-19', 'dueDate' => '2026-10-19', 'invoiceType' => 'inventory',
            'lines' => [
                ['lineType' => 'inventory', 'description' => 'First', 'inventoryItemId' => $itemId, 'quantity' => '1.000', 'lineGrossAmount' => '13.00', 'warehouseId' => $warehouseA],
                ['lineType' => 'inventory', 'description' => 'Second', 'inventoryItemId' => $itemId, 'quantity' => '1.000', 'lineGrossAmount' => '13.00', 'warehouseId' => $warehouseB],
            ],
        ], $headers)->assertCreated()->json('data.id');

        $this->getJson("/api/v1/finance/purchases/{$invoiceId}", $headers)
            ->assertOk()->assertJsonPath('data.warehouseName', 'متعدد المخازن');
    }

    public function test_historical_posted_invoice_is_not_auto_received(): void
    {
        [$tenant, $headers, , $invoiceId, $warehouseId, $itemId] = $this->unifiedInventoryFixture('historical-pending');
        $this->postJson("/api/v1/finance/supplier-invoices/{$invoiceId}/post", [
            'idempotencyKey' => 'historical-invoice',
        ], $headers)->assertOk();
        $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", [
            'idempotencyKey' => 'historical-purchase', 'paidAmount' => '0.00',
        ], $headers)->assertOk()->assertJsonPath('data.receiptStatus', 'not_received');
        $this->assertNull(DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $itemId)->value('quantity_on_hand'));
        $this->assertSame(0, DB::table('purchase_receipts')->where('tenant_id', $tenant)->where('supplier_invoice_id', $invoiceId)->count());
    }

    public function test_cashier_without_open_shift_rolls_back_every_purchase_effect(): void
    {
        [$tenant, $ownerHeaders, $branchId, $invoiceId, $warehouseId, $itemId] = $this->unifiedInventoryFixture('no-open-shift');
        $cashierHeaders = $this->cashierHeaders($tenant, $branchId, 'no-shift');

        $response = $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", ['idempotencyKey' => 'no-shift'], $cashierHeaders)
            ->assertUnprocessable();
        $this->assertStringContainsString('يجب فتح وردية', json_encode($response->json(), JSON_UNESCAPED_UNICODE));
        $this->assertNull(DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $itemId)->value('quantity_on_hand'));
        $this->assertSame('draft', DB::table('supplier_invoices')->where('id', $invoiceId)->value('status'));
        $this->assertSame(0, DB::table('supplier_payments')->where('tenant_id', $tenant)->count());
        $this->assertSame(0, DB::table('finance_documents')->where('tenant_id', $tenant)->where('source_type', 'supplier_payment')->count());
    }

    public function test_cashier_open_shift_uses_its_drawer_and_reduces_expected_cash(): void
    {
        [$tenant, $ownerHeaders, $branchId, $invoiceId] = $this->unifiedInventoryFixture('cashier-open-shift');
        $cashierHeaders = $this->cashierHeaders($tenant, $branchId, 'open-shift');
        $this->fundDrawerForShift($tenant, $branchId, $ownerHeaders, '1000.00');
        $shift = $this->postJson('/api/v1/shifts/current', ['branchId' => $branchId, 'openingCash' => '1000.00'], $cashierHeaders)
            ->assertCreated()->json('data');

        $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", ['idempotencyKey' => 'cashier-open'], $cashierHeaders)->assertOk();

        $payment = DB::table('supplier_payments')->where('tenant_id', $tenant)->first();
        $this->assertSame((int) $shift['id'], (int) $payment->shift_id);
        $this->assertSame((int) DB::table('shifts')->where('id', $shift['id'])->value('financial_location_id'), (int) $payment->financial_location_id);
        $summary = app(ShiftCashSummaryService::class)->summarize($tenant, DB::table('shifts')->where('id', $shift['id'])->first());
        $this->assertSame('740.00', $summary['expectedCash']);
        $this->assertSame('260.00', $summary['expenses']);
    }

    public function test_cashier_cannot_override_purchase_shift_drawer(): void
    {
        [$tenant, $ownerHeaders, $branchId, $invoiceId] = $this->unifiedInventoryFixture('cashier-drawer-override');
        $cashierHeaders = $this->cashierHeaders($tenant, $branchId, 'drawer-override');
        $this->fundDrawerForShift($tenant, $branchId, $ownerHeaders, '1000.00');
        $this->postJson('/api/v1/shifts/current', ['branchId' => $branchId, 'openingCash' => '1000.00'], $cashierHeaders)->assertCreated();
        $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", [
            'idempotencyKey' => 'drawer-override', 'financialLocationId' => $this->drawer($branchId),
        ], $cashierHeaders)->assertUnprocessable()->assertJsonValidationErrors('financialLocationId');
        $this->assertSame('draft', DB::table('supplier_invoices')->where('id', $invoiceId)->value('status'));
        $this->assertSame(0, DB::table('supplier_payments')->where('tenant_id', $tenant)->count());
    }

    public function test_inventory_failure_rolls_back_invoice_and_creates_no_payment_or_voucher(): void
    {
        [$tenant, $headers, $branchId, $invoiceId, $warehouseId, $itemId] = $this->unifiedInventoryFixture('inventory-failure');
        DB::table('inventory_item_warehouses')->where('tenant_id', $tenant)->where('inventory_item_id', $itemId)->where('warehouse_id', $warehouseId)->delete();

        $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", ['idempotencyKey' => 'inventory-fail', 'financialLocationId' => $this->drawer($branchId)], $headers)->assertUnprocessable();

        $this->assertSame('draft', DB::table('supplier_invoices')->where('id', $invoiceId)->value('status'));
        $this->assertSame(0, DB::table('purchase_receipts')->where('tenant_id', $tenant)->count());
        $this->assertSame(0, DB::table('supplier_payments')->where('tenant_id', $tenant)->count());
        $this->assertSame(0, DB::table('finance_documents')->where('tenant_id', $tenant)->where('source_type', 'supplier_payment')->count());
    }

    public function test_existing_fully_received_invoice_is_paid_without_duplicate_stock(): void
    {
        [$tenant, $headers, $branchId, $invoiceId, $warehouseId, $itemId] = $this->unifiedInventoryFixture('legacy-received');
        $this->postJson("/api/v1/finance/supplier-invoices/{$invoiceId}/post", ['idempotencyKey' => 'legacy-invoice-post'], $headers)->assertOk();
        $lineId = (int) DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $invoiceId)->value('id');
        $receiptId = (int) $this->postJson("/api/v1/finance/purchases/{$invoiceId}/receipts", [
            'idempotencyKey' => 'legacy-receipt',
            'lines' => [['supplierInvoiceLineId' => $lineId, 'quantity' => '12.000', 'warehouseId' => $warehouseId]],
        ], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/purchase-receipts/{$receiptId}/post", ['idempotencyKey' => 'legacy-receipt-post'], $headers)->assertOk();
        $movements = DB::table('stock_movements')->where('tenant_id', $tenant)->count();

        $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", ['idempotencyKey' => 'legacy-auto-pay', 'financialLocationId' => $this->drawer($branchId)], $headers)
            ->assertOk()->assertJsonPath('data.paymentStatus', 'paid')->assertJsonPath('data.receiptStatus', 'received');
        $this->assertSame($movements, DB::table('stock_movements')->where('tenant_id', $tenant)->count());
        $this->assertSame(1, DB::table('purchase_receipts')->where('tenant_id', $tenant)->where('supplier_invoice_id', $invoiceId)->count());
    }

    public function test_expense_and_asset_purchases_auto_pay_without_inventory_movements(): void
    {
        $tenant = $this->tenant('unified-non-inventory');
        $headers = $this->headers($tenant);
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenant)->value('id');
        $supplierId = $this->supplier($headers);
        $categoryId = $this->expenseCategory($tenant, $headers, '6140');
        $fixedAssetId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1500')->value('id');
        $beforeMovements = DB::table('stock_movements')->where('tenant_id', $tenant)->count();

        $expenseId = (int) $this->postJson('/api/v1/finance/supplier-invoices', [
            'branchId' => $branchId, 'supplierId' => $supplierId, 'invoiceNumber' => 'EXP-AUTO',
            'invoiceDate' => '2026-09-17', 'dueDate' => '2026-09-17', 'invoiceType' => 'expense', 'expenseCategoryId' => $categoryId,
            'lines' => [['lineType' => 'expense', 'description' => 'Service', 'quantity' => '1', 'lineGrossAmount' => '80.00']],
        ], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/purchases/{$expenseId}/post", ['idempotencyKey' => 'expense-auto', 'financialLocationId' => $this->drawer($branchId)], $headers)
            ->assertOk()->assertJsonPath('data.paymentStatus', 'paid')->assertJsonPath('data.receiptStatus', 'not_applicable');

        $assetId = (int) $this->postJson('/api/v1/finance/supplier-invoices', [
            'branchId' => $branchId, 'supplierId' => $supplierId, 'invoiceNumber' => 'ASSET-AUTO',
            'invoiceDate' => '2026-09-17', 'dueDate' => '2026-09-17', 'invoiceType' => 'other', 'debitAccountId' => $fixedAssetId,
            'lines' => [['lineType' => 'asset', 'description' => 'Machine', 'quantity' => '1', 'lineGrossAmount' => '180.00']],
        ], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/purchases/{$assetId}/post", ['idempotencyKey' => 'asset-auto', 'financialLocationId' => $this->drawer($branchId)], $headers)
            ->assertOk()->assertJsonPath('data.paymentStatus', 'paid')->assertJsonPath('data.receiptStatus', 'not_applicable');

        $this->assertSame($beforeMovements, DB::table('stock_movements')->where('tenant_id', $tenant)->count());
        $this->assertSame(2, DB::table('supplier_payments')->where('tenant_id', $tenant)->count());
        $this->assertSame(2, DB::table('finance_documents')->where('tenant_id', $tenant)->where('source_type', 'supplier_payment')->count());
    }

    public function test_branch_scoped_user_cannot_pay_purchase_from_another_branch_drawer(): void
    {
        [$tenant, $headers, $branchA, $invoiceId] = $this->unifiedInventoryFixture('auto-pay-branch-isolation');
        $branchB = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Branch B', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('supplier_invoices')->where('id', $invoiceId)->update(['branch_id' => $branchB]);
        $cashierHeaders = $this->cashierHeaders($tenant, $branchA, 'branch-a-only');

        $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", ['idempotencyKey' => 'wrong-branch'], $cashierHeaders)->assertForbidden();
        $this->assertSame('draft', DB::table('supplier_invoices')->where('id', $invoiceId)->value('status'));
        $this->assertSame(0, DB::table('supplier_payments')->where('tenant_id', $tenant)->count());
        $this->assertSame(0, DB::table('purchase_receipts')->where('tenant_id', $tenant)->count());
    }

    public function test_failure_after_supplier_payment_rolls_back_inventory_payment_and_invoice(): void
    {
        [$tenant, $headers, $branchId, $invoiceId, $warehouseId, $itemId] = $this->unifiedInventoryFixture('payment-stage-failure');
        DB::statement(<<<'SQL'
            CREATE OR REPLACE FUNCTION reject_auto_purchase_voucher() RETURNS trigger AS $$
            BEGIN
                IF NEW.source_type = 'supplier_payment' THEN
                    RAISE EXCEPTION 'forced voucher failure';
                END IF;
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql
        SQL);
        DB::statement('CREATE TRIGGER reject_auto_purchase_voucher BEFORE INSERT ON finance_documents FOR EACH ROW EXECUTE FUNCTION reject_auto_purchase_voucher()');

        $this->postJson("/api/v1/finance/purchases/{$invoiceId}/post", ['idempotencyKey' => 'forced-payment-stage-failure', 'financialLocationId' => $this->drawer($branchId)], $headers)->assertServerError();

        $this->assertSame('draft', DB::table('supplier_invoices')->where('id', $invoiceId)->value('status'));
        $this->assertSame(0, DB::table('stock_movements')->where('tenant_id', $tenant)->where('inventory_item_id', $itemId)->count());
        $this->assertSame(0, DB::table('purchase_receipts')->where('tenant_id', $tenant)->count());
        $this->assertSame(0, DB::table('supplier_payments')->where('tenant_id', $tenant)->count());
        $this->assertNull(DB::table('stock_balances')->where('tenant_id', $tenant)->where('warehouse_id', $warehouseId)->where('inventory_item_id', $itemId)->first());
    }

    public function test_purchase_numbers_are_server_generated_unique_and_supplier_reference_is_optional_and_separate(): void
    {
        $tenant = $this->tenant('purchase-auto-number');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $categoryId = $this->expenseCategory($tenant, $headers, '6140');

        $payload = [
            'supplierId' => $supplierId,
            'invoiceDate' => '2026-09-17',
            'dueDate' => '2026-09-17',
            'invoiceType' => 'expense',
            'expenseCategoryId' => $categoryId,
            'lines' => [[
                'lineType' => 'expense',
                'description' => 'Service',
                'quantity' => '1.000',
                'unitCost' => '10.0000',
            ]],
        ];

        $first = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)
            ->assertCreated()->json('data');
        $second = $this->postJson('/api/v1/finance/supplier-invoices', $payload + [
            'supplierInvoiceNumber' => 'SUPPLIER-77',
        ], $headers)->assertCreated()->json('data');

        $this->assertMatchesRegularExpression('/^PI-\d{4}-\d{6}$/', $first['invoiceNumber']);
        $this->assertMatchesRegularExpression('/^PI-\d{4}-\d{6}$/', $second['invoiceNumber']);
        $this->assertNotSame($first['invoiceNumber'], $second['invoiceNumber']);
        $code = DB::table('suppliers')->where('id', $supplierId)->value('supplier_number');
        $this->assertSame($code.'-000001', $first['supplierInternalReference']);
        $this->assertSame($code.'-000002', $second['supplierInternalReference']);
        $this->assertNull($first['supplierInvoiceNumber']);
        $this->assertSame('SUPPLIER-77', $second['supplierInvoiceNumber']);
        $this->assertNull($first['externalSupplierReference']);
        $this->assertSame('SUPPLIER-77', $second['externalSupplierReference']);

        $otherSupplierId = $this->supplier($headers);
        $other = $this->postJson('/api/v1/finance/supplier-invoices', array_replace($payload, [
            'supplierId' => $otherSupplierId,
        ]), $headers)->assertCreated()->json('data');
        $otherCode = DB::table('suppliers')->where('id', $otherSupplierId)->value('supplier_number');
        $this->assertSame($otherCode.'-000001', $other['supplierInternalReference']);

        $this->patchJson('/api/v1/finance/supplier-invoices/'.$first['id'], array_replace($payload, [
            'supplierId' => $otherSupplierId,
        ]), $headers)->assertUnprocessable();

        $retryPayload = $payload + ['idempotencyKey' => 'supplier-sequence-retry'];
        $retryFirst = $this->postJson('/api/v1/finance/supplier-invoices', $retryPayload, $headers)
            ->assertCreated()->json('data');
        $retrySecond = $this->postJson('/api/v1/finance/supplier-invoices', $retryPayload, $headers)
            ->assertCreated()->json('data');
        $this->assertSame($retryFirst['id'], $retrySecond['id']);
        $this->assertSame($code.'-000003', $retryFirst['supplierInternalReference']);
        $this->assertSame($retryFirst['supplierInternalReference'], $retrySecond['supplierInternalReference']);
    }

    public function test_line_gross_is_derived_from_quantity_and_four_decimal_unit_cost(): void
    {
        $tenant = $this->tenant('purchase-derived-gross');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $categoryId = $this->expenseCategory($tenant, $headers, '6140');

        $invoice = $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId,
            'invoiceDate' => '2026-09-17',
            'dueDate' => '2026-09-17',
            'invoiceType' => 'expense',
            'expenseCategoryId' => $categoryId,
            'lines' => [[
                'lineType' => 'expense',
                'description' => 'Precision service',
                'quantity' => '12.000',
                'unitCost' => '21.6667',
                'lineGrossAmount' => '999.99',
            ]],
        ], $headers)->assertCreated()->json('data');

        $this->assertSame('260.00', $invoice['subtotal']);
        $this->assertSame('260.00', $invoice['lines'][0]['lineGrossAmount']);
        $this->assertSame('21.6667', $invoice['lines'][0]['unitPrice']);
    }

    // --- helpers -----------------------------------------------------

    private function tenant(string $slug): int
    {
        $tenantId = DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['tenant_id' => $tenantId, 'name' => 'Central Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenantId);

        return (int) $tenantId;
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        if (! $userId) {
            $userId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantId, 'name' => 'Phase2 Owner', 'email' => "phase2-owner-$tenantId@example.test", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        }
        $plainToken = "phase2-test-$tenantId-$userId";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'phase2-feature-test'], ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }

    private function supplier(array $headers): int
    {
        return (int) $this->postJson('/api/v1/finance/suppliers', ['name' => 'Phase2 Test Supplier '.uniqid()], $headers)->assertCreated()->json('data.id');
    }

    private function expenseCategory(int $tenant, array $headers, string $accountCode): int
    {
        $account = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', $accountCode)->value('id');

        return (int) $this->postJson('/api/v1/finance/expense-categories', ['code' => 'P2CAT-'.uniqid(), 'name' => 'Phase2 Category', 'financialAccountId' => $account, 'isActive' => true], $headers)->assertCreated()->json('data.id');
    }

    private function warehouse(array $headers, ?string $code = null): int
    {
        $branchId = (int) DB::table('branches')->where('tenant_id', $headers['X-Tenant-Id'])->value('id');

        return (int) $this->postJson('/api/v1/warehouses', [
            'name' => 'Warehouse '.uniqid(), 'code' => $code ?? 'WH-'.strtoupper(uniqid()), 'type' => 'other', 'branchId' => $branchId, 'isActive' => true,
        ], $headers)->assertCreated()->json('data.id');
    }

    private function inventoryItem(array $headers, string $unit, array $warehouseIds = []): int
    {
        return (int) $this->postJson('/api/v1/inventory/items', [
            'nameAr' => 'صنف اختبار', 'nameEn' => 'Phase2 Test Item '.uniqid(), 'sku' => 'P2-'.strtoupper(uniqid()),
            'itemType' => 'raw_material', 'unit' => $unit, 'minimumStock' => '0.000', 'reorderLevel' => '0.000',
            'latestUnitCost' => '1.0000', 'isActive' => true, 'warehouseIds' => $warehouseIds,
        ], $headers)->assertCreated()->json('data.id');
    }

    private function stockIn(array $headers, int $itemId, int $warehouseId, string $quantity, string $unitCost): void
    {
        $this->postJson('/api/v1/inventory/movements', [
            'warehouseId' => $warehouseId, 'itemId' => $itemId, 'type' => 'stock_in', 'quantity' => $quantity, 'unitCost' => $unitCost,
            'idempotencyKey' => 'seed-stock-in-'.uniqid(),
        ], $headers)->assertCreated();
    }

    private function createInventoryInvoice(array $headers, int $supplierId, int $itemId, int $warehouseId, string $quantity, string $unitPrice): int
    {
        $grossAmount = number_format((float) $quantity * (float) $unitPrice, 2, '.', '');

        return (int) $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'P2-INV-'.uniqid(), 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory',
            'lines' => [['lineType' => 'inventory', 'description' => 'Goods', 'inventoryItemId' => $itemId, 'quantity' => $quantity, 'lineGrossAmount' => $grossAmount, 'warehouseId' => $warehouseId]],
        ], $headers)->assertCreated()->json('data.id');
    }

    private function postedInventoryInvoice(array $headers, int $supplierId, int $itemId, int $warehouseId, string $quantity, string $unitPrice): int
    {
        $id = $this->createInventoryInvoice($headers, $supplierId, $itemId, $warehouseId, $quantity, $unitPrice);
        $this->postJson("/api/v1/finance/supplier-invoices/{$id}/post", ['idempotencyKey' => 'inv-post-'.uniqid()], $headers)->assertOk();

        return $id;
    }

    private function unifiedInventoryFixture(string $slug): array
    {
        $tenant = $this->tenant($slug);
        $headers = $this->headers($tenant);
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenant)->value('id');
        $supplierId = $this->supplier($headers);
        $warehouseId = $this->warehouse($headers);
        $itemId = $this->inventoryItem($headers, 'kg', [$warehouseId]);
        $invoiceId = (int) $this->postJson('/api/v1/finance/supplier-invoices', [
            'branchId' => $branchId, 'supplierId' => $supplierId, 'invoiceNumber' => 'AUTO-'.uniqid(),
            'invoiceDate' => '2026-09-17', 'dueDate' => '2026-09-17', 'invoiceType' => 'inventory',
            'lines' => [['lineType' => 'inventory', 'description' => 'Material', 'inventoryItemId' => $itemId, 'quantity' => '12.000', 'lineGrossAmount' => '260.00', 'warehouseId' => $warehouseId]],
        ], $headers)->assertCreated()->json('data.id');

        return [$tenant, $headers, $branchId, $invoiceId, $warehouseId, $itemId];
    }

    private function cashierHeaders(int $tenant, int $branchId, string $tag): array
    {
        $userId = (int) DB::table('users')->insertGetId([
            'tenant_id' => $tenant, 'name' => 'Cashier', 'email' => "{$tag}-{$tenant}@example.test",
            'password' => bcrypt('password'), 'role' => 'cashier', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('user_branches')->insert(['tenant_id' => $tenant, 'user_id' => $userId, 'branch_id' => $branchId, 'created_at' => now(), 'updated_at' => now()]);
        $token = "{$tag}-{$tenant}-{$userId}";
        DB::table('api_tokens')->insert(['tenant_id' => $tenant, 'user_id' => $userId, 'name' => $tag, 'token_hash' => hash('sha256', $token), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer {$token}", 'X-Tenant-Id' => $tenant];
    }

    private function drawer(int $branchId): int
    {
        return (int) DB::table('branches')->where('id', $branchId)->value('pos_cash_financial_location_id');
    }

    private function fundDrawerForShift(int $tenant, int $branchId, array $headers, string $amount): void
    {
        $safe = (int) DB::table('financial_locations')->where('tenant_id', $tenant)
            ->where('code', 'MAIN-SAFE')->value('id');
        $this->postJson('/api/v1/finance/cash-transfers', [
            'fromFinancialLocationId' => $safe,
            'toFinancialLocationId' => $this->drawer($branchId),
            'amount' => $amount,
            'transferDate' => now()->toDateString(),
            'idempotencyKey' => 'purchase-opening-float-'.$tenant.'-'.$branchId,
        ], $headers)->assertCreated();
    }
}
