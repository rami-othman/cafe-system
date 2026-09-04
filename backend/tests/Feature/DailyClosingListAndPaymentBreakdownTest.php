<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

/**
 * Phase 8: the Daily Closing list (`GET finance/daily-closings`) must show live,
 * backend-computed net sales/expected cash/readiness for open days (not the raw
 * `daily_closings` snapshot columns, which stay NULL until close), and the
 * per-payment-method breakdown returned by `DailyClosingSummaryService` must be
 * real backend aggregation, not something Flutter is left to rebuild.
 */
class DailyClosingListAndPaymentBreakdownTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    public function test_list_row_for_an_open_day_reflects_live_summary_and_readiness(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $headers = $this->headers($tenant);
        $date = '2030-02-01';

        $order = $this->makeOrder($tenant, $branch, '100.00', "$date 10:00:00");
        $this->makePayment($tenant, $branch, $order, '100.00', "$date 10:00:00");

        // Creates the daily_closings row via the preview (get-or-create) endpoint.
        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)
            ->assertOk()->json('data');
        $this->assertSame('100.00', $preview['sales']['netSales']);

        $list = $this->getJson('/api/v1/finance/daily-closings?perPage=100', $headers)->assertOk()->json('data');
        $row = collect($list)->firstWhere('id', $preview['id']);
        $this->assertNotNull($row);
        $this->assertSame('open', $row['status']);
        // Live-derived, not the NULL snapshot columns an open row has in `daily_closings`.
        $this->assertSame('100.00', $row['netSales']);
        $this->assertArrayHasKey('readiness', $row);
        $this->assertArrayHasKey('warningsCount', $row);
        $this->assertSame('blocked', $row['readiness']); // MISSING_ACTUAL_CASH
    }

    public function test_payment_breakdown_is_grouped_by_real_payment_method_and_nets_refunds(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $headers = $this->headers($tenant);
        $date = '2030-02-02';

        $cashMethodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $card = $this->makeCardPaymentMethod($tenant, 'DC-CARD');

        $order1 = $this->makeOrder($tenant, $branch, '100.00', "$date 09:00:00");
        $payment1 = $this->makePayment($tenant, $branch, $order1, '100.00', "$date 09:00:00", 'cash', $cashMethodId);
        $order2 = $this->makeOrder($tenant, $branch, '50.00', "$date 09:05:00");
        $this->makePayment($tenant, $branch, $order2, '50.00', "$date 09:05:00", 'card', $card['methodId']);
        $this->makeRefund($tenant, $branch, $order1, $payment1, '20.00', "$date 09:10:00");

        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)
            ->assertOk()->json('data');

        $breakdown = collect($preview['summary']['paymentBreakdown'])->keyBy('method');
        $this->assertSame('100.00', $breakdown['Cash']['gross']);
        $this->assertSame('20.00', $breakdown['Cash']['refunded']);
        $this->assertSame('80.00', $breakdown['Cash']['net']);
        $this->assertSame('50.00', $breakdown['DC-CARD']['gross']);
        $this->assertSame('0.00', $breakdown['DC-CARD']['refunded']);
    }

    public function test_supplier_payments_can_be_filtered_by_payment_date_range(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $headers = $this->headers($tenant);
        $supplier = $this->supplierId($tenant);

        $this->makeSupplierPayment($tenant, $branch, $supplier, '40.00', '2030-03-01');
        $this->makeSupplierPayment($tenant, $branch, $supplier, '60.00', '2030-03-05');

        $inRange = $this->getJson('/api/v1/finance/supplier-payments?from=2030-03-01&to=2030-03-01', $headers)
            ->assertOk()->json('data');
        $this->assertCount(1, $inRange);
        $this->assertSame('40.00', $inRange[0]['amount']);

        $outOfRange = $this->getJson('/api/v1/finance/supplier-payments?from=2030-03-02&to=2030-03-04', $headers)
            ->assertOk()->json('data');
        $this->assertCount(0, $outOfRange);
    }
}
