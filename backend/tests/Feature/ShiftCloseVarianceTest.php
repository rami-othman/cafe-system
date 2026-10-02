<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\FinancialAccountBalanceQuery;
use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** T2 — manual shift close: a ledger/counted difference is allowed with a reason and posted to the variance account. */
final class ShiftCloseVarianceTest extends TestCase
{
    use RefreshDatabase;

    private int $tenant;

    private int $branch;

    private User $owner;

    private array $headers;

    protected function setUp(): void
    {
        parent::setUp();
        $this->tenant = (int) DB::table('tenants')->insertGetId(['name' => 'T2 Tenant', 'slug' => 'scv-tenant', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $this->branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $this->tenant, 'name' => 'Main', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($this->tenant, $this->branch);
        $this->owner = User::query()->create(['tenant_id' => $this->tenant, 'name' => 'Owner', 'email' => 'scv-owner@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true]);
        $this->headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($this->tenant, $this->owner)];
        $this->putJson("/api/v1/cafe-configuration/branches/{$this->branch}", [
            'shiftCloseDestinationFinancialLocationId' => $this->safe(), 'shiftClosingFloatAmount' => '0.00',
        ], $this->headers)->assertOk();
    }

    public function test_shortage_with_a_reason_posts_a_debit_to_6180_and_transfers_the_counted_amount(): void
    {
        $this->fund('1000.00');
        $shift = $this->open('1000.00');

        $closed = $this->postJson("/api/v1/shifts/{$shift}/close", [
            'closingCash' => '900.00', 'cashDifferenceReason' => 'unknown_shortage',
        ], $this->headers)->assertOk()->json('data');

        $row = DB::table('shifts')->find($shift);
        $this->assertSame('closed', $row->status);
        $this->assertSame('-100.00', $row->cash_difference);
        $variance6180 = (int) DB::table('financial_accounts')->where('tenant_id', $this->tenant)->where('code', '6180')->value('id');
        $this->assertDatabaseHas('journal_entry_lines', ['journal_entry_id' => $row->cash_variance_journal_entry_id, 'financial_account_id' => $variance6180, 'debit' => '100.00', 'credit' => '0.00']);
        $transfer = DB::table('cash_transfers')->find($row->close_transfer_id);
        $this->assertSame('900.00', $transfer->amount);
        $this->assertSame('0.00', $this->ledger());
        $this->assertSame('unknown_shortage', $closed['cash']['reason']);
    }

    public function test_surplus_with_a_reason_posts_a_credit_to_the_separate_4040_overage_account(): void
    {
        $this->fund('500.00');
        $shift = $this->open('500.00');

        $this->postJson("/api/v1/shifts/{$shift}/close", [
            'closingCash' => '550.00', 'cashDifferenceReason' => 'unknown_surplus',
        ], $this->headers)->assertOk();

        $row = DB::table('shifts')->find($shift);
        $this->assertSame('50.00', $row->cash_difference);
        // Overage is income on its own account (4040) — never mixed into the 6180 shortage expense.
        $over4040 = (int) DB::table('financial_accounts')->where('tenant_id', $this->tenant)->where('code', '4040')->value('id');
        $variance6180 = (int) DB::table('financial_accounts')->where('tenant_id', $this->tenant)->where('code', '6180')->value('id');
        $this->assertDatabaseHas('journal_entry_lines', ['journal_entry_id' => $row->cash_variance_journal_entry_id, 'financial_account_id' => $over4040, 'debit' => '0.00', 'credit' => '50.00']);
        $this->assertDatabaseMissing('journal_entry_lines', ['journal_entry_id' => $row->cash_variance_journal_entry_id, 'financial_account_id' => $variance6180]);
        $this->assertSame('0.00', $this->ledger());
    }

    public function test_difference_without_a_reason_is_rejected(): void
    {
        $this->fund('300.00');
        $shift = $this->open('300.00');

        $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '310.00'], $this->headers)
            ->assertUnprocessable()->assertJsonValidationErrors('cashDifferenceReason');
        $this->assertSame('open', DB::table('shifts')->where('id', $shift)->value('status'));
    }

    public function test_matching_count_posts_no_variance_entry(): void
    {
        $this->fund('200.00');
        $shift = $this->open('200.00');

        $closed = $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '200.00'], $this->headers)->assertOk()->json('data');

