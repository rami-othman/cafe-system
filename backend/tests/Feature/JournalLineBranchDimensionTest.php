<?php

namespace Tests\Feature;

use App\Services\InterBranchAccount;
use App\Services\JournalEntryService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

class JournalLineBranchDimensionTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    private function owner(int $tenant): array
    {
        $headers = $this->headers($tenant, 'owner', 'line-branch');
        $id = (int) DB::table('users')->where('tenant_id', $tenant)->where('email', "line-branch-owner-$tenant@test.local")->value('id');

        return [$headers, $id];
    }

    private function secondBranch(int $tenant): int
    {
        return (int) DB::table('branches')->insertGetId([
            'tenant_id' => $tenant, 'name' => 'TierFour', 'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function postEntry(int $tenant, int $actor, array $data): int
    {
        $service = app(JournalEntryService::class);
        $request = Request::create('/line-branch-test', 'POST');
        $id = $service->createDraft($request, $tenant, $data + ['entryDate' => '2030-12-15'], $actor);
        $service->post($request, $tenant, $id, $actor);

        return $id;
    }

    public function test_lines_inherit_the_entry_branch_and_reversal_keeps_it(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        [, $actor] = $this->owner($tenant);

        $id = $this->postEntry($tenant, $actor, ['branchId' => $branch, 'lines' => [
            ['accountId' => $this->accountId($tenant, '1010'), 'debit' => '50.00'],
            ['accountId' => $this->accountId($tenant, '3000'), 'credit' => '50.00'],
        ]]);
        $this->assertSame([$branch, $branch], DB::table('journal_entry_lines')->where('journal_entry_id', $id)->orderBy('line_number')->pluck('branch_id')->map(fn ($v) => (int) $v)->all());

        $reversal = app(JournalEntryService::class)->reverse(Request::create('/r', 'POST'), $tenant, $id, $actor);
        $this->assertSame([$branch, $branch], DB::table('journal_entry_lines')->where('journal_entry_id', $reversal)->pluck('branch_id')->map(fn ($v) => (int) $v)->all());
    }

    public function test_unbalanced_branches_are_rejected_unless_auto_balanced_through_the_inter_branch_account(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $a = $this->branchId($tenant);
        $b = $this->secondBranch($tenant);
        [$headers, $actor] = $this->owner($tenant);
        $expense = $this->accountId($tenant, '6190');
        $cash = $this->accountId($tenant, '1010');

        // Shared cost paid by head office, allocated 60/40 to two branches.
        $lines = [
            ['accountId' => $expense, 'branchId' => $a, 'debit' => '60.00'],
            ['accountId' => $expense, 'branchId' => $b, 'debit' => '40.00'],
            ['accountId' => $cash, 'branchId' => null, 'credit' => '100.00'],
        ];
        try {
            $this->postEntry($tenant, $actor, ['branchId' => null, 'lines' => $lines]);
            $this->fail('A multi-branch entry with unbalanced branches must be rejected.');
        } catch (ValidationException $e) {
            $this->assertArrayHasKey('lines', $e->errors());
        }

        $id = $this->postEntry($tenant, $actor, ['branchId' => null, 'lines' => $lines, 'autoBalanceBranches' => true]);
        $clearing = app(InterBranchAccount::class)->id($tenant);
        $this->assertSame('جاري الفروع', DB::table('financial_accounts')->where('id', $clearing)->value('name_ar'));

        $byBranch = DB::table('journal_entry_lines')->where('journal_entry_id', $id)->get()
            ->groupBy(fn ($l) => $l->branch_id === null ? 'company' : (string) $l->branch_id)
            ->map(fn ($g) => round($g->sum(fn ($l) => (float) $l->debit - (float) $l->credit), 2));
        $this->assertEqualsCanonicalizing(['company', (string) $a, (string) $b], $byBranch->keys()->all());
        foreach ($byBranch as $branchKey => $net) {
            $this->assertSame(0.0, (float) $net, "Branch $branchKey must balance inside the entry.");
        }
        $this->assertSame(0.0, round((float) DB::table('journal_entry_lines')->where('journal_entry_id', $id)->where('financial_account_id', $clearing)->sum(DB::raw('debit - credit')), 2));

        $pnlA = $this->getJson("/api/v1/finance/reports/profit-loss?dateFrom=2030-12-15&dateTo=2030-12-15&branchId=$a", $headers)->assertOk()->json('data');
        $pnlB = $this->getJson("/api/v1/finance/reports/profit-loss?dateFrom=2030-12-15&dateTo=2030-12-15&branchId=$b", $headers)->assertOk()->json('data');
        $this->assertSame('60.00', $pnlA['totals']['operatingExpenses']);
        $this->assertSame('40.00', $pnlB['totals']['operatingExpenses']);

        foreach ([$a, $b] as $branch) {
            $trial = $this->getJson("/api/v1/finance/reports/trial-balance?dateFrom=2030-12-15&dateTo=2030-12-15&branchId=$branch", $headers)->assertOk()->json('data');
            $this->assertTrue($trial['totals']['balanced'], "Branch $branch trial balance must balance.");
        }
        $all = $this->getJson('/api/v1/finance/reports/profit-loss?dateFrom=2030-12-15&dateTo=2030-12-15', $headers)->assertOk()->json('data');
        $this->assertSame('100.00', $all['totals']['operatingExpenses']);
    }

    public function test_cost_center_must_belong_to_the_tenant_and_is_stored_on_the_line(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        [, $actor] = $this->owner($tenant);
        $center = (int) DB::table('cost_centers')->insertGetId(['tenant_id' => $tenant, 'code' => 'BAR', 'name_ar' => 'البار', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $lines = fn (int $cc) => [
            ['accountId' => $this->accountId($tenant, '6190'), 'debit' => '10.00', 'costCenterId' => $cc],
            ['accountId' => $this->accountId($tenant, '1010'), 'credit' => '10.00'],
        ];

        try {
            $this->postEntry($tenant, $actor, ['branchId' => $this->branchId($tenant), 'lines' => $lines(999999)]);
            $this->fail('An unknown cost center must be rejected.');
        } catch (ValidationException $e) {
            $this->assertArrayHasKey('lines.0.costCenterId', $e->errors());
        }
        $id = $this->postEntry($tenant, $actor, ['branchId' => $this->branchId($tenant), 'lines' => $lines($center)]);
        $this->assertSame($center, (int) DB::table('journal_entry_lines')->where('journal_entry_id', $id)->where('line_number', 1)->value('cost_center_id'));
    }

    public function test_inter_branch_account_is_idempotent_and_uses_the_phinix_parent_when_present(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $first = app(InterBranchAccount::class)->ensure($tenant);
        $this->assertSame($first, app(InterBranchAccount::class)->ensure($tenant));
        $this->assertSame(1, DB::table('financial_accounts')->where('tenant_id', $tenant)->where('name_ar', 'جاري الفروع')->count());
        $this->assertSame($first, (int) DB::table('sales_account_mappings')->where('tenant_id', $tenant)->where('mapping_key', 'branches.inter_branch')->value('financial_account_id'));
    }
}
