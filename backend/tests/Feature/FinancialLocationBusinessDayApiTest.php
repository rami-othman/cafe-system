<?php

namespace Tests\Feature;

use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * C6 completion — FinancialLocationController's "todayIncoming"/"todayOutgoing"
 * buckets must be scoped to the location's branch-local business day, not the
 * server's UTC calendar day. entries.entry_date is a true DATE column, so the
 * branch-local date value is used directly (no UTC instant-range math needed).
 */
final class FinancialLocationBusinessDayApiTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    public function test_today_buckets_use_branch_local_day_not_utc_day(): void
    {
        [$tenant, $branch] = $this->tenantWithBranch('Asia/Damascus');
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashLocation = $this->cashLocation($tenant, $branch);

        // UTC 2026-09-20 22:00 is already 2026-09-21 01:00 in Damascus (UTC+3).
        Carbon::setTestNow(Carbon::create(2026, 9, 20, 22, 0, 0, 'UTC'));

        // Inside the branch-local business day (Damascus 09-21) -> counted as "today".
        $this->postJournal($tenant, $cashLocation['accountId'], $cashLocation['id'], '3000', '100.00', '2026-09-21');
        // Same UTC calendar date (09-20) but outside the branch-local day -> excluded from "today".
        $this->postJournal($tenant, $cashLocation['accountId'], $cashLocation['id'], '3000', '50.00', '2026-09-20');

        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant)];
        $data = $this->getJson("/api/v1/finance/cash-accounts/{$cashLocation['id']}", $headers)->assertOk()->json('data');

        $this->assertSame('100.00', $data['todayIncoming'], 'Only the entry inside the branch-local day should count as today.');
        // The balance total is unaffected by which day is "today" — both entries are posted.
        $this->assertSame('150.00', $data['balance']);
    }

    public function test_today_bucket_falls_back_to_utc_for_a_location_with_no_branch(): void
    {
        // branches.timezone is NOT NULL (defaults to 'UTC'), so the only realistic
        // "no branch timezone" case is a shared location with branch_id = null
        // (e.g. a tenant-wide safe not tied to one branch) — BranchLocalDate::today(null)
        // is documented to fall back to UTC for exactly this case.
        [$tenant] = $this->tenantWithBranch('Asia/Damascus');
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashLocation = $this->cashLocation($tenant, null);

        Carbon::setTestNow(Carbon::create(2026, 9, 20, 22, 0, 0, 'UTC'));

        // Matches the UTC calendar date -> counted, since the branch has no timezone.
        $this->postJournal($tenant, $cashLocation['accountId'], $cashLocation['id'], '3000', '75.00', '2026-09-20');
        // Would be "today" only under a Damascus-style ahead-of-UTC offset; excluded under the UTC fallback.
        $this->postJournal($tenant, $cashLocation['accountId'], $cashLocation['id'], '3000', '25.00', '2026-09-21');

        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant)];
        $data = $this->getJson("/api/v1/finance/cash-accounts/{$cashLocation['id']}", $headers)->assertOk()->json('data');

        $this->assertSame('75.00', $data['todayIncoming']);
        $this->assertSame('100.00', $data['balance']);
    }

    /** @return array{0:int,1:int} */
    private function tenantWithBranch(?string $timezone): array
    {
        $tenant = (int) DB::table('tenants')->insertGetId([
            'name' => 'C6 Business Day', 'slug' => 'c6-business-day-'.uniqid(), 'status' => 'active',
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $branch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $tenant, 'name' => 'Branch', 'timezone' => $timezone, 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);

        return [$tenant, $branch];
    }

    /** @return array{id:int,accountId:int} */
    private function cashLocation(int $tenant, ?int $branch): array
    {
        $accountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $locationId = (int) DB::table('financial_locations')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'financial_account_id' => $accountId,
            'code' => 'C6-CASH-'.($branch ?? 'shared').'-'.uniqid(), 'name' => 'C6 Test Cash Location', 'kind' => 'cash', 'type' => 'main_safe', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);

        return ['id' => $locationId, 'accountId' => $accountId];
    }

    private function postJournal(int $tenant, int $debitAccountId, int $debitLocationId, string $creditAccountCode, string $amount, string $entryDate): int
    {
        $creditAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', $creditAccountCode)->value('id');
        $journalId = (int) DB::table('journal_entries')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => null, 'entry_number' => 'C6J-'.uniqid(), 'entry_date' => $entryDate,
            'source_type' => 'manual', 'status' => 'posted', 'posted_at' => now(), 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('journal_entry_lines')->insert([
            'tenant_id' => $tenant, 'journal_entry_id' => $journalId, 'financial_account_id' => $debitAccountId, 'financial_location_id' => $debitLocationId,
            'line_number' => 1, 'debit' => $amount, 'credit' => '0.00', 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('journal_entry_lines')->insert([
            'tenant_id' => $tenant, 'journal_entry_id' => $journalId, 'financial_account_id' => $creditAccountId,
            'line_number' => 2, 'debit' => '0.00', 'credit' => $amount, 'created_at' => now(), 'updated_at' => now(),
        ]);

        return $journalId;
    }
}