        $this->assertNull($closed['cashVarianceJournalEntryId'] ?? DB::table('shifts')->where('id', $shift)->value('cash_variance_journal_entry_id'));
        $this->assertSame('0.00', DB::table('shifts')->where('id', $shift)->value('cash_difference'));
    }

    public function test_branch_selected_variance_account_receives_the_entry_instead_of_6180(): void
    {
        $selected = (int) DB::table('financial_accounts')->insertGetId([
            'tenant_id' => $this->tenant, 'code' => 'SCV-VAR', 'name_ar' => 'فروقات مخصصة', 'name_en' => 'Custom variance',
            'account_group' => 'expenses', 'normal_balance' => 'debit', 'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->putJson("/api/v1/cafe-configuration/branches/{$this->branch}", ['cashVarianceAccountId' => $selected], $this->headers)->assertOk();
        $this->fund('400.00');
        $shift = $this->open('400.00');

        $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '390.00', 'cashDifferenceReason' => 'change_error'], $this->headers)->assertOk();

        $journalId = DB::table('shifts')->where('id', $shift)->value('cash_variance_journal_entry_id');
        $this->assertDatabaseHas('journal_entry_lines', ['journal_entry_id' => $journalId, 'financial_account_id' => $selected, 'debit' => '10.00']);
    }

    public function test_branch_selected_overage_account_receives_a_surplus(): void
    {
        $selected = (int) DB::table('financial_accounts')->insertGetId([
            'tenant_id' => $this->tenant, 'code' => 'SCV-OVR', 'name_ar' => 'إيراد زيادة مخصص', 'name_en' => 'Custom overage',
            'account_group' => 'revenue', 'normal_balance' => 'credit', 'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->putJson("/api/v1/cafe-configuration/branches/{$this->branch}", ['cashOverAccountId' => $selected], $this->headers)->assertOk()
            ->assertJsonPath('data.cashOverAccountId', $selected);
        $this->fund('400.00');
        $shift = $this->open('400.00');

        $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '425.00', 'cashDifferenceReason' => 'unknown_surplus'], $this->headers)->assertOk();

        $journalId = DB::table('shifts')->where('id', $shift)->value('cash_variance_journal_entry_id');
        $this->assertDatabaseHas('journal_entry_lines', ['journal_entry_id' => $journalId, 'financial_account_id' => $selected, 'credit' => '25.00']);
    }

    public function test_manual_cash_movement_outside_the_shift_leaves_close_open_but_flags_unexplained_cash(): void
    {
        $this->fund('600.00');
        $shift = $this->open('600.00');
        $drawer = $this->drawer();
        $account = (int) DB::table('financial_locations')->where('id', $drawer)->value('financial_account_id');
        // A manual journal against the drawer's own account/location, entirely
        // outside shift_cash_movements/orders/payments — the drawer ledger
        // moves, but the shift's own cash summary has no idea why.
        app(\App\Services\AccountingPostingService::class)->post(\Illuminate\Http\Request::create('/'), $this->tenant, [
            'branchId' => $this->branch, 'sourceType' => 'manual', 'sourceId' => 999, 'sourceEvent' => 'MANUAL_TEST',
            'entryDate' => now()->toDateString(), 'description' => 'حركة يدوية خارج الوردية',
            'lines' => [
                ['accountCode' => DB::table('financial_accounts')->where('id', $account)->value('code'), 'debit' => '25.00', 'financialLocationId' => $drawer],
                ['accountCode' => '4000', 'credit' => '25.00'],
            ],
        ], $this->owner->id);

        $preview = $this->getJson("/api/v1/shifts/{$shift}/close-preview", $this->headers)->assertOk()->json('data');
        $this->assertTrue($preview['period']['canClose']);
        $this->assertNotSame('0.00', $preview['period']['unexplainedCash']);
    }

    public function test_todays_close_accepts_a_stale_preview_version(): void
    {
        $this->fund('120.00');
        $shift = $this->open('120.00');
        $preview = $this->getJson("/api/v1/shifts/{$shift}/close-preview", $this->headers)->assertOk()->json('data');

        $this->postJson("/api/v1/shifts/{$shift}/close", [
            'closingCash' => '120.00', 'previewVersion' => $preview['period']['version'],
        ], $this->headers)->assertOk();
        $this->assertSame('closed', DB::table('shifts')->where('id', $shift)->value('status'));
    }

    public function test_resubmitting_the_same_close_request_does_not_duplicate_the_variance_entry(): void
    {
        $this->fund('700.00');
        $shift = $this->open('700.00');

        $first = $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '710.00', 'cashDifferenceReason' => 'unknown_surplus'], $this->headers)->assertOk()->json('data');
        $second = $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '710.00', 'cashDifferenceReason' => 'unknown_surplus'], $this->headers)->assertOk()->json('data');

        $this->assertSame($first['closeTransferId'], $second['closeTransferId']);
        $journalId = DB::table('shifts')->where('id', $shift)->value('cash_variance_journal_entry_id');
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $this->tenant)->where('source_type', 'shift_cash_variance')->where('source_id', $shift)->count());
        $this->assertSame($journalId, DB::table('journal_entries')->where('tenant_id', $this->tenant)->where('source_type', 'shift_cash_variance')->where('source_id', $shift)->value('id'));
    }

    // ---- helpers ---------------------------------------------------------------

    private function open(string $cash): int
    {
        return (int) $this->postJson('/api/v1/shifts/current', ['branchId' => $this->branch, 'openingCash' => $cash], $this->headers)
            ->assertCreated()->json('data.id');
    }

    private function fund(string $amount): void
    {
        $this->postJson('/api/v1/finance/cash-transfers', [
            'fromFinancialLocationId' => $this->safe(), 'toFinancialLocationId' => $this->drawer(),
            'amount' => $amount, 'transferDate' => now()->toDateString(), 'idempotencyKey' => 'scv-fund-'.uniqid(),
        ], $this->headers)->assertCreated();
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
