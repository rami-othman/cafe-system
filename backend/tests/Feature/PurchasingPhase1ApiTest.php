<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Purchasing Phase 0 + Phase 1 — supplier_invoice_lines are subordinate to
 * the existing supplier_invoices AP record (never a second Purchase Invoice
 * table). Posting still emits exactly one journal entry from the header's
 * own resolved debit account; a Goods Receipt does not exist yet, so an
 * inventory-type purchase invoice must never change physical stock.
 */
class PurchasingPhase1ApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_inventory_line_invoice_computes_totals_server_side_ignores_client_subtotal_and_leaves_stock_untouched(): void
    {
        $tenant = $this->tenant('purchasing-inv-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers, 'kg');
        $beforeMovements = DB::table('stock_movements')->where('tenant_id', $tenant)->count();
        $beforeBalance = DB::table('stock_balances')->where('tenant_id', $tenant)->sum('quantity_on_hand');
        $beforeCost = DB::table('inventory_items')->where('id', $itemId)->value('latest_unit_cost');

        $payload = [
            'supplierId' => $supplierId, 'invoiceNumber' => 'BEANS-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01',
            'invoiceType' => 'inventory',
            // A tampered client-side subtotal must be ignored entirely once lines are present.
            'subtotal' => '999999.00',
            'lines' => [[
                'lineType' => 'inventory', 'description' => 'Coffee beans', 'inventoryItemId' => $itemId,
                'quantity' => '5.000', 'unitPrice' => '16.0000',
            ]],
        ];
        $created = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertCreated()
            ->assertJsonPath('data.subtotal', '80.00')->assertJsonPath('data.taxAmount', '0.00')->assertJsonPath('data.totalAmount', '80.00')
            ->assertJsonCount(1, 'data.lines');
        $id = $created->json('data.id');
        $this->assertSame('80.00', $created->json('data.lines.0.lineTotal'));
        $this->assertSame('5.000', $created->json('data.lines.0.quantity'));
        $this->assertSame('0.000', $created->json('data.lines.0.receivedQuantity'));

        $this->postJson("/api/v1/finance/supplier-invoices/{$id}/post", ['idempotencyKey' => 'beans-post-1'], $headers)->assertOk();

        $inventoryAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1100')->value('id');
        $journalId = DB::table('supplier_invoices')->where('id', $id)->value('journal_entry_id');
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $journalId)->get();
        $this->assertSame(80.0, (float) $lines->firstWhere('financial_account_id', $inventoryAccountId)->debit);
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'supplier_invoice')->where('source_id', $id)->count());

        // The critical Phase 1 invariant: an inventory purchase invoice never moves physical stock.
        $this->assertSame($beforeMovements, DB::table('stock_movements')->where('tenant_id', $tenant)->count());
        $this->assertEquals((float) $beforeBalance, (float) DB::table('stock_balances')->where('tenant_id', $tenant)->sum('quantity_on_hand'));
        $this->assertSame($beforeCost, DB::table('inventory_items')->where('id', $itemId)->value('latest_unit_cost'));
    }

    public function test_service_line_invoice_posts_through_the_headers_expense_category_account(): void
    {
        $tenant = $this->tenant('purchasing-svc-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $categoryId = $this->expenseCategory($tenant, $headers, '6120');

        $payload = [
            'supplierId' => $supplierId, 'invoiceNumber' => 'NET-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01',
            'invoiceType' => 'expense', 'expenseCategoryId' => $categoryId,
            'lines' => [['lineType' => 'expense', 'description' => 'Internet service', 'quantity' => '1', 'unitPrice' => '100.00']],
        ];
        $id = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertCreated()
            ->assertJsonPath('data.totalAmount', '100.00')->json('data.id');

        $this->postJson("/api/v1/finance/supplier-invoices/{$id}/post", ['idempotencyKey' => 'net-post-1'], $headers)->assertOk();
        $utilitiesAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6120')->value('id');
        $journalId = DB::table('supplier_invoices')->where('id', $id)->value('journal_entry_id');
        $this->assertSame(100.0, (float) DB::table('journal_entry_lines')->where('journal_entry_id', $journalId)->where('financial_account_id', $utilitiesAccountId)->value('debit'));
    }

    public function test_asset_line_requires_an_asset_group_account_and_other_line_rejects_one(): void
    {
        $tenant = $this->tenant('purchasing-asset-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $fixedAssetsId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1500')->value('id');
        $cogsAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '5000')->value('id');

        $base = ['supplierId' => $supplierId, 'invoiceNumber' => 'ASSET-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'other'];

        // asset line against a non-asset account is rejected.
        $this->postJson('/api/v1/finance/supplier-invoices', [...$base, 'debitAccountId' => $cogsAccountId, 'lines' => [['lineType' => 'asset', 'description' => 'Espresso machine', 'quantity' => '1', 'unitPrice' => '2500.00']]], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('debitAccountId');

        // other line against an asset-group account is rejected (must use "asset" instead).
        $this->postJson('/api/v1/finance/supplier-invoices', [...$base, 'debitAccountId' => $fixedAssetsId, 'lines' => [['lineType' => 'other', 'description' => 'Misc', 'quantity' => '1', 'unitPrice' => '50.00']]], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('debitAccountId');

        // asset line against an asset-group account succeeds.
        $created = $this->postJson('/api/v1/finance/supplier-invoices', [...$base, 'debitAccountId' => $fixedAssetsId, 'lines' => [['lineType' => 'asset', 'description' => 'Espresso machine', 'quantity' => '1', 'unitPrice' => '2500.00']]], $headers)
            ->assertCreated()->assertJsonPath('data.totalAmount', '2500.00');
        $this->assertSame('asset', $created->json('data.lines.0.lineType'));
    }

    public function test_mixed_line_types_on_one_invoice_are_rejected_in_phase_one(): void
    {
        $tenant = $this->tenant('purchasing-mixed-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers, 'kg');

        $payload = [
            'supplierId' => $supplierId, 'invoiceNumber' => 'MIX-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory',
            'lines' => [
                ['lineType' => 'inventory', 'description' => 'Coffee beans', 'inventoryItemId' => $itemId, 'quantity' => '1', 'unitPrice' => '10.00'],
                ['lineType' => 'expense', 'description' => 'Delivery charge', 'quantity' => '1', 'unitPrice' => '5.00'],
            ],
        ];
        $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertUnprocessable()->assertJsonValidationErrors('lines');
    }

    public function test_line_type_must_match_the_resolved_invoice_type(): void
    {
        $tenant = $this->tenant('purchasing-mismatch-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $categoryId = $this->expenseCategory($tenant, $headers, '6130');

        $payload = [
            'supplierId' => $supplierId, 'invoiceNumber' => 'MISMATCH-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01',
            'invoiceType' => 'expense', 'expenseCategoryId' => $categoryId,
            'lines' => [['lineType' => 'inventory', 'description' => 'Should not be allowed', 'inventoryItemId' => $this->inventoryItem($headers, 'kg'), 'quantity' => '1', 'unitPrice' => '10.00']],
        ];
        $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertUnprocessable()->assertJsonValidationErrors('invoiceTypeId');
    }

    public function test_header_only_invoice_without_lines_behaves_exactly_as_before(): void
    {
        $tenant = $this->tenant('purchasing-legacy-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $categoryId = $this->expenseCategory($tenant, $headers, '6100');

        $payload = ['supplierId' => $supplierId, 'invoiceNumber' => 'LEGACY-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'expense', 'expenseCategoryId' => $categoryId, 'subtotal' => '250.00'];
        $created = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertCreated()->assertJsonPath('data.totalAmount', '250.00')->assertJsonCount(0, 'data.lines');
        $id = $created->json('data.id');

        $this->patchJson("/api/v1/finance/supplier-invoices/{$id}", [...$payload, 'subtotal' => '300.00'], $headers)->assertOk()->assertJsonPath('data.totalAmount', '300.00');
        $this->getJson("/api/v1/finance/supplier-invoices/{$id}", $headers)->assertOk()->assertJsonCount(0, 'data.lines');
    }

    public function test_updating_a_lines_based_invoice_replaces_lines_and_recomputes_totals_but_requires_lines_on_every_edit(): void
    {
        $tenant = $this->tenant('purchasing-update-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers, 'kg');

        $payload = [
            'supplierId' => $supplierId, 'invoiceNumber' => 'UPD-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory',
            'lines' => [
                ['lineType' => 'inventory', 'description' => 'Beans', 'inventoryItemId' => $itemId, 'quantity' => '2', 'unitPrice' => '10.00'],
                ['lineType' => 'inventory', 'description' => 'Milk', 'inventoryItemId' => $this->inventoryItem($headers, 'liter'), 'quantity' => '3', 'unitPrice' => '2.00'],
            ],
        ];
        $id = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertCreated()->assertJsonPath('data.totalAmount', '26.00')->json('data.id');

        // Replacing with a single line recomputes the total and drops the old lines.
        $updated = $this->patchJson("/api/v1/finance/supplier-invoices/{$id}", [
            ...$payload, 'lines' => [['lineType' => 'inventory', 'description' => 'Beans only', 'inventoryItemId' => $itemId, 'quantity' => '1', 'unitPrice' => '10.00']],
        ], $headers)->assertOk()->assertJsonPath('data.totalAmount', '10.00')->assertJsonCount(1, 'data.lines');
        $this->assertSame(1, DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $id)->count());

        // Editing a lines-based invoice without resending lines is rejected outright — it can never
        // silently strand the header total out of sync with the lines actually on file.
        $withoutLines = $payload;
        unset($withoutLines['lines']);
        $this->patchJson("/api/v1/finance/supplier-invoices/{$id}", [...$withoutLines, 'subtotal' => '1.00'], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('lines');
    }

    public function test_posted_lines_invoice_is_immutable_and_reversal_still_works(): void
    {
        $tenant = $this->tenant('purchasing-immutable-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers, 'kg');
        $payload = ['supplierId' => $supplierId, 'invoiceNumber' => 'IMM-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory', 'lines' => [['lineType' => 'inventory', 'description' => 'Beans', 'inventoryItemId' => $itemId, 'quantity' => '1', 'unitPrice' => '20.00']]];
        $id = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/supplier-invoices/{$id}/post", ['idempotencyKey' => 'imm-post-1'], $headers)->assertOk();

        $this->patchJson("/api/v1/finance/supplier-invoices/{$id}", $payload, $headers)->assertUnprocessable();

        $reversed = $this->postJson("/api/v1/finance/supplier-invoices/{$id}/reverse", [], $headers)->assertOk()->json('data');
        $this->assertSame('cancelled', $reversed['status']);
        $this->assertNotNull($reversed['reversalJournalEntryId']);
        // The lines remain on file as an unmutated historical record.
        $this->assertSame(1, DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $id)->count());
    }

    public function test_posting_replay_with_the_same_idempotency_key_does_not_duplicate_the_journal(): void
    {
        $tenant = $this->tenant('purchasing-idem-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers, 'kg');
        $payload = ['supplierId' => $supplierId, 'invoiceNumber' => 'IDEM-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory', 'idempotencyKey' => 'create-idem-1', 'lines' => [['lineType' => 'inventory', 'description' => 'Beans', 'inventoryItemId' => $itemId, 'quantity' => '1', 'unitPrice' => '20.00']]];

        $first = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertCreated()->json('data.id');
        $replay = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertCreated()->json('data.id');
        $this->assertSame($first, $replay);
        $this->assertSame(1, DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('invoice_number', 'IDEM-001')->count());
        $this->assertSame(1, DB::table('supplier_invoice_lines')->where('supplier_invoice_id', $first)->count());

        $this->postJson("/api/v1/finance/supplier-invoices/{$first}/post", ['idempotencyKey' => 'post-idem-1'], $headers)->assertOk();
        $this->postJson("/api/v1/finance/supplier-invoices/{$first}/post", ['idempotencyKey' => 'post-idem-1'], $headers)->assertOk();
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'supplier_invoice')->where('source_id', $first)->count());
    }

    public function test_purchasing_center_list_exposes_purchase_type_paid_remaining_and_filters(): void
    {
        $tenant = $this->tenant('purchasing-list-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers, 'kg');
        $payload = ['supplierId' => $supplierId, 'invoiceNumber' => 'LIST-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory', 'lines' => [['lineType' => 'inventory', 'description' => 'Beans', 'inventoryItemId' => $itemId, 'quantity' => '5', 'unitPrice' => '16.00']]];
        $id = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/supplier-invoices/{$id}/post", ['idempotencyKey' => 'list-post-1'], $headers)->assertOk();

        $row = $this->getJson('/api/v1/finance/purchases', $headers)->assertOk()->json('data.0');
        $this->assertSame('inventory', $row['purchaseType']);
        $this->assertSame('80.00', $row['totalAmount']);
        $this->assertSame('0.00', $row['paidAmount']);
        $this->assertSame('80.00', $row['remainingAmount']);
        $this->assertSame('posted', $row['documentStatus']);
        $this->assertSame('unpaid', $row['paymentStatus']);

        $this->getJson('/api/v1/finance/purchases?purchaseType=inventory', $headers)->assertOk()->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/finance/purchases?purchaseType=expense', $headers)->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/finance/purchases?paymentStatus=paid', $headers)->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/finance/purchases?paymentStatus=unpaid', $headers)->assertOk()->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/finance/purchases?search=LIST-001', $headers)->assertOk()->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/finance/purchases?search=NOPE', $headers)->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_purchasing_center_show_returns_lines_and_related_payments(): void
    {
        $tenant = $this->tenant('purchasing-show-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers, 'kg');
        $payload = ['supplierId' => $supplierId, 'invoiceNumber' => 'SHOW-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory', 'lines' => [['lineType' => 'inventory', 'description' => 'Beans', 'inventoryItemId' => $itemId, 'quantity' => '5', 'unitPrice' => '16.00']]];
        $id = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/supplier-invoices/{$id}/post", ['idempotencyKey' => 'show-post-1'], $headers)->assertOk();

        $cash = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        $method = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $this->postJson('/api/v1/finance/supplier-payments', [
            'supplierId' => $supplierId, 'paymentDate' => '2026-09-05', 'amount' => '30.00', 'paymentMethodId' => $method, 'financialLocationId' => $cash,
            'idempotencyKey' => 'show-pay-1', 'allocations' => [['invoiceId' => $id, 'amount' => '30.00']],
        ], $headers)->assertCreated();

        $detail = $this->getJson("/api/v1/finance/purchases/{$id}", $headers)->assertOk()->json('data');
        $this->assertCount(1, $detail['lines']);
        $this->assertSame('Beans', $detail['lines'][0]['description']);
        $this->assertCount(1, $detail['payments']);
        $this->assertSame('30.00', $detail['payments'][0]['amount']);
        $this->assertSame('50.00', $detail['remainingAmount']);
        $this->assertSame('partial', $detail['paymentStatus']);
    }

    public function test_tenant_isolation_and_permission_are_enforced_on_the_purchasing_endpoints(): void
    {
        $tenantA = $this->tenant('purchasing-tenant-a');
        $headersA = $this->headers($tenantA);
        $supplierId = $this->supplier($headersA);
        $itemId = $this->inventoryItem($headersA, 'kg');
        $payload = ['supplierId' => $supplierId, 'invoiceNumber' => 'ISO-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory', 'lines' => [['lineType' => 'inventory', 'description' => 'Beans', 'inventoryItemId' => $itemId, 'quantity' => '1', 'unitPrice' => '10.00']]];
        $id = $this->postJson('/api/v1/finance/supplier-invoices', $payload, $headersA)->assertCreated()->json('data.id');

        $tenantB = $this->tenant('purchasing-tenant-b');
        $headersB = $this->headers($tenantB);
        $this->getJson('/api/v1/finance/purchases', $headersB)->assertOk()->assertJsonCount(0, 'data');
        $this->getJson("/api/v1/finance/purchases/{$id}", $headersB)->assertNotFound();

        // Cross-tenant inventory item is rejected at line-build time, even with a valid tenant-B supplier.
        $supplierBId = $this->supplier($headersB);
        $crossPayload = [...$payload, 'supplierId' => $supplierBId, 'invoiceNumber' => 'ISO-002', 'lines' => [['lineType' => 'inventory', 'description' => 'Beans', 'inventoryItemId' => $itemId, 'quantity' => '1', 'unitPrice' => '10.00']]];
        $this->postJson('/api/v1/finance/supplier-invoices', $crossPayload, $headersB)->assertUnprocessable()->assertJsonValidationErrors('lines');

        // A cashier-role user without finance.purchases.view is denied the Purchasing Center read.
        $cashierId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantA, 'name' => 'Cashier', 'email' => 'cashier-purchasing@example.test', 'password' => bcrypt('password'), 'role' => 'cashier', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $plainToken = "purchasing-cashier-$tenantA";
        DB::table('api_tokens')->insert(['tenant_id' => $tenantA, 'user_id' => $cashierId, 'name' => 'cashier-token', 'token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);
        $this->getJson('/api/v1/finance/purchases', ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantA])->assertForbidden();
    }

    public function test_branch_scoped_manager_only_sees_purchases_for_assigned_branches(): void
    {
        $tenant = $this->tenant('purchasing-branch-1');
        $headers = $this->headers($tenant);
        $branchAllowed = (int) DB::table('branches')->where('tenant_id', $tenant)->value('id');
        $branchOther = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Other Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers, 'kg');

        $allowedInvoiceId = $this->postJson('/api/v1/finance/supplier-invoices', ['supplierId' => $supplierId, 'branchId' => $branchAllowed, 'invoiceNumber' => 'BR-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory', 'lines' => [['lineType' => 'inventory', 'description' => 'Beans', 'inventoryItemId' => $itemId, 'quantity' => '1', 'unitPrice' => '10.00']]], $headers)->assertCreated()->json('data.id');
        $this->postJson('/api/v1/finance/supplier-invoices', ['supplierId' => $supplierId, 'branchId' => $branchOther, 'invoiceNumber' => 'BR-002', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01', 'invoiceType' => 'inventory', 'lines' => [['lineType' => 'inventory', 'description' => 'Beans', 'inventoryItemId' => $itemId, 'quantity' => '1', 'unitPrice' => '10.00']]], $headers)->assertCreated();

        foreach (\App\Support\FinanceAccess::defaultPermissionsForRole('manager') as $permission) {
            DB::table('finance_role_permissions')->updateOrInsert(['tenant_id' => $tenant, 'role' => 'manager', 'permission' => $permission], ['created_at' => now(), 'updated_at' => now()]);
        }
        $managerId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => 'Branch Manager', 'email' => 'manager-purchasing@example.test', 'password' => bcrypt('password'), 'role' => 'manager', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('user_branches')->insert(['user_id' => $managerId, 'branch_id' => $branchAllowed, 'tenant_id' => $tenant, 'created_at' => now(), 'updated_at' => now()]);
        $plainToken = "purchasing-manager-$tenant";
        DB::table('api_tokens')->insert(['tenant_id' => $tenant, 'user_id' => $managerId, 'name' => 'manager-token', 'token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);
        $managerHeaders = ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenant];

        $list = $this->getJson('/api/v1/finance/purchases', $managerHeaders)->assertOk()->json('data');
        $this->assertCount(1, $list);
        $this->assertSame($allowedInvoiceId, $list[0]['id']);
        $this->getJson("/api/v1/finance/purchases/{$allowedInvoiceId}", $managerHeaders)->assertOk();
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

    private function inventoryItem(array $headers, string $unit): int
    {
        return (int) $this->postJson('/api/v1/inventory/items', [
            'nameAr' => 'صنف اختبار', 'nameEn' => 'Purchasing Test Item '.uniqid(), 'sku' => 'PUR-'.strtoupper(uniqid()),
            'itemType' => 'raw_material', 'unit' => $unit, 'minimumStock' => '0.000', 'reorderLevel' => '0.000',
            'latestUnitCost' => '1.0000', 'isActive' => true,
        ], $headers)->assertCreated()->json('data.id');
    }
}
