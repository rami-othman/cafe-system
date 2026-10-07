<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\FinancialAccountBalanceQuery;
use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * The shift float (عهدة) is physical cash left in the drawer for change. It is OFF the books: never in the drawer
 * ledger, never in sales, never in the close transfer. It carries to the next shift by itself; a cashier replaces it
 * only by choosing "new float". The cashier counts the whole drawer; only the ledger-side part is varied/transferred.
 */
final class ShiftFloatTest extends TestCase
{
    use RefreshDatabase;

    private int $tenant;

    private int $branch;

    private User $owner;

    private array $headers;

    protected function setUp(): void
    {
        parent::setUp();
        $this->tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Float Tenant', 'slug' => 'float-tenant', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $this->branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $this->tenant, 'name' => 'Float Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($this->tenant, $this->branch);
        $this->owner = User::query()->create(['tenant_id' => $this->tenant, 'name' => 'Float Owner', 'email' => 'float-owner@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true]);
        $this->headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($this->tenant, $this->owner)];
    }

    public function test_opening_needs_no_cash_count_and_the_float_stays_off_the_ledger(): void
    {
        $shift = $this->openShift(['newFloat' => true, 'floatAmount' => '500.00']);

        $row = DB::table('shifts')->find($shift['id']);
        $this->assertSame('500.00', $row->float_amount);
        $this->assertSame('0.00', $row->opening_cash, 'The float is not drawer-ledger cash.');
        $this->assertSame('0.00', $row->closing_float_amount, 'Nothing is retained on the ledger at close.');
        $this->assertSame('0.00', $this->ledger());
        $this->assertEquals(500.0, $shift['physicalOpeningCash']);
    }

    public function test_close_transfers_only_what_is_above_the_float(): void
    {
        $shift = $this->openShift(['newFloat' => true, 'floatAmount' => '500.00']);
        $this->cashArrives('500.00'); // sales cash on the drawer ledger

        // 1000 in the drawer, 500 of it is the float.
        $preview = $this->getJson("/api/v1/shifts/{$shift['id']}/close-preview", $this->headers)->assertOk()->json('data');
        $this->assertSame('500.00', $preview['period']['floatAmount']);
        $this->assertSame('1000.00', $preview['period']['physicalExpectedCash']);
        $this->assertSame('500.00', $preview['period']['transferAmount']);

        $closed = $this->postJson("/api/v1/shifts/{$shift['id']}/close", ['closingCash' => '1000.00'], $this->headers)->assertOk()->json('data');

        $this->assertSame('0.00', DB::table('shifts')->find($shift['id'])->cash_difference);
        $this->assertSame('500.00', $closed['transfer']['amount']);
        $this->assertSame('0.00', $this->ledger(), 'Only sales left the drawer ledger; the float never entered it.');
        $this->assertEquals(1000.0, $closed['physicalClosingCash']);
    }

    public function test_the_previous_float_carries_to_the_next_shift_without_any_option(): void
    {
        $first = $this->openShift(['newFloat' => true, 'floatAmount' => '500.00']);
        $this->postJson("/api/v1/shifts/{$first['id']}/close", ['closingCash' => '500.00'], $this->headers)->assertOk();

        $readiness = $this->getJson("/api/v1/shifts/readiness?branchId={$this->branch}", $this->headers)->assertOk()->json('data');
        $this->assertSame('500.00', $readiness['carriedFloat']);

        $second = $this->openShift([]);
        $this->assertSame('500.00', DB::table('shifts')->find($second['id'])->float_amount);
    }

    public function test_choosing_a_new_float_replaces_the_old_one_whatever_it_was(): void
    {
        $first = $this->openShift(['newFloat' => true, 'floatAmount' => '500.00']);
        $this->cashArrives('200.00');
        $this->postJson("/api/v1/shifts/{$first['id']}/close", ['closingCash' => '700.00'], $this->headers)->assertOk();

        $second = $this->openShift(['newFloat' => true, 'floatAmount' => '300.00']);

        $this->assertSame('300.00', DB::table('shifts')->find($second['id'])->float_amount);
        $this->assertSame('0.00', $this->ledger());
    }

    public function test_counting_less_than_the_float_is_refused(): void
    {
        $shift = $this->openShift(['newFloat' => true, 'floatAmount' => '500.00']);

        $this->postJson("/api/v1/shifts/{$shift['id']}/close", ['closingCash' => '400.00'], $this->headers)
            ->assertUnprocessable()->assertJsonValidationErrors('closingCash');
        $this->assertSame('open', DB::table('shifts')->find($shift['id'])->status);
    }

    public function test_a_shortage_is_measured_against_the_ledger_part_only(): void
    {
        $shift = $this->openShift(['newFloat' => true, 'floatAmount' => '500.00']);
        $this->cashArrives('500.00');

        // 990 counted = 500 float + 490 of 500 sales: a 10 shortage, not 510.
        $this->postJson("/api/v1/shifts/{$shift['id']}/close", ['closingCash' => '990.00'], $this->headers)
            ->assertUnprocessable()->assertJsonValidationErrors('cashDifferenceReason');
        $closed = $this->postJson("/api/v1/shifts/{$shift['id']}/close", ['closingCash' => '990.00', 'cashDifferenceReason' => 'unknown_shortage'], $this->headers)->assertOk()->json('data');

        $this->assertSame('-10.00', DB::table('shifts')->find($shift['id'])->cash_difference);
        $this->assertSame('490.00', $closed['transfer']['amount']);
        $this->assertSame('0.00', $this->ledger());
    }

    public function test_retrying_the_same_close_is_idempotent_with_a_float(): void
    {
        $shift = $this->openShift(['newFloat' => true, 'floatAmount' => '500.00']);
        $this->cashArrives('100.00');

        $first = $this->postJson("/api/v1/shifts/{$shift['id']}/close", ['closingCash' => '600.00'], $this->headers)->assertOk()->json('data.closeTransferId');
        $second = $this->postJson("/api/v1/shifts/{$shift['id']}/close", ['closingCash' => '600.00'], $this->headers)->assertOk()->json('data.closeTransferId');

        $this->assertSame($first, $second);
        $this->assertSame(1, DB::table('cash_transfers')->where('tenant_id', $this->tenant)->where('idempotency_key', 'shift-close-transfer:'.$shift['id'])->count());
    }

    public function test_a_new_float_needs_an_amount(): void
    {
        $this->postJson('/api/v1/shifts/current', ['branchId' => $this->branch, 'newFloat' => true], $this->headers)
            ->assertUnprocessable()->assertJsonValidationErrors('floatAmount');
    }

    private function openShift(array $extra): array
    {
        return $this->postJson('/api/v1/shifts/current', ['branchId' => $this->branch] + $extra, $this->headers)->assertCreated()->json('data');
    }

    /** Cash sales reach the drawer ledger (a manual journal on the drawer's own account/location stands in for POS cash payments). */
    private function cashArrives(string $amount): void
    {
        $drawer = $this->drawer();
        $account = (int) DB::table('financial_locations')->where('id', $drawer)->value('financial_account_id');
        app(\App\Services\AccountingPostingService::class)->post(\Illuminate\Http\Request::create('/'), $this->tenant, [
            'branchId' => $this->branch, 'sourceType' => 'manual', 'sourceId' => random_int(1000, 999999), 'sourceEvent' => 'FLOAT_TEST_SALE',
            'entryDate' => now()->toDateString(), 'description' => 'مبيعات نقدية',
            'lines' => [
                ['accountCode' => DB::table('financial_accounts')->where('id', $account)->value('code'), 'debit' => $amount, 'financialLocationId' => $drawer],
                ['accountCode' => '4000', 'credit' => $amount],
            ],
        ], $this->owner->id);
    }

    private function ledger(): string
    {
        $drawer = $this->drawer();
        $account = (int) DB::table('financial_locations')->where('id', $drawer)->value('financial_account_id');

        return app(FinancialAccountBalanceQuery::class)->summary($this->tenant, $account, locationId: $drawer)['balance'];
    }

    private function drawer(): int
    {
        return (int) DB::table('branches')->where('id', $this->branch)->value('pos_cash_financial_location_id');
    }

    private function safe(): int
    {
        return (int) DB::table('financial_locations')->where('tenant_id', $this->tenant)->where('code', 'MAIN-SAFE')->value('id');
    }
}
