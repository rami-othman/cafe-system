<?php

namespace Tests\Feature;

use App\Services\CashDrawerConsolidationService;
use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

final class CashDrawerConsolidationTest extends TestCase
{
    use RefreshDatabase;

    public function test_dry_run_preserves_history_and_apply_moves_exact_amounts_once(): void
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Cash repair', 'slug' => 'cash-repair', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'TierFour', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch);
        $source = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->first();
        $copy = (array) $source;
        unset($copy['id']);
        $copy['code'] = '139';
        $account = DB::table('financial_accounts')->insertGetId($copy);
        $old = DB::table('financial_locations')->where('tenant_id', $tenant)->where('financial_account_id', $source->id)->pluck('id')->map(fn ($id) => (int) $id)->all();
        $drawer = DB::table('financial_locations')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'financial_account_id' => $account, 'code' => '139', 'name' => 'TierFour', 'kind' => 'cash', 'type' => 'cash_drawer', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(\App\Services\AccountingPostingService::class)->post(request(), $tenant, [
            'sourceType' => 'opening_balance', 'sourceId' => $tenant, 'sourceEvent' => 'TEST_CASH_HISTORY',
            'lines' => [['accountCode' => '1010', 'debit' => '17.00'],
                ['accountCode' => '1010', 'credit' => '24.00', 'financialLocationId' => $old[0]],
                ['accountCode' => '3000', 'debit' => '7.00']],
        ], null);
        $before = DB::table('journal_entry_lines')->where('tenant_id', $tenant)->orderBy('id')->get()->map(fn ($row) => (array) $row)->all();
        $service = app(CashDrawerConsolidationService::class);
        $dry = $service->run($tenant, $branch, $source->id, $account, $old, $drawer);
        $this->assertSame('-7.00', $dry['combinedBalance']);
        $this->assertSame($before, DB::table('journal_entry_lines')->where('tenant_id', $tenant)->orderBy('id')->get()->map(fn ($row) => (array) $row)->all());
        $this->assertTrue($service->run($tenant, $branch, $source->id, $account, $old, $drawer, true, $dry['fingerprint'], str_repeat('a', 64))['applied']);
        foreach ($before as $line) {
            $after = DB::table('journal_entry_lines')->find($line['id']);
            $this->assertSame([$line['debit'], $line['credit'], $line['journal_entry_id']], [$after->debit, $after->credit, $after->journal_entry_id]);
            if ((int) $line['financial_account_id'] === (int) $source->id) {
                $this->assertSame([$account, $drawer], [(int) $after->financial_account_id, (int) $after->financial_location_id]);
            }
        }
        $this->assertSame($drawer, (int) DB::table('branches')->where('id', $branch)->value('pos_cash_financial_location_id'));
        $this->assertSame(0, DB::table('financial_locations')->whereIn('id', $old)->where('is_active', true)->count());
        $this->assertTrue($service->run($tenant, $branch, $source->id, $account, $old, $drawer, true, $dry['fingerprint'], str_repeat('a', 64))['alreadyApplied']);
        $this->assertSame(1, DB::table('activity_logs')->where('tenant_id', $tenant)->where('action', 'finance.cash_drawer_consolidated')->count());
    }

    public function test_historical_locations_and_unlocated_cash_do_not_become_live_drawer_cash(): void
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Historical cash', 'slug' => 'historical-cash', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'TierFour', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch);
        $source = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->first();
        $old = (int) DB::table('branches')->where('id', $branch)->value('pos_cash_financial_location_id');
        $history = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('financial_account_id', $source->id)->whereNull('branch_id')->value('id');
        $copy = (array) $source;
        unset($copy['id']);
        $copy['code'] = '139';
        $account = DB::table('financial_accounts')->insertGetId($copy);
        $drawer = DB::table('financial_locations')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'financial_account_id' => $account, 'code' => '139', 'name' => 'TierFour', 'kind' => 'cash', 'type' => 'cash_drawer', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(\App\Services\AccountingPostingService::class)->post(request(), $tenant, [
            'sourceType' => 'opening_balance', 'sourceId' => $tenant, 'sourceEvent' => 'TEST_HISTORICAL_PROVENANCE',
            'lines' => [['accountCode' => '1010', 'debit' => '17.00'],
                ['accountCode' => '1010', 'credit' => '24.00', 'financialLocationId' => $history],
                ['accountCode' => '1010', 'debit' => '3.00', 'financialLocationId' => $old],
                ['accountCode' => '1010', 'credit' => '3.00', 'financialLocationId' => $old],
                ['accountCode' => '3000', 'debit' => '7.00']],
        ], null);
        $before = DB::table('journal_entry_lines')->where('tenant_id', $tenant)->orderBy('id')->get();
        $service = app(CashDrawerConsolidationService::class);
        $dry = $service->run($tenant, $branch, $source->id, $account, [$old], $drawer, historicalLocations: [$history], includePlan: true);
        $this->assertSame('-7.00', $dry['combinedBalance']);
        $this->assertArrayHasKey('beforeState', $dry);
        $this->assertTrue($service->run($tenant, $branch, $source->id, $account, [$old], $drawer, true, $dry['fingerprint'], str_repeat('b', 64), [$history])['applied']);
        foreach ($before as $line) {
            $after = DB::table('journal_entry_lines')->find($line->id);
            $this->assertSame([$line->debit, $line->credit, $line->journal_entry_id], [$after->debit, $after->credit, $after->journal_entry_id]);
            if ((int) $line->financial_account_id === (int) $source->id) {
                $this->assertSame($account, (int) $after->financial_account_id);
                $this->assertSame($line->financial_location_id === $old ? $drawer : $line->financial_location_id, $after->financial_location_id);
            }
        }
        $this->assertSame('0.00', app(\App\Services\ShiftDrawerReadinessService::class)->drawerLedgerBalance($tenant, DB::table('financial_locations')->find($drawer)));
        $this->assertFalse((bool) DB::table('financial_locations')->where('id', $history)->value('is_active'));
        $this->assertSame($account, (int) DB::table('financial_locations')->where('id', $history)->value('financial_account_id'));
        $this->assertTrue($service->run($tenant, $branch, $source->id, $account, [$old], $drawer, historicalLocations: [$history])['alreadyApplied']);
    }
}
