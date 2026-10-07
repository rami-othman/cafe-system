<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

class FixedAssetsAndPartnersTest extends TestCase
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
        $this->headers = $this->headers($this->tenant, 'owner', 'assets');
    }

    private function account(string $code, string $name, string $group, string $normal): int
    {
        return (int) DB::table('financial_accounts')->insertGetId(['tenant_id' => $this->tenant, 'code' => $code, 'name_ar' => $name, 'name_en' => $name,
            'account_group' => $group, 'normal_balance' => $normal, 'is_active' => true, 'is_system_protected' => false, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function category(): int
    {
        $asset = $this->account('1610', 'الأجهزة', 'assets', 'debit');
        $acc = $this->account('1611', 'مجمع اهتلاك الأجهزة', 'assets', 'credit');
        $exp = $this->account('6210', 'مصروف اهتلاك الأجهزة', 'expenses', 'debit');
        $this->postJson('/api/v1/finance/assets/categories', ['code' => 'EQ', 'nameAr' => 'أجهزة', 'assetAccountId' => $asset, 'accumulatedAccountId' => $acc,
            'expenseAccountId' => $exp, 'defaultMethod' => 'straight_line', 'defaultLifeMonths' => 12], $this->headers)->assertCreated();

        return (int) DB::table('asset_categories')->where('tenant_id', $this->tenant)->where('code', 'EQ')->value('id');
    }

    private function journal(int $tenant, int $branch, string $date, array $lines): void
    {
        $id = (int) $this->postJson('/api/v1/finance/journal-entries', ['entryDate' => $date, 'branchId' => $branch, 'lines' => array_map(fn ($l) => [
            'accountId' => $this->accountId($tenant, $l[0]), 'debit' => $l[1], 'credit' => $l[2]], $lines)], $this->headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/journal-entries/$id/post", [], $this->headers)->assertOk();
    }

    private function balance(int $accountId, ?int $branch = null): float
    {
        $q = DB::table('journal_entry_lines as l')->join('journal_entries as e', 'e.id', '=', 'l.journal_entry_id')->where('e.status', 'posted')->where('l.financial_account_id', $accountId);
        if ($branch !== null) {
            $q->whereRaw('COALESCE(l.branch_id, e.branch_id) = ?', [$branch]);
        }

        return round((float) $q->sum(DB::raw('l.debit - l.credit')), 2);
    }

    public function test_full_asset_life_cycle(): void
    {
        $this->boot();
        $category = $this->category();
        $cash = $this->accountId($this->tenant, '1010');
        $assetAccount = (int) DB::table('asset_categories')->where('id', $category)->value('asset_account_id');
        $accAccount = (int) DB::table('asset_categories')->where('id', $category)->value('accumulated_account_id');

        $card = $this->postJson('/api/v1/finance/assets', ['nameAr' => 'آلة إسبريسو', 'categoryId' => $category, 'branchId' => $this->branch,
            'acquisitionDate' => '2025-01-01', 'acquisitionCost' => '1200.00', 'fundingAccountId' => $cash, 'activate' => true], $this->headers)
            ->assertCreated()->assertJsonPath('data.status', 'active')->assertJsonPath('data.usefulLifeMonths', 12)->json('data');
        $id = $card['id'];
        $this->assertSame(1200.0, $this->balance($assetAccount, $this->branch));

        // Direct journal reversal is refused: the asset ledger owns this entry.
        $journal = (int) DB::table('fixed_asset_transactions')->where('fixed_asset_id', $id)->value('journal_entry_id');
        $this->postJson("/api/v1/finance/journal-entries/$journal/reverse", [], $this->headers)->assertUnprocessable();

        $preview = $this->postJson('/api/v1/finance/assets/depreciation-runs/preview', ['periodEnd' => '2025-01-31'], $this->headers)->assertOk()->json('data');
        $this->assertSame('101.92', $preview['total']); // 1200 × 31 / 365
        $run = $this->postJson('/api/v1/finance/assets/depreciation-runs', ['periodEnd' => '2025-01-31'], $this->headers)->assertCreated()->json('data');
        $this->assertSame(-101.92, $this->balance($accAccount, $this->branch));
        $this->postJson('/api/v1/finance/assets/depreciation-runs', ['periodEnd' => '2025-01-31'], $this->headers)->assertUnprocessable();

        // Reverse and redo.
        $this->postJson("/api/v1/finance/assets/depreciation-runs/{$run['id']}/reverse", [], $this->headers)->assertOk()->assertJsonPath('data.status', 'reversed');
        $this->assertSame(0.0, $this->balance($accAccount));
        $this->postJson('/api/v1/finance/assets/depreciation-runs', ['periodEnd' => '2025-01-31'], $this->headers)->assertCreated();

        // Addition on 1 July: catches up Feb–June first, then spreads the rest over the remaining life.
        $this->postJson("/api/v1/finance/assets/$id/additions", ['date' => '2025-07-01', 'amount' => '300.00', 'counterAccountId' => $cash], $this->headers)->assertCreated();
        $after = $this->getJson("/api/v1/finance/assets/$id", $this->headers)->assertOk()->json('data');
        $this->assertSame('1500.00', $after['cost']);
        $this->assertSame('2025-06-30', $after['depreciatedUntil']);
        $this->assertSame(595.07, round(1200 * 181 / 365, 2)); // sanity of the day count used below
        $this->assertEqualsWithDelta(595.07, (float) $after['accumulated'], 0.02);

        // Run to year end: fully depreciated.
        $this->postJson('/api/v1/finance/assets/depreciation-runs', ['periodEnd' => '2025-12-31'], $this->headers)->assertCreated();
        $done = $this->getJson("/api/v1/finance/assets/$id", $this->headers)->json('data');
        $this->assertSame('fully_depreciated', $done['status']);
        $this->assertSame('1500.00', $done['accumulated']);
        $this->assertSame('0.00', $done['bookValue']);

        // Transfer to a second branch: each branch stays balanced through جاري الفروع.
        $second = (int) DB::table('branches')->insertGetId(['tenant_id' => $this->tenant, 'name' => 'TierFour', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->postJson("/api/v1/finance/assets/$id/transfers", ['date' => '2026-01-05', 'toBranchId' => $second], $this->headers)->assertCreated()->assertJsonPath('data.branchId', $second);
        $this->assertSame(1500.0, $this->balance($assetAccount, $second));
        $this->assertSame(0.0, $this->balance($assetAccount, $this->branch));
        foreach ([$this->branch, $second] as $b) {
            $trial = $this->getJson("/api/v1/finance/reports/trial-balance?dateFrom=2025-01-01&dateTo=2026-01-31&branchId=$b", $this->headers)->assertOk()->json('data');
            $this->assertTrue($trial['totals']['balanced'], "branch $b");
        }

        // Sell for 100 → gain 100 (book value 0).
        $sold = $this->postJson("/api/v1/finance/assets/$id/disposals", ['date' => '2026-02-01', 'kind' => 'sale', 'proceeds' => '100.00', 'counterAccountId' => $cash], $this->headers)
            ->assertCreated()->json('data');
        $this->assertSame('disposed', $sold['status']);
        $this->assertSame('0.00', $sold['cost']);
        $gain = (int) DB::table('sales_account_mappings')->where('tenant_id', $this->tenant)->where('mapping_key', 'assets.gain')->value('financial_account_id');
        $this->assertSame(-100.0, $this->balance($gain));

        // Undo the sale (latest movement) → back to fully depreciated in TierFour.
        $tx = collect($sold['transactions'])->last();
        $this->postJson("/api/v1/finance/assets/$id/transactions/{$tx['id']}/reverse", [], $this->headers)->assertOk()->assertJsonPath('data.status', 'fully_depreciated');
        $this->assertSame(0.0, $this->balance($gain));

        $register = $this->getJson('/api/v1/finance/assets?branchId='.$second, $this->headers)->assertOk()->json('data');
        $this->assertSame(1, $register['count']);
        $ops = $this->getJson('/api/v1/finance/assets/reports/operations?dateFrom=2025-01-01&dateTo=2026-12-31', $this->headers)->assertOk()->json('data');
        $this->assertNotEmpty($ops['items']);
    }

    public function test_opening_asset_posts_nothing_and_partial_disposal_splits_accumulated(): void
    {
        $this->boot();
        $category = $this->category();
        $journalsBefore = DB::table('journal_entries')->count();
        $card = $this->postJson('/api/v1/finance/assets', ['nameAr' => 'ديكور الخشب', 'categoryId' => $category, 'branchId' => $this->branch, 'acquisitionDate' => '2024-01-01',
            'acquisitionCost' => '1000.00', 'usefulLifeMonths' => 24, 'isOpening' => true, 'openingAccumulated' => '400.00', 'openingDepreciatedUntil' => '2024-08-31', 'activate' => true], $this->headers)
            ->assertCreated()->assertJsonPath('data.bookValue', '600.00')->json('data');
        $this->assertSame($journalsBefore, DB::table('journal_entries')->count());

        $cash = $this->accountId($this->tenant, '1010');
        $loss = $this->postJson("/api/v1/finance/assets/{$card['id']}/disposals", ['date' => '2024-08-31', 'kind' => 'scrap', 'costAmount' => '500.00'], $this->headers)->assertCreated()->json('data');
        $this->assertSame('500.00', $loss['cost']);
        $this->assertSame('200.00', $loss['accumulated']);
        $this->assertSame('active', $loss['status']);
        $this->assertSame('-300.00', collect($loss['transactions'])->last()['gainLoss']);
    }

    public function test_partners_ownership_and_profit_distribution(): void
    {
        $this->boot();
        $partners = $this->postJson('/api/v1/finance/partners', ['name' => 'مستثمر X', 'kind' => 'investor'], $this->headers)->assertCreated()->json('data');
        $company = collect($partners)->firstWhere('kind', 'company');
        $investor = collect($partners)->firstWhere('kind', 'investor');
        $this->assertNotNull($company);

        $this->putJson("/api/v1/finance/partners/branches/{$this->branch}/ownership", ['effectiveFrom' => '2025-01-01', 'shares' => [
            ['partnerId' => $company['id'], 'sharePercent' => 60], ['partnerId' => $investor['id'], 'sharePercent' => 30],
        ]], $this->headers)->assertUnprocessable()->assertJsonValidationErrors('shares');
        $this->putJson("/api/v1/finance/partners/branches/{$this->branch}/ownership", ['effectiveFrom' => '2025-01-01', 'shares' => [
            ['partnerId' => $company['id'], 'sharePercent' => 60], ['partnerId' => $investor['id'], 'sharePercent' => 40],
        ], 'settings' => ['managementFeeType' => 'profit_percent', 'managementFeePercent' => 10]], $this->headers)->assertOk()->assertJsonCount(2, 'data.current');

        $cash = $this->accountId($this->tenant, '1010');
        $this->postJson("/api/v1/finance/partners/{$investor['id']}/transactions", ['type' => 'capital_in', 'date' => '2025-01-02', 'amount' => '5000', 'counterAccountId' => $cash, 'branchId' => $this->branch], $this->headers)->assertCreated();

        // Branch result for March: revenue 1000 − expense 200 = 800.
        $this->journal($this->tenant, $this->branch, '2025-03-10', [['1010', '1000.00', '0.00'], ['4000', '0.00', '1000.00']]);
        $this->journal($this->tenant, $this->branch, '2025-03-11', [['6190', '200.00', '0.00'], ['1010', '0.00', '200.00']]);

        $preview = $this->postJson('/api/v1/finance/partners/distributions/preview', ['branchId' => $this->branch, 'periodFrom' => '2025-03-01', 'periodTo' => '2025-03-31'], $this->headers)->assertOk()->json('data');
        $this->assertSame('800.00', $preview['netProfit']);
        $this->assertSame('80.00', $preview['managementFee']);
        $this->assertSame('720.00', $preview['distributable']);
        $amounts = collect($preview['lines'])->mapWithKeys(fn ($l) => [$l['kind'].'-'.$l['partnerId'] => $l['amount']])->all();
        $this->assertSame('432.00', $amounts['share-'.$company['id']]);
        $this->assertSame('288.00', $amounts['share-'.$investor['id']]);

        $dist = $this->postJson('/api/v1/finance/partners/distributions', ['branchId' => $this->branch, 'periodFrom' => '2025-03-01', 'periodTo' => '2025-03-31'], $this->headers)->assertCreated()->json('data');
        $this->postJson('/api/v1/finance/partners/distributions', ['branchId' => $this->branch, 'periodFrom' => '2025-03-15', 'periodTo' => '2025-04-30'], $this->headers)->assertUnprocessable();
        $this->assertSame(-288.0, $this->balance($investor['currentAccount']['id']));
        $this->assertSame(-512.0, $this->balance($company['currentAccount']['id']));

        $statement = $this->getJson("/api/v1/finance/partners/{$investor['id']}/statement?dateFrom=2025-01-01&dateTo=2025-12-31", $this->headers)->assertOk()->json('data');
        $this->assertSame('5288.00', $statement['closing']['total']);

        // Ownership cannot be back-dated into a distributed period.
        $this->putJson("/api/v1/finance/partners/branches/{$this->branch}/ownership", ['effectiveFrom' => '2025-03-20', 'shares' => [['partnerId' => $company['id'], 'sharePercent' => 100]]], $this->headers)->assertUnprocessable();

        $this->postJson("/api/v1/finance/partners/distributions/{$dist['id']}/reverse", [], $this->headers)->assertOk()->assertJsonPath('data.status', 'reversed');
        $this->assertSame(0.0, $this->balance($investor['currentAccount']['id']));
        $this->getJson('/api/v1/finance/partners/overview?dateFrom=2025-03-01&dateTo=2025-03-31', $this->headers)->assertOk();
    }

    public function test_opening_import_command_dry_run_and_apply(): void
    {
        $this->boot();
        $this->category();
        $file = tempnam(sys_get_temp_dir(), 'assets').'.csv';
        file_put_contents($file, "code,name,category,branch,acquisition_date,start_date,cost,accumulated,depreciated_until,life_months,salvage,method\n"
            ."500,منظومة الطاقة,EQ,Downtown,2026-01-01,2026-01-01,\"412,129.90\",45219.99,2026-08-31,60,0,straight_line\n");
        $this->artisan('assets:import-opening', ['tenant' => $this->tenant, 'file' => $file])->assertSuccessful();
        $this->assertSame(0, DB::table('fixed_assets')->count());
        $this->artisan('assets:import-opening', ['tenant' => $this->tenant, 'file' => $file, '--apply' => true])->assertSuccessful();
        $asset = DB::table('fixed_assets')->first();
        $this->assertSame('active', $asset->status);
        $this->assertSame('2026-08-31', $asset->depreciated_until);
        $this->assertSame('500', $asset->code);
    }

    // ------------------------------------------------------------ batch 2: items, split payments, maintenance, expenses

    private function assetWithItems(int $category, array $payments, string $mode = 'equal'): array
    {
        return $this->postJson('/api/v1/finance/assets', ['nameAr' => 'غرفة تحضير', 'categoryId' => $category, 'branchId' => $this->branch,
            'acquisitionDate' => '2025-01-01', 'acquisitionCost' => '1000.00', 'activate' => true, 'payments' => $payments,
            'componentsMode' => $mode, 'components' => [['name' => 'ثلاجة'], ['name' => 'فرن'], ['name' => 'طاولة']]], $this->headers)
            ->assertCreated()->json('data');
    }

    public function test_items_split_equally_and_acquisition_paid_from_several_accounts(): void
    {
        $this->boot();
        $category = $this->category();
        $cash = $this->accountId($this->tenant, '1010');
        $bank = $this->account('1625', 'بنك الاختبار', 'assets', 'debit');
        $assetAccount = (int) DB::table('asset_categories')->where('id', $category)->value('asset_account_id');

        $cashBefore = $this->balance($cash, $this->branch);
        $card = $this->assetWithItems($category, [['accountId' => $cash, 'amount' => '400.00'], ['accountId' => $bank, 'amount' => '600.00']]);
        $this->assertSame(1000.0, $this->balance($assetAccount, $this->branch));
        $this->assertSame(-400.0, round($this->balance($cash, $this->branch) - $cashBefore, 2));
        $this->assertSame(-600.0, $this->balance($bank, $this->branch));
        $this->assertSame(['333.34', '333.33', '333.33'], array_column($card['components'], 'cost'));
        $this->assertCount(2, $card['transactions'][0]['payments']);

        // Payments that do not add up are refused and nothing is posted.
        $this->postJson("/api/v1/finance/assets/{$card['id']}/additions", ['date' => '2025-02-01', 'amount' => '100.00',
            'payments' => [['accountId' => $cash, 'amount' => '60.00'], ['accountId' => $bank, 'amount' => '30.00']]], $this->headers)->assertUnprocessable();
        $this->assertSame(1000.0, $this->balance($assetAccount, $this->branch));
    }

    public function test_manual_items_must_add_up_to_the_cost(): void
    {
        $this->boot();
        $category = $this->category();
        $cash = $this->accountId($this->tenant, '1010');
        $this->postJson('/api/v1/finance/assets', ['nameAr' => 'مطبخ', 'categoryId' => $category, 'branchId' => $this->branch, 'acquisitionDate' => '2025-01-01',
            'acquisitionCost' => '500.00', 'fundingAccountId' => $cash, 'componentsMode' => 'manual',
            'components' => [['name' => 'أ', 'cost' => '200.00'], ['name' => 'ب', 'cost' => '200.00']]], $this->headers)->assertUnprocessable();
        $card = $this->postJson('/api/v1/finance/assets', ['nameAr' => 'مطبخ', 'categoryId' => $category, 'branchId' => $this->branch, 'acquisitionDate' => '2025-01-01',
            'acquisitionCost' => '500.00', 'fundingAccountId' => $cash, 'componentsMode' => 'manual',
            'components' => [['name' => 'أ', 'cost' => '200.00'], ['name' => 'ب', 'cost' => '300.00']]], $this->headers)->assertCreated()->json('data');
        $this->assertSame(['200.00', '300.00'], array_column($card['components'], 'cost'));
        // Changing the draft's cost without re-splitting the items is refused.
        $this->patchJson("/api/v1/finance/assets/{$card['id']}", ['acquisitionCost' => '600.00'], $this->headers)->assertUnprocessable();
    }

    public function test_addition_whole_manual_and_new_item_then_reverse(): void
    {
        $this->boot();
        $category = $this->category();
        $cash = $this->accountId($this->tenant, '1010');
        $card = $this->assetWithItems($category, [['accountId' => $cash, 'amount' => '1000.00']]);
        $id = $card['id'];
        [$a, $b, $c] = array_column($card['components'], 'id');

        // Whole addition, manual split: 100 / 50 / 0.
        $after = $this->postJson("/api/v1/finance/assets/$id/additions", ['date' => '2025-03-01', 'amount' => '150.00', 'counterAccountId' => $cash, 'scope' => 'asset',
            'distribution' => 'manual', 'allocations' => [['componentId' => $a, 'amount' => '100.00'], ['componentId' => $b, 'amount' => '50.00']]], $this->headers)
            ->assertCreated()->json('data');
        $this->assertSame('1150.00', $after['cost']);
        $this->assertSame(['433.34', '383.33', '333.33'], array_column($after['components'], 'cost'));
        // Manual split that does not match the amount is refused.
        $this->postJson("/api/v1/finance/assets/$id/additions", ['date' => '2025-03-02', 'amount' => '90.00', 'counterAccountId' => $cash,
            'distribution' => 'manual', 'allocations' => [['componentId' => $c, 'amount' => '50.00']]], $this->headers)->assertUnprocessable();

        // A new item.
        $item = $this->postJson("/api/v1/finance/assets/$id/additions", ['date' => '2025-04-01', 'amount' => '200.00', 'counterAccountId' => $cash,
            'scope' => 'new_component', 'componentName' => 'مولد'], $this->headers)->assertCreated()->json('data');
        $this->assertCount(4, $item['components']);
        $this->assertSame('200.00', $item['components'][3]['cost']);
        $this->assertSame('1350.00', $item['cost']);
        $this->assertSame('1350.00', number_format(array_sum(array_map('floatval', array_column($item['components'], 'cost'))), 2, '.', ''));

        // Reversing the last movement removes the item again.
        $this->postJson("/api/v1/finance/assets/$id/transactions/{$item['lastTransactionId']}/reverse", [], $this->headers)->assertOk();
        $back = $this->getJson("/api/v1/finance/assets/$id", $this->headers)->json('data');
        $this->assertCount(3, $back['components']);
        $this->assertSame('1150.00', $back['cost']);

        // Partial disposal is not supported for an asset made of items.
        $this->postJson("/api/v1/finance/assets/$id/disposals", ['date' => '2025-05-01', 'costAmount' => '100.00'], $this->headers)->assertUnprocessable();
    }

    public function test_first_new_item_on_an_asset_without_items_keeps_the_base_cost(): void
    {
        $this->boot();
        $category = $this->category();
        $cash = $this->accountId($this->tenant, '1010');
        $id = $this->postJson('/api/v1/finance/assets', ['nameAr' => 'حاسوب', 'categoryId' => $category, 'branchId' => $this->branch, 'acquisitionDate' => '2025-01-01',
            'acquisitionCost' => '800.00', 'fundingAccountId' => $cash, 'activate' => true], $this->headers)->assertCreated()->json('data.id');
        $card = $this->postJson("/api/v1/finance/assets/$id/additions", ['date' => '2025-02-01', 'amount' => '120.00', 'counterAccountId' => $cash,
            'scope' => 'new_component', 'componentName' => 'شاشة'], $this->headers)->assertCreated()->json('data');
        $this->assertSame(['الأصل الأساسي', 'شاشة'], array_column($card['components'], 'name'));
        $this->assertSame(['800.00', '120.00'], array_column($card['components'], 'cost'));
        $this->postJson("/api/v1/finance/assets/$id/transactions/{$card['lastTransactionId']}/reverse", [], $this->headers)->assertOk();
        $this->assertCount(0, $this->getJson("/api/v1/finance/assets/$id", $this->headers)->json('data.components'));
    }

    public function test_maintenance_extends_life_and_expense_does_not(): void
    {
        $this->boot();
        $category = $this->category();
        $cash = $this->accountId($this->tenant, '1010');
        $bank = $this->account('1625', 'بنك الاختبار', 'assets', 'debit');
        $repairs = $this->account('6310', 'مصروف صيانة', 'expenses', 'debit');
        $assetAccount = (int) DB::table('asset_categories')->where('id', $category)->value('asset_account_id');
        $id = $this->postJson('/api/v1/finance/assets', ['nameAr' => 'مولد', 'categoryId' => $category, 'branchId' => $this->branch, 'acquisitionDate' => '2025-01-01',
            'acquisitionCost' => '1200.00', 'fundingAccountId' => $cash, 'activate' => true], $this->headers)->assertCreated()->json('data.id');

        // Maintenance: capitalised, +6 months of life, paid from two accounts.
        $card = $this->postJson("/api/v1/finance/assets/$id/maintenance", ['date' => '2025-06-01', 'amount' => '200.00', 'lifeExtensionMonths' => 6,
            'payments' => [['accountId' => $cash, 'amount' => '50.00'], ['accountId' => $bank, 'amount' => '150.00']]], $this->headers)->assertCreated()->json('data');
        $this->assertSame('1400.00', $card['cost']);
        $this->assertSame(6, $card['lifeChangeMonths']);
        $this->assertSame(1400.0, $this->balance($assetAccount, $this->branch));
        $this->assertSame('صيانة', $card['transactions'][count($card['transactions']) - 1]['typeLabel']);
        $this->postJson("/api/v1/finance/assets/$id/maintenance", ['date' => '2025-06-02', 'amount' => '10.00', 'counterAccountId' => $cash], $this->headers)->assertUnprocessable(); // life is required

        // Expense (default): goes to P&L, cost and life untouched.
        $exp = $this->postJson("/api/v1/finance/assets/$id/expenses", ['date' => '2025-07-01', 'amount' => '75.00', 'counterAccountId' => $cash, 'expenseAccountId' => $repairs], $this->headers)
            ->assertCreated()->json('data');
        $this->assertSame('1400.00', $exp['cost']);
        $this->assertSame(6, $exp['lifeChangeMonths']);
        $this->assertSame(75.0, $this->balance($repairs, $this->branch));
        $this->assertSame(1400.0, $this->balance($assetAccount, $this->branch));
        $this->assertSame('مصروف', $exp['transactions'][count($exp['transactions']) - 1]['typeLabel']);
        // Expense needs an expense account.
        $this->postJson("/api/v1/finance/assets/$id/expenses", ['date' => '2025-07-02', 'amount' => '5.00', 'counterAccountId' => $cash], $this->headers)->assertUnprocessable();

        // Reversing the expense restores the P&L; module-owned journal can't be reversed directly.
        $journal = (int) DB::table('fixed_asset_transactions')->where('fixed_asset_id', $id)->where('type', 'expense')->value('journal_entry_id');
        $this->postJson("/api/v1/finance/journal-entries/$journal/reverse", [], $this->headers)->assertUnprocessable();
        $this->postJson("/api/v1/finance/assets/$id/transactions/{$exp['lastTransactionId']}/reverse", [], $this->headers)->assertOk();
        $this->assertSame(0.0, $this->balance($repairs));

        // Capitalised expense: cost grows, life does not.
        $cap = $this->postJson("/api/v1/finance/assets/$id/expenses", ['date' => '2025-08-01', 'amount' => '60.00', 'counterAccountId' => $cash, 'capitalize' => true, 'lifeExtensionMonths' => 12], $this->headers)
            ->assertCreated()->json('data');
        $this->assertSame('1460.00', $cap['cost']);
        $this->assertSame(6, $cap['lifeChangeMonths']);
    }

    public function test_alerts_list_expiring_warranties_and_assets_nearing_end_of_life(): void
    {
        $this->boot();
        $category = $this->category();
        $cash = $this->accountId($this->tenant, '1010');
        $today = now()->toDateString();
        $make = fn (string $name, array $extra) => $this->postJson('/api/v1/finance/assets', array_merge(['nameAr' => $name, 'categoryId' => $category, 'branchId' => $this->branch,
            'acquisitionDate' => now()->subMonths(11)->toDateString(), 'acquisitionCost' => '600.00', 'fundingAccountId' => $cash, 'activate' => true], $extra), $this->headers)->assertCreated()->json('data.id');
        $soon = $make('جهاز كفالته تنتهي', ['warrantyEndDate' => now()->addDays(20)->toDateString(), 'usefulLifeMonths' => 120]);
        $make('جهاز كفالته بعيدة', ['warrantyEndDate' => now()->addDays(400)->toDateString(), 'usefulLifeMonths' => 120]);
        $old = $make('جهاز عمره ينتهي', ['usefulLifeMonths' => 12]);

        $alerts = $this->getJson('/api/v1/finance/assets/reports/alerts?days=60', $this->headers)->assertOk()->json('data');
        $this->assertSame([$soon], array_column($alerts['warranty'], 'id'));
        $this->assertFalse($alerts['warranty'][0]['expired']);
        $this->assertSame([$old], array_column($alerts['endOfLife'], 'id'));
        $this->assertSame(2, $alerts['count']);
        $this->assertGreaterThan(0, $alerts['endOfLife'][0]['daysLeft']);
    }

    public function test_declining_balance_depreciation(): void
    {
        $this->boot();
        $category = $this->category();
        $cash = $this->accountId($this->tenant, '1010');
        $make = fn (string $name) => $this->postJson('/api/v1/finance/assets', ['nameAr' => $name, 'categoryId' => $category, 'branchId' => $this->branch, 'acquisitionDate' => '2021-01-01',
            'acquisitionCost' => '1000.00', 'salvageValue' => '100.00', 'usefulLifeMonths' => 60, 'method' => 'declining_balance', 'fundingAccountId' => $cash, 'activate' => true], $this->headers)
            ->assertCreated()->assertJsonPath('data.method', 'declining_balance')->json('data.id');
        $id = $make('آلة متناقصة');

        // Year 1: 1000 × (1 − 0.6) = 400 (double-declining rate 40% for a 5-year life).
        $preview = $this->postJson('/api/v1/finance/assets/depreciation-runs/preview', ['periodEnd' => '2021-12-31'], $this->headers)->assertOk()->json('data');
        $this->assertSame('400.00', $preview['total']);
        $this->postJson('/api/v1/finance/assets/depreciation-runs', ['periodEnd' => '2021-12-31'], $this->headers)->assertCreated();
        // Year 2 works on the new book value: 600 × 0.4 = 240.
        $this->postJson('/api/v1/finance/assets/depreciation-runs', ['periodEnd' => '2022-12-31'], $this->headers)->assertCreated();
        $card = $this->getJson("/api/v1/finance/assets/$id", $this->headers)->assertOk()->json('data');
        $this->assertSame('640.00', $card['accumulated']);

        // The projection declines and ends exactly at salvage.
        $rows = $this->getJson("/api/v1/finance/assets/$id/schedule", $this->headers)->assertOk()->json('data.rows');
        $this->assertGreaterThan((float) $rows[count($rows) - 1]['amount'], (float) $rows[0]['amount']);
        $this->assertSame('100.00', $rows[count($rows) - 1]['bookValue']);

        // Reaching the end of the life takes whatever is left above salvage; never below it.
        $this->postJson('/api/v1/finance/assets/depreciation-runs', ['periodEnd' => '2025-12-31'], $this->headers)->assertCreated();
        $done = $this->getJson("/api/v1/finance/assets/$id", $this->headers)->json('data');
        $this->assertSame('900.00', $done['accumulated']);
        $this->assertSame('fully_depreciated', $done['status']);

        // Slicing into monthly runs gives (almost) the same first-year total as one yearly run.
        $monthly = $make('آلة شهرية');
        foreach (range(1, 12) as $m) {
            $this->postJson('/api/v1/finance/assets/depreciation-runs', ['periodEnd' => now()->setDate(2021, $m, 1)->endOfMonth()->toDateString(), 'assetId' => $monthly], $this->headers)->assertCreated();
        }
        $this->assertEqualsWithDelta(400.0, (float) $this->getJson("/api/v1/finance/assets/$monthly", $this->headers)->json('data.accumulated'), 0.07);
    }

    public function test_head_office_overhead_is_allocated_to_branches_by_revenue_and_reversed(): void
    {
        $this->boot();
        $second = (int) DB::table('branches')->insertGetId(['tenant_id' => $this->tenant, 'name' => 'TierFour', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->journal($this->tenant, $this->branch, '2025-03-10', [['1010', '3000.00', '0.00'], ['4000', '0.00', '3000.00']]);
        $this->journal($this->tenant, $second, '2025-03-12', [['1010', '1000.00', '0.00'], ['4000', '0.00', '1000.00']]);
        // 400 of head-office rent (no branch on the line).
        $id = (int) $this->postJson('/api/v1/finance/journal-entries', ['entryDate' => '2025-03-15', 'branchId' => null, 'lines' => [
            ['accountId' => $this->accountId($this->tenant, '6190'), 'debit' => '400.00', 'credit' => '0.00'],
            ['accountId' => $this->accountId($this->tenant, '1010'), 'debit' => '0.00', 'credit' => '400.00'],
        ]], $this->headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/journal-entries/$id/post", [], $this->headers)->assertOk();
        $expense = $this->accountId($this->tenant, '6190');
        $range = ['periodFrom' => '2025-03-01', 'periodTo' => '2025-03-31'];

        $preview = $this->postJson('/api/v1/finance/partners/overhead/preview', $range, $this->headers)->assertOk()->json('data');
        $this->assertSame('400.00', $preview['total']);
        $byBranch = collect($preview['branches'])->mapWithKeys(fn ($b) => [$b['branchId'] => $b['amount']])->all();
        $this->assertSame('300.00', $byBranch[$this->branch]);
        $this->assertSame('100.00', $byBranch[$second]);

        // Manual percentages must add up to 100.
        $this->postJson('/api/v1/finance/partners/overhead/preview', $range + ['basis' => 'manual', 'percents' => [$this->branch => 50, $second => 40]], $this->headers)->assertUnprocessable();
        $equal = $this->postJson('/api/v1/finance/partners/overhead/preview', $range + ['basis' => 'equal', 'branchIds' => [$this->branch, $second]], $this->headers)->assertOk()->json('data');
        $this->assertSame('200.00', $equal['branches'][0]['amount']);

        $alloc = $this->postJson('/api/v1/finance/partners/overhead', $range, $this->headers)->assertCreated()->json('data');
        $this->assertSame(300.0, $this->balance($expense, $this->branch));
        $this->assertSame(100.0, $this->balance($expense, $second));
        $headOffice = (float) DB::table('journal_entry_lines as l')->join('journal_entries as e', 'e.id', '=', 'l.journal_entry_id')->where('e.status', 'posted')
            ->where('l.financial_account_id', $expense)->whereNull('l.branch_id')->sum(DB::raw('l.debit - l.credit'));
        $this->assertSame(0.0, round($headOffice, 2));

        // Nothing left on the head office: a second run has nothing to move.
        $this->postJson('/api/v1/finance/partners/overhead', $range, $this->headers)->assertUnprocessable();
        // The entry is owned by the module.
        $this->postJson('/api/v1/finance/journal-entries/'.$alloc['journalEntryId'].'/reverse', [], $this->headers)->assertUnprocessable();

        $this->postJson("/api/v1/finance/partners/overhead/{$alloc['id']}/reverse", [], $this->headers)->assertOk()->assertJsonPath('data.status', 'reversed');
        $this->assertSame(0.0, $this->balance($expense, $this->branch));
        $this->assertSame(0.0, $this->balance($expense, $second));
    }

    public function test_physical_count_scan_missing_and_extra(): void
    {
        $this->boot();
        $category = $this->category();
        $cash = $this->accountId($this->tenant, '1010');
        $second = (int) DB::table('branches')->insertGetId(['tenant_id' => $this->tenant, 'name' => 'TierFour', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $make = fn (string $name, int $branch, string $barcode) => $this->postJson('/api/v1/finance/assets', ['nameAr' => $name, 'categoryId' => $category, 'branchId' => $branch,
            'acquisitionDate' => '2025-01-01', 'acquisitionCost' => '500.00', 'usefulLifeMonths' => 24, 'barcode' => $barcode, 'fundingAccountId' => $cash, 'activate' => true], $this->headers)
            ->assertCreated()->json('data');
        $a = $make('آلة 1', $this->branch, 'BC-1');
        $make('آلة 2', $this->branch, 'BC-2');
        $make('آلة فرع آخر', $second, 'BC-3');

        $count = $this->postJson('/api/v1/finance/assets/counts', ['branchId' => $this->branch], $this->headers)->assertCreated()->json('data');
        $this->assertSame(2, $count['summary']['total']);
        $this->assertSame(2, $count['summary']['pending']);

        $this->postJson("/api/v1/finance/assets/counts/{$count['id']}/scan", ['code' => 'BC-1'], $this->headers)->assertOk()->assertJsonPath('data.result', 'found');
        $this->postJson("/api/v1/finance/assets/counts/{$count['id']}/scan", ['code' => 'BC-1'], $this->headers)->assertOk()->assertJsonPath('data.result', 'already');
        $this->postJson("/api/v1/finance/assets/counts/{$count['id']}/scan", ['code' => 'BC-3'], $this->headers)->assertOk()->assertJsonPath('data.result', 'extra');
        $this->postJson("/api/v1/finance/assets/counts/{$count['id']}/scan", ['code' => 'NOPE'], $this->headers)->assertUnprocessable();

        $closed = $this->postJson("/api/v1/finance/assets/counts/{$count['id']}/close", [], $this->headers)->assertOk()->json('data');
        $this->assertSame(1, $closed['summary']['found']);
        $this->assertSame(1, $closed['summary']['missing']);
        $this->assertSame(1, $closed['summary']['extra']);
        $this->postJson("/api/v1/finance/assets/counts/{$count['id']}/scan", ['code' => 'BC-2'], $this->headers)->assertUnprocessable();
        $this->assertNotNull($a['id']);
    }

    public function test_investor_portal_is_read_only_and_limited_to_the_linked_partner(): void
    {
        $this->boot();
        $investorHeaders = $this->headers($this->tenant, 'manager', 'inv');
        $investorUser = (int) DB::table('users')->where('tenant_id', $this->tenant)->where('email', 'inv-manager-'.$this->tenant.'@test.local')->value('id');
        // The investor's role carries only the portal permission.
        DB::table('finance_role_permissions')->where('tenant_id', $this->tenant)->where('role', 'manager')->where('permission', '!=', 'finance.partners.portal')->delete();

        $partners = $this->postJson('/api/v1/finance/partners', ['name' => 'مستثمر X', 'kind' => 'investor', 'userId' => $investorUser], $this->headers)->assertCreated()->json('data');
        $investor = collect($partners)->firstWhere('kind', 'investor');
        $this->assertSame($investorUser, $investor['userId']);
        $this->postJson('/api/v1/finance/partners', ['name' => 'مستثمر Y', 'kind' => 'investor', 'userId' => $investorUser], $this->headers)->assertUnprocessable()->assertJsonValidationErrors('userId');
        $this->getJson('/api/v1/finance/partners/linkable-users', $this->headers)->assertOk();

        $cash = $this->accountId($this->tenant, '1010');
        $this->postJson("/api/v1/finance/partners/{$investor['id']}/transactions", ['type' => 'capital_in', 'date' => '2025-01-02', 'amount' => '5000', 'counterAccountId' => $cash, 'branchId' => $this->branch], $this->headers)->assertCreated();

        // The portal shows only his own account...
        $portal = $this->getJson('/api/v1/finance/partners/portal?dateFrom=2025-01-01&dateTo=2025-12-31', $investorHeaders)->assertOk()->json('data');
        $this->assertCount(1, $portal);
        $this->assertSame('مستثمر X', $portal[0]['partner']['name']);
        $this->assertSame('5000.00', $portal[0]['statement']['closing']['total']);
        // ...and nothing else in the module (no list of partners, no distributions, no writes).
        $this->getJson('/api/v1/finance/partners', $investorHeaders)->assertForbidden();
        $this->getJson('/api/v1/finance/partners/distributions', $investorHeaders)->assertForbidden();
        $this->postJson("/api/v1/finance/partners/{$investor['id']}/transactions", ['type' => 'capital_in', 'date' => '2025-01-03', 'amount' => '1', 'counterAccountId' => $cash], $investorHeaders)->assertForbidden();
        // A user that is not linked to any partner has no portal.
        $this->getJson('/api/v1/finance/partners/portal', $this->headers)->assertNotFound();
    }

    public function test_depreciation_of_a_1000_asset_posts_to_the_depreciation_expense_account(): void
    {
        $this->boot();
        $asset = $this->account('1620', 'أجهزة مكتبية', 'assets', 'debit');
        $accumulated = $this->account('1621', 'مجمع اهتلاك أجهزة مكتبية', 'assets', 'credit');
        // A category with no expense account of its own.
        $this->postJson('/api/v1/finance/assets/categories', ['code' => 'OFF', 'nameAr' => 'أجهزة مكتبية', 'assetAccountId' => $asset, 'accumulatedAccountId' => $accumulated,
            'defaultMethod' => 'straight_line', 'defaultLifeMonths' => 12], $this->headers)->assertCreated();
        $category = (int) DB::table('asset_categories')->where('tenant_id', $this->tenant)->where('code', 'OFF')->value('id');
        $cash = $this->accountId($this->tenant, '1010');
        $id = $this->postJson('/api/v1/finance/assets', ['nameAr' => 'جهاز 1000$', 'categoryId' => $category, 'branchId' => $this->branch, 'acquisitionDate' => '2025-01-01',
            'acquisitionCost' => '1000.00', 'usefulLifeMonths' => 12, 'fundingAccountId' => $cash, 'activate' => true], $this->headers)->assertCreated()->json('data.id');

        $this->postJson('/api/v1/finance/assets/depreciation-runs', ['periodEnd' => '2025-12-31'], $this->headers)->assertCreated();
        $expense = (int) DB::table('financial_accounts')->where('tenant_id', $this->tenant)->where('name_ar', 'مصاريف اهتلاك')->where('account_group', 'expenses')->value('id');
        $this->assertGreaterThan(0, $expense, 'the «مصاريف اهتلاك» expense account exists');
        $this->assertSame(1000.0, $this->balance($expense));
        $this->assertSame('1000.00', $this->getJson("/api/v1/finance/assets/$id", $this->headers)->json('data.accumulated'));
    }
}
