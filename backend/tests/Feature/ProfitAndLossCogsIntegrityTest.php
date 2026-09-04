<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

/**
 * Phase 9: the P&L `integrity` block must be a real, backend-computed COGS
 * posting-completeness signal (reusing `InventoryAccountingMapper`, the same
 * engine Daily Closing's `UNPOSTED_INVENTORY_FINANCIAL_EVENT` check uses) —
 * never a static "ledgerBased: true" placeholder Flutter would have to trust
 * blindly as "healthy".
 */
class ProfitAndLossCogsIntegrityTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    public function test_profit_and_loss_integrity_is_healthy_with_no_inventory_events(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'pnl-integrity-clean');
        $date = '2030-05-01';

        $data = $this->getJson("/api/v1/finance/reports/profit-loss?dateFrom=$date&dateTo=$date", $headers)
            ->assertOk()->json('data');

        $this->assertTrue($data['integrity']['ledgerBased']);
        $this->assertTrue($data['integrity']['cogsComplete']);
        $this->assertSame(0, $data['integrity']['unpostedInventoryEventsCount']);
    }

    public function test_profit_and_loss_integrity_flags_an_unposted_inventory_event_in_range(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $headers = $this->headers($tenant, 'owner', 'pnl-integrity-gap');
        $date = '2030-05-02';

        // Bypasses InventoryPostingService/InventoryAccountingMapper — no journal is created for
        // this waste movement, so the mapper reports it as an unposted required Finance impact.
        $this->makeStockMovementRaw($tenant, $branch, 'waste', '25.00', "$date 09:00:00");

        $data = $this->getJson("/api/v1/finance/reports/profit-loss?dateFrom=$date&dateTo=$date&branchId=$branch", $headers)
            ->assertOk()->json('data');

        $this->assertFalse($data['integrity']['cogsComplete']);
        $this->assertSame(1, $data['integrity']['unpostedInventoryEventsCount']);

        // Outside the requested date range: must not be counted.
        $outsideRange = $this->getJson('/api/v1/finance/reports/profit-loss?dateFrom=2030-06-01&dateTo=2030-06-30&branchId='.$branch, $headers)
            ->assertOk()->json('data');
        $this->assertTrue($outsideRange['integrity']['cogsComplete']);
    }
}
