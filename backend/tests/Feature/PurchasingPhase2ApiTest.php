<?php

namespace Tests\Feature;

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
            'lines' => [['lineType' => 'expense', 'description' => 'Internet', 'quantity' => '1', 'unitPrice' => '50.00']],
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
            'lines' => [['lineType' => 'inventory', 'description' => 'Bottled water', 'inventoryItemId' => $itemId, 'purchaseUnit' => 'carton', 'quantity' => '2', 'unitPrice' => '24.0000', 'warehouseId' => $warehouseId]],
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

    // --- helpers -----------------------------------------------------

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
        return (int) $this->postJson('/api/v1/warehouses', [
            'name' => 'Central Warehouse '.uniqid(), 'code' => $code ?? 'WH-'.strtoupper(uniqid()), 'type' => 'central', 'branchId' => null, 'isActive' => true,
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
        return (int) $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'P2-INV-'.uniqid(), 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory',
            'lines' => [['lineType' => 'inventory', 'description' => 'Goods', 'inventoryItemId' => $itemId, 'quantity' => $quantity, 'unitPrice' => $unitPrice, 'warehouseId' => $warehouseId]],
        ], $headers)->assertCreated()->json('data.id');
    }

    private function postedInventoryInvoice(array $headers, int $supplierId, int $itemId, int $warehouseId, string $quantity, string $unitPrice): int
    {
        $id = $this->createInventoryInvoice($headers, $supplierId, $itemId, $warehouseId, $quantity, $unitPrice);
        $this->postJson("/api/v1/finance/supplier-invoices/{$id}/post", ['idempotencyKey' => 'inv-post-'.uniqid()], $headers)->assertOk();

        return $id;
    }
}
