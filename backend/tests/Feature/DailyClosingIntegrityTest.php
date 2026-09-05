<?php

namespace Tests\Feature;

use App\Domain\Inventory\InventoryPostingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

/**
 * Phase 9 remaining gaps #1 (late financial activity after close) and #2
 * (inventory missing/failed financial-posting blockers). Both reuse
 * existing Phase 6 (InventoryAccountingMapper) and journal_entries
 * semantics rather than inventing a parallel status engine.
 */
class DailyClosingIntegrityTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    public function test_missing_or_failed_inventory_posting_blocks_close(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'inv-fail');
        $branch = $this->branchId($tenant);
        $date = '2030-02-01';

        // A waste movement dated this business day whose journal was never
        // written (simulating a lost/failed posting) — decision() would
        // resolve to POSTED, but impactForMovement() finds no journal, i.e. FAILED.
        $this->makeStockMovementRaw($tenant, $branch, 'waste', '15.00', $date.' 10:00:00', '1.000');

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->assertFalse($preview['canClose']);
        $this->assertContains('UNPOSTED_INVENTORY_FINANCIAL_EVENT', array_column($preview['blockers'], 'code'));
        $this->assertSame(1, $preview['financialIntegrity']['failedPostings']);

        $this->patchJson("/api/v1/finance/daily-closings/{$preview['id']}", ['actualCash' => '0.00'], $headers)->assertOk();
        $close = $this->postJson("/api/v1/finance/daily-closings/{$preview['id']}/close", [], $headers)->assertUnprocessable();
        $this->assertContains('UNPOSTED_INVENTORY_FINANCIAL_EVENT', $close->json('errors.closing'));
    }

    public function test_configuration_required_inventory_posting_blocks_close(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'inv-config');
        $branch = $this->branchId($tenant);
        $date = '2030-02-02';

        // Manual adjustments are always CONFIGURATION_REQUIRED regardless of
        // account setup — InventoryAccountingMapper::decision() hardcodes this.
        $this->makeStockMovementRaw($tenant, $branch, 'adjustment_in', '25.00', $date.' 09:00:00');

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->assertFalse($preview['canClose']);
        $this->assertContains('UNPOSTED_INVENTORY_FINANCIAL_EVENT', array_column($preview['blockers'], 'code'));
        $this->assertSame(1, $preview['financialIntegrity']['missingPostings']);
    }

    public function test_correctly_posted_and_not_applicable_inventory_movements_never_block_close(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'inv-clean');
        $branch = $this->branchId($tenant);
        $date = '2030-02-03';
        $warehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', "BR-$branch-MAIN")->value('id');
        $item = $this->inventoryItemId($tenant);
        $service = app(InventoryPostingService::class);
        $request = Request::create('/inventory-test', 'POST');
        $actor = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');

        $service->post($request, $tenant, ['warehouseId' => $warehouseId, 'itemId' => $item, 'type' => 'stock_in', 'quantity' => '20.000', 'unit' => 'unit', 'unitCost' => '5.0000', 'idempotencyKey' => 'clean-open', 'occurredAt' => $date.' 08:00:00'], $actor);
        // Properly posted waste — a real journal is created synchronously.
        $service->post($request, $tenant, ['warehouseId' => $warehouseId, 'itemId' => $item, 'type' => 'waste', 'quantity' => '1.000', 'unit' => 'unit', 'reason' => 'Spoiled', 'idempotencyKey' => 'clean-waste', 'occurredAt' => $date.' 09:00:00'], $actor);
        // Properly posted stock-count shortage.
        $service->post($request, $tenant, ['warehouseId' => $warehouseId, 'itemId' => $item, 'type' => 'stock_count_variance', 'quantity' => '1.000', 'unit' => 'unit', 'reason' => 'Count', 'countDirection' => 'out', 'idempotencyKey' => 'clean-shortage', 'occurredAt' => $date.' 09:30:00'], $actor);
        // Properly posted stock-count surplus.
        $service->post($request, $tenant, ['warehouseId' => $warehouseId, 'itemId' => $item, 'type' => 'stock_count_variance', 'quantity' => '1.000', 'unit' => 'unit', 'unitCost' => '5.0000', 'reason' => 'Count', 'countDirection' => 'in', 'idempotencyKey' => 'clean-surplus', 'occurredAt' => $date.' 09:45:00'], $actor);
        // Internal transfer — NOT_APPLICABLE, never reaches the posting check.
        $service->post($request, $tenant, ['warehouseId' => $warehouseId, 'itemId' => $item, 'type' => 'transfer_out', 'quantity' => '1.000', 'unit' => 'unit', 'idempotencyKey' => 'clean-transfer', 'occurredAt' => $date.' 10:00:00'], $actor);
        // POS sale consumption — ALREADY_HANDLED_BY_SOURCE, must never double-count as a blocker.
        $this->makeStockMovementRaw($tenant, $branch, 'sale_consumption', '5.00', $date.' 11:00:00');

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->assertNotContains('UNPOSTED_INVENTORY_FINANCIAL_EVENT', array_column($preview['blockers'], 'code'));
        $this->assertSame(0, $preview['financialIntegrity']['missingPostings']);
        $this->assertSame(0, $preview['financialIntegrity']['failedPostings']);
    }

    public function test_inventory_posting_issue_is_scoped_to_tenant_branch_and_date(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'inv-scope');
        $branch = $this->branchId($tenant);
        $otherBranch = $this->branchId($tenant, 'Mall');
        $date = '2030-02-04';

        $this->makeStockMovementRaw($tenant, $otherBranch, 'waste', '15.00', $date.' 10:00:00');
        $this->makeStockMovementRaw($tenant, $branch, 'waste', '15.00', '2030-02-05 10:00:00');

        $foreignTenant = (int) DB::table('tenants')->insertGetId(['name' => 'Foreign Inv', 'slug' => 'daily-closing-inv-foreign', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        app(\App\Services\FinancialSetupService::class)->ensureForTenant($foreignTenant);
        $this->makeStockMovementRaw($foreignTenant, $branch, 'waste', '15.00', $date.' 10:00:00');

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->assertNotContains('UNPOSTED_INVENTORY_FINANCIAL_EVENT', array_column($preview['blockers'], 'code'));
        $this->assertSame(0, $preview['financialIntegrity']['missingPostings']);
        $this->assertSame(0, $preview['financialIntegrity']['failedPostings']);
    }

    public function test_late_financial_activity_after_close_is_detected_without_reopening_or_mutating_snapshot(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'late-activity');
        $branch = $this->branchId($tenant);
        $date = '2030-03-01';

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->patchJson("/api/v1/finance/daily-closings/{$preview['id']}", ['actualCash' => '0.00'], $headers)->assertOk();
        $closed = $this->postJson("/api/v1/finance/daily-closings/{$preview['id']}/close", [], $headers)->assertOk()->json('data');
        $this->assertSame('closed', $closed['status']);
        $closedAt = $closed['closedAt'];
        $snapshotBefore = $closed['summary'];

        // Posted before close — never late.
        $this->makeJournal($tenant, $branch, $date, 'posted', now()->parse($closedAt)->subHour()->toDateTimeString());
        // Posted after close, same business date — LATE.
        $lateId = $this->makeJournal($tenant, $branch, $date, 'posted', now()->parse($closedAt)->addHour()->toDateTimeString(), 'manual', 777);
        // Posted after close, but for the NEXT business date — never late for this closing.
        $this->makeJournal($tenant, $branch, '2030-03-02', 'posted', now()->parse($closedAt)->addHours(2)->toDateTimeString());

        $detail = $this->getJson("/api/v1/finance/daily-closings/{$preview['id']}", $headers)->assertOk()->json('data');
        $this->assertSame(1, $detail['financialIntegrity']['lateActivityAfterClose']);
        $this->assertCount(1, $detail['integrityIssues']['lateActivity']);
        $this->assertSame($lateId, $detail['integrityIssues']['lateActivity'][0]['journalId']);
        $this->assertSame('LATE_FINANCIAL_ACTIVITY_AFTER_CLOSE', $detail['integrityIssues']['lateActivity'][0]['code']);

        // The historical snapshot itself is untouched and the closing is not reopened.
        $this->assertSame($snapshotBefore, $detail['summary']);
        $this->assertSame('closed', $detail['status']);
        $this->patchJson("/api/v1/finance/daily-closings/{$preview['id']}", ['actualCash' => '1.00'], $headers)->assertUnprocessable();
    }

    public function test_late_activity_does_not_leak_across_branch_or_tenant(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'late-scope');
        $branch = $this->branchId($tenant);
        $otherBranch = $this->branchId($tenant, 'Mall');
        $date = '2030-03-03';

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $this->patchJson("/api/v1/finance/daily-closings/{$preview['id']}", ['actualCash' => '0.00'], $headers)->assertOk();
        $closed = $this->postJson("/api/v1/finance/daily-closings/{$preview['id']}/close", [], $headers)->assertOk()->json('data');
        $closedAt = $closed['closedAt'];

        $this->makeJournal($tenant, $otherBranch, $date, 'posted', now()->parse($closedAt)->addHour()->toDateTimeString());

        $foreignTenant = (int) DB::table('tenants')->insertGetId(['name' => 'Foreign Late', 'slug' => 'daily-closing-late-foreign', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $this->makeJournal($foreignTenant, $branch, $date, 'posted', now()->parse($closedAt)->addHour()->toDateTimeString());

        $detail = $this->getJson("/api/v1/finance/daily-closings/{$preview['id']}", $headers)->assertOk()->json('data');
        $this->assertSame(0, $detail['financialIntegrity']['lateActivityAfterClose']);
        $this->assertCount(0, $detail['integrityIssues']['lateActivity']);
    }
}
