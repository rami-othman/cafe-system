<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

/** Maintenance tracking: expenses tagged against an asset (classification only), contracts, report and alerts. */
class AssetMaintenanceTest extends TestCase
{
    use RefreshDatabase;
    use DailyClosingFixtures;

    private int $tenant;

    private array $headers;

    private int $branch;

    private function boot(): void
    {
        $this->seed();
        $this->tenant = $this->tenantId();
        $this->branch = $this->branchId($this->tenant);
        $this->headers = $this->headers($this->tenant, 'owner', 'maint');
    }

    private function account(string $code, string $name, string $group, string $normal): int
    {
        return (int) DB::table('financial_accounts')->insertGetId(['tenant_id' => $this->tenant, 'code' => $code, 'name_ar' => $name, 'name_en' => $name,
            'account_group' => $group, 'normal_balance' => $normal, 'is_active' => true, 'is_system_protected' => false, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function asset(string $name = 'آلة إسبريسو', array $extra = []): int
    {
        $asset = $this->account('1610', 'الأجهزة', 'assets', 'debit');
        $acc = $this->account('1611', 'مجمع اهتلاك الأجهزة', 'assets', 'credit');
        $exp = $this->account('6210', 'مصروف اهتلاك الأجهزة', 'expenses', 'debit');
        $this->postJson('/api/v1/finance/assets/categories', ['code' => 'EQ', 'nameAr' => 'أجهزة', 'assetAccountId' => $asset, 'accumulatedAccountId' => $acc,
            'expenseAccountId' => $exp, 'defaultMethod' => 'straight_line', 'defaultLifeMonths' => 60], $this->headers)->assertCreated();
        $category = (int) DB::table('asset_categories')->where('tenant_id', $this->tenant)->where('code', 'EQ')->value('id');

        return (int) $this->postJson('/api/v1/finance/assets', array_merge(['nameAr' => $name, 'categoryId' => $category, 'branchId' => $this->branch,
            'acquisitionDate' => now()->subMonths(2)->toDateString(), 'acquisitionCost' => '1200.00', 'fundingAccountId' => $this->accountId($this->tenant, '1010'), 'activate' => true], $extra), $this->headers)
            ->assertCreated()->json('data.id');
    }

    private function entryCount(): int
    {
        return (int) DB::table('journal_entries')->where('tenant_id', $this->tenant)->count();
    }

    public function test_expense_can_be_tagged_at_creation_and_linked_later_without_touching_the_ledger(): void
    {
        $this->boot();
        $asset = $this->asset();
        $category = $this->expenseCategoryId($this->tenant);
        $draft = ['branchId' => $this->branch, 'expenseCategoryId' => $category, 'amount' => '100.00', 'expenseDate' => now()->toDateString(), 'description' => 'صيانة آلة'];

        // Tagged at creation.
        $tagged = $this->postJson('/api/v1/finance/expenses', $draft + ['fixedAssetId' => $asset, 'assetExpenseKind' => 'repair'], $this->headers)
            ->assertCreated()->assertJsonPath('data.fixedAssetId', $asset)->assertJsonPath('data.assetExpenseKind', 'repair')->json('data');

        // Editing without the field keeps the tag; explicit null clears it.
        $this->patchJson("/api/v1/finance/expenses/{$tagged['id']}", $draft + ['description' => 'تعديل'], $this->headers)->assertOk()->assertJsonPath('data.fixedAssetId', $asset);
        $this->patchJson("/api/v1/finance/expenses/{$tagged['id']}", $draft + ['fixedAssetId' => null], $this->headers)->assertOk()->assertJsonPath('data.fixedAssetId', null);

        // Linked afterwards, ledger untouched.
        $plain = $this->postJson('/api/v1/finance/expenses', $draft, $this->headers)->assertCreated()->assertJsonPath('data.fixedAssetId', null)->json('data.id');
        $entries = $this->entryCount();
        $summary = $this->postJson("/api/v1/finance/assets/$asset/link-expense", ['expenseId' => $plain, 'kind' => 'maintenance'], $this->headers)->assertOk()->json('data');
        $this->assertSame($entries, $this->entryCount());
        $this->assertSame([$plain], array_column($summary['expenses'], 'id'));
        $this->assertSame('0.00', $summary['totals']['paid']);
        $this->assertSame('100.00', $summary['totals']['pending']);
        $this->getJson("/api/v1/finance/expenses?fixedAssetId=$asset", $this->headers)->assertOk()->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/finance/expenses?unlinked=1', $this->headers)->assertOk()->assertJsonCount(1, 'data'); // the cleared one

        // Unlink.
        $after = $this->deleteJson("/api/v1/finance/assets/$asset/link-expense/$plain", [], $this->headers)->assertOk()->json('data');
        $this->assertSame([], $after['expenses']);
        $this->deleteJson("/api/v1/finance/assets/$asset/link-expense/$plain", [], $this->headers)->assertUnprocessable();
    }

    public function test_paid_expense_counts_in_summary_and_report_and_rejects_bad_targets(): void
    {
        $this->boot();
        $asset = $this->asset();
        $today = now()->toDateString();
        $paid = $this->makeExpense($this->tenant, $this->branch, '100.00', $today, 'paid');
        $other = $this->makeExpense($this->tenant, $this->branch, '40.00', $today, 'paid');
        $rejected = $this->makeExpense($this->tenant, $this->branch, '15.00', $today, 'rejected', null);

        $this->postJson("/api/v1/finance/assets/$asset/link-expense", ['expenseId' => $paid, 'kind' => 'repair'], $this->headers)->assertOk();
        $summary = $this->postJson("/api/v1/finance/assets/$asset/link-expense", ['expenseId' => $other], $this->headers)->assertOk()->json('data'); // default kind = maintenance
        $this->assertSame('100.00', $summary['totals']['repair']);
        $this->assertSame('40.00', $summary['totals']['maintenance']);
        $this->assertSame('140.00', $summary['totals']['paid']);

        $this->postJson("/api/v1/finance/assets/$asset/link-expense", ['expenseId' => $rejected], $this->headers)->assertUnprocessable();
        $this->postJson("/api/v1/finance/assets/$asset/link-expense", ['expenseId' => 999999], $this->headers)->assertNotFound();
        $this->postJson("/api/v1/finance/assets/$asset/link-expense", ['expenseId' => $paid, 'kind' => 'bogus'], $this->headers)->assertUnprocessable();

        $report = $this->getJson("/api/v1/finance/assets/reports/maintenance?dateFrom=$today&dateTo=$today", $this->headers)->assertOk()->json('data');
        $this->assertCount(1, $report['items']);
        $this->assertSame('140.00', $report['items'][0]['paid']);
        $this->assertSame('140.00', $report['totals']['paid']);
        $only = $this->getJson("/api/v1/finance/assets/reports/maintenance?dateFrom=$today&dateTo=$today&kind=repair", $this->headers)->assertOk()->json('data');
        $this->assertSame('100.00', $only['totals']['paid']);

        // A disposed asset cannot be tagged.
        DB::table('fixed_assets')->where('id', $asset)->update(['status' => 'disposed']);
        $this->postJson('/api/v1/finance/expenses', ['branchId' => $this->branch, 'expenseCategoryId' => $this->expenseCategoryId($this->tenant), 'amount' => '5.00',
            'expenseDate' => $today, 'description' => 'x', 'fixedAssetId' => $asset], $this->headers)->assertUnprocessable()->assertJsonValidationErrors('fixedAssetId');
    }

    public function test_contracts_crud_validation_and_expiry_alerts(): void
    {
        $this->boot();
        $asset = $this->asset();
        $base = ['contractNo' => 'C-1', 'startDate' => now()->subMonths(11)->toDateString(), 'endDate' => now()->addDays(20)->toDateString(), 'annualCost' => '240.00', 'billing' => 'quarterly', 'renewalNoticeDays' => 30];

        $this->postJson("/api/v1/finance/assets/$asset/contracts", array_merge($base, ['endDate' => now()->subYear()->subDay()->toDateString()]), $this->headers)->assertUnprocessable();
        $list = $this->postJson("/api/v1/finance/assets/$asset/contracts", $base, $this->headers)->assertCreated()->json('data');
        $this->assertCount(1, $list);
        $this->assertTrue($list[0]['renewalDue']);
        $this->assertSame('active', $list[0]['status']);
        $contract = $list[0]['id'];

        $alerts = $this->getJson('/api/v1/finance/assets/reports/alerts?days=60', $this->headers)->assertOk()->json('data');
        $this->assertSame([$contract], array_column($alerts['contracts'], 'contractId'));
        $this->assertFalse($alerts['contracts'][0]['expired']);

        // Renew far into the future: no alert; an ended contract shows as expired.
        $this->patchJson("/api/v1/finance/assets/$asset/contracts/$contract", array_merge($base, ['endDate' => now()->addYear()->toDateString()]), $this->headers)->assertOk()->assertJsonPath('data.0.renewalDue', false);
        $this->assertSame([], $this->getJson('/api/v1/finance/assets/reports/alerts?days=60', $this->headers)->json('data.contracts'));
        $this->patchJson("/api/v1/finance/assets/$asset/contracts/$contract", array_merge($base, ['endDate' => now()->subDays(3)->toDateString()]), $this->headers)->assertOk()->assertJsonPath('data.0.status', 'expired');
        $expired = $this->getJson('/api/v1/finance/assets/reports/alerts?days=60', $this->headers)->json('data.contracts');
        $this->assertTrue($expired[0]['expired']);

        $summary = $this->getJson("/api/v1/finance/assets/$asset/maintenance-summary", $this->headers)->assertOk()->json('data');
        $this->assertCount(1, $summary['contracts']);

        $this->deleteJson("/api/v1/finance/assets/$asset/contracts/$contract", [], $this->headers)->assertOk()->assertJsonCount(0, 'data');
        $this->deleteJson("/api/v1/finance/assets/$asset/contracts/$contract", [], $this->headers)->assertNotFound();
    }
}
