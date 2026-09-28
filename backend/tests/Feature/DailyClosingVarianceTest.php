<?php

namespace Tests\Feature;

use App\Services\AccountingPostingService;
use App\Support\Money;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

final class DailyClosingVarianceTest extends TestCase
{
    use DailyClosingFixtures;
    use RefreshDatabase;

    public function test_supplier_payment_from_safe_changes_expected_cash_by_ledger_amount(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $headers = $this->headers($tenant, 'owner', 'variance-ledger');
        $date = '2030-05-01';
        $before = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data.cash.expectedCash');
        $sales = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data.sales');
        $this->assertArrayHasKey('salesSum', $sales);
        $this->assertArrayHasKey('salesTotal', $sales);
        $this->assertArrayHasKey('salesNet', $sales);
        $safe = $this->locationId($tenant, 'MAIN-SAFE');
        $actor = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        app(AccountingPostingService::class)->post(Request::create('/'), $tenant, [
            'sourceType' => 'supplier_payment', 'sourceId' => 999001, 'sourceEvent' => 'SUPPLIER_PAYMENT_POSTED',
            'branchId' => $branch, 'entryDate' => $date, 'description' => 'دفعة مورد اختبارية',
            'lines' => [
                ['accountCode' => '2000', 'debit' => '30.00'],
                ['accountCode' => '1020', 'credit' => '30.00', 'financialLocationId' => $safe],
            ],
        ], $actor);
        $after = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data.cash.expectedCash');
        $this->assertSame(3000, Money::cents($before) - Money::cents($after));
    }

    public function test_difference_warns_and_requires_reason_before_posting(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $headers = $this->headers($tenant, 'owner', 'variance-reason');
        $date = '2030-05-02';
        $safe = $this->locationId($tenant, 'MAIN-SAFE');
        DB::table('branches')->where('id', $branch)->update(['shift_close_destination_financial_location_id' => $safe]);
        $preview = $this->getJson("/api/v1/finance/daily-closing?branchId=$branch&date=$date", $headers)->assertOk()->json('data');
        $actual = Money::decimal(Money::cents($preview['cash']['expectedCash']) + 500);
        $ready = $this->patchJson("/api/v1/finance/daily-closings/{$preview['id']}", ['actualCash' => $actual], $headers)->assertOk()->json('data');
        $this->assertContains('CASH_DIFFERENCE', array_column($ready['warnings'], 'code'));
        $this->postJson("/api/v1/finance/daily-closings/{$preview['id']}/close", [], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('closing');
        DB::table('branches')->where('id', $branch)->update(['shift_close_destination_financial_location_id' => null]);
        $this->postJson("/api/v1/finance/daily-closings/{$preview['id']}/close", ['cashDifferenceReason' => 'unknown_surplus'], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('closing');
        DB::table('branches')->where('id', $branch)->update(['shift_close_destination_financial_location_id' => $safe]);
        $closed = $this->postJson("/api/v1/finance/daily-closings/{$preview['id']}/close", ['cashDifferenceReason' => 'unknown_surplus'], $headers)->assertOk()->json('data');
        $this->assertSame('closed', $closed['status']);
        $this->assertDatabaseHas('journal_entries', [
            'tenant_id' => $tenant, 'source_type' => 'daily_closing_cash_variance',
            'source_id' => $preview['id'], 'entry_date' => $date,
        ]);
    }
}
