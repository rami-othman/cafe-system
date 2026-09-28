<?php

namespace Tests\Feature;

use App\Services\FinancialAccountBalanceQuery;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

final class FinancialAccountBalanceCardTest extends TestCase
{
    use DailyClosingFixtures;
    use RefreshDatabase;

    public function test_parent_balance_includes_posted_descendants_and_ignores_drafts(): void
    {
        $this->seed();
        $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $parent = (int) DB::table('financial_accounts')->insertGetId([
            'tenant_id' => $tenant, 'code' => 'BAL-ROOT', 'name_ar' => 'النقد', 'name_en' => 'Cash',
            'account_group' => 'assets', 'normal_balance' => 'debit', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $child = (int) DB::table('financial_accounts')->insertGetId([
            'tenant_id' => $tenant, 'parent_account_id' => $parent, 'code' => 'BAL-CHILD',
            'name_ar' => 'فرع النقد', 'name_en' => 'Child cash', 'account_group' => 'assets',
            'normal_balance' => 'debit', 'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
        foreach (['posted' => '45.00', 'draft' => '999.00'] as $status => $amount) {
            $entry = (int) DB::table('journal_entries')->insertGetId([
                'tenant_id' => $tenant, 'entry_number' => 'BAL-'.uniqid(), 'entry_date' => '2026-09-28',
                'source_type' => 'manual', 'status' => $status, 'posted_at' => $status === 'posted' ? now() : null,
                'created_at' => now(), 'updated_at' => now(),
            ]);
            DB::table('journal_entry_lines')->insert([
                'tenant_id' => $tenant, 'journal_entry_id' => $entry, 'financial_account_id' => $child,
                'line_number' => 1, 'debit' => $amount, 'credit' => '0.00', 'created_at' => now(), 'updated_at' => now(),
            ]);
        }

        $balance = app(FinancialAccountBalanceQuery::class)->balanceWithChildren($tenant, $parent);
        $this->assertSame('45.00', $balance['balance']);
        $this->assertSame('45.00', $balance['totalDebit']);
        $this->assertSame('0.00', $balance['totalCredit']);
        $this->assertSame('2026-09-28', $balance['lastMovementDate']);

        $queries = [];
        DB::listen(function ($query) use (&$queries): void {
            if (str_contains($query->sql, 'journal_entry_lines') && str_contains($query->sql, 'group by')) {
                $queries[] = $query->sql;
            }
        });
        $headers = $this->headers($tenant, 'owner', 'balance-card');
        $index = $this->getJson('/api/v1/finance/accounts?search=BAL-&perPage=2', $headers)->assertOk()->json('data');
        $byCode = collect($index)->keyBy('code');
        $this->assertSame('45.00', $byCode['BAL-ROOT']['balance']);
        $this->assertSame('45.00', $byCode['BAL-CHILD']['balance']);
        $this->assertCount(1, $queries);
        $this->getJson("/api/v1/finance/accounts/{$parent}", $headers)->assertOk()
            ->assertJsonPath('data.balance', '45.00')->assertJsonPath('data.totalDebit', '45.00');
    }
}
