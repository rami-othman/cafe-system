<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\AccountingPostingService;
use App\Services\FinancialAccountBalanceQuery;
use App\Services\FinancialSetupService;
use App\Services\ShiftCashSummaryService;
use App\Services\StockCountService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

final class HistoricalShiftCloseTest extends TestCase
{
    use RefreshDatabase;

    private int $tenant;

    private int $branch;

    private int $drawer;

    private int $safe;

    private int $shift;

    private User $owner;

    private array $headers;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-09-26 07:00:00', 'UTC'));
        $this->tenant = DB::table('tenants')->insertGetId(['name' => 'Historical', 'slug' => 'historical', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $this->branch = DB::table('branches')->insertGetId(['tenant_id' => $this->tenant, 'name' => 'Historical branch', 'timezone' => 'Asia/Damascus', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($this->tenant, $this->branch);
        $this->drawer = DB::table('branches')->where('id', $this->branch)->value('pos_cash_financial_location_id');
        $this->safe = DB::table('financial_locations')->where('tenant_id', $this->tenant)->where('code', 'MAIN-SAFE')->value('id');
        DB::table('branches')->where('id', $this->branch)->update(['shift_close_destination_financial_location_id' => $this->safe, 'shift_closing_float_amount' => '100.00']);
        $this->owner = User::query()->create(['tenant_id' => $this->tenant, 'name' => 'Owner', 'email' => 'historical@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true]);
        $this->headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($this->tenant, $this->owner)];
        $this->postJson('/api/v1/finance/cash-transfers', ['fromFinancialLocationId' => $this->safe, 'toFinancialLocationId' => $this->drawer, 'amount' => '100.00', 'transferDate' => '2026-09-26', 'idempotencyKey' => 'fund-historical'], $this->headers)->assertCreated();
        $this->shift = $this->postJson('/api/v1/shifts/current', ['branchId' => $this->branch, 'openingCash' => '100.00'], $this->headers)->assertCreated()->json('data.id');
    }

    public function test_preview_is_read_only_and_uses_branch_midnight_and_event_time(): void
    {
        $old = $this->sale('400.00');
        $this->travelTo(CarbonImmutable::parse('2026-09-26 21:00:00', 'UTC'));
        $this->sale('80.00');
        DB::table('payments')->where('order_id', $old)->update(['updated_at' => now()]);
        $before = $this->fingerprint();
        $preview = $this->preview();
        $this->assertSame('2026-09-26T21:00:00+00:00', $preview['period']['periodEndExclusive']);
        $this->assertSame('500.00', $preview['period']['expectedCash']);
        $this->assertSame('580.00', $preview['period']['currentLedgerCash']);
        $this->assertSame(1, $preview['period']['laterRecords']['payments']);
        $this->assertSame(1, $preview['snapshot']['sales']['orderCount']);
        $this->assertArrayHasKey('salesSum', $preview['snapshot']['sales']);
        $this->assertArrayHasKey('salesTotal', $preview['snapshot']['sales']);
        $this->assertArrayHasKey('salesNet', $preview['snapshot']['sales']);
        $this->assertTrue($preview['period']['canClose']);
        $this->assertSame($before, $this->fingerprint());
    }

    public function test_historical_close_preserves_cash_and_moves_today_without_reposting(): void
    {
        $old = $this->sale('400.00');
        $this->today();
        $new = $this->sale('80.00');
        $journals = DB::table('journal_entries')->where('tenant_id', $this->tenant)->count();
        $data = $this->closeData();
        $result = $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertOk()->json('data');
        $next = DB::table('shifts')->where('continuation_of_shift_id', $this->shift)->first();
        $this->assertNotNull($next);
        $this->assertSame('open', $next->status);
        $this->assertSame('500.00', $next->opening_cash);
        $this->assertSame($this->shift, (int) DB::table('orders')->where('id', $old)->value('shift_id'));
        $this->assertSame((int) $next->id, (int) DB::table('orders')->where('id', $new)->value('shift_id'));
        $this->assertSame((int) $next->id, (int) DB::table('payments')->where('order_id', $new)->value('shift_id'));
        $this->assertSame('180.00', $this->ledger());
        $this->assertSame('180.00', app(ShiftCashSummaryService::class)->summarize($this->tenant, $next)['expectedCash']);
        $this->assertSame($journals + 1, DB::table('journal_entries')->where('tenant_id', $this->tenant)->count());
        // behaviour changed in T3 (client decision 2026-09-28): the transfer is dated to the closed period.
        $this->assertDatabaseHas('cash_transfers', ['id' => $result['closeTransferId'], 'shift_id' => $next->id, 'amount' => '400.00', 'transfer_date' => '2026-09-26']);
        $this->assertDatabaseHas('shifts', ['id' => $this->shift, 'business_date' => '2026-09-26', 'closed_at' => '2026-09-26 20:59:59', 'closing_cash' => '500.00']);
        $this->assertSame(2, DB::table('shift_period_reassignments')->where('from_shift_id', $this->shift)->count());
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertOk();
        $this->assertSame($journals + 1, DB::table('journal_entries')->where('tenant_id', $this->tenant)->count());
        $this->assertSame(1, DB::table('shifts')->where('continuation_of_shift_id', $this->shift)->count());
    }

    public function test_counting_now_is_converted_to_period_end_cash(): void
    {
        $this->sale('400.00');
        $this->today();
        $this->sale('80.00');
        $data = $this->closeData();
        $data['closingCash'] = '580.00';
        $data['cashCountBasis'] = 'current';
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertOk()->assertJsonPath('data.cash.actual', '500.00');
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertOk();
        $data['closingCash'] = '579.00';
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertUnprocessable();
    }

    public function test_historical_shortage_posts_on_period_date_and_continuation_opens_with_counted_cash(): void
    {
        $this->sale('400.00');
        $this->today();
        $this->sale('80.00');
        $data = $this->closeData();
        $data['closingCash'] = '490.00';
        $data['cashDifferenceReason'] = 'unknown_shortage';
        $result = $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertOk()->json('data');
        $next = DB::table('shifts')->where('continuation_of_shift_id', $this->shift)->first();

        $this->assertSame('490.00', $next->opening_cash);
        $this->assertDatabaseHas('cash_transfers', ['id' => $result['closeTransferId'], 'amount' => '390.00', 'transfer_date' => '2026-09-26']);
        $this->assertDatabaseHas('journal_entries', ['tenant_id' => $this->tenant, 'source_type' => 'shift_cash_variance', 'entry_date' => '2026-09-26']);
        $safeAccount = DB::table('financial_locations')->where('id', $this->safe)->value('financial_account_id');
        $safeBalance = app(FinancialAccountBalanceQuery::class)->summary($this->tenant, $safeAccount, to: '2026-09-26', locationId: $this->safe)['balance'];
        $this->assertSame('290.00', $safeBalance);
    }

    public function test_changed_preview_is_rejected_without_partial_updates(): void
    {
        $this->sale('400.00');
        $this->today();
        $data = $this->closeData();
        $this->sale('80.00');
        $before = $this->fingerprint();
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertUnprocessable()->assertJsonValidationErrors('previewVersion');
        $this->assertSame($before, $this->fingerprint());
    }

    public function test_preview_and_count_basis_are_required_for_historical_close(): void
    {
        $this->today();
        $this->postJson("/api/v1/shifts/{$this->shift}/close", ['closingDate' => '2026-09-26', 'closingCash' => 100], $this->headers)->assertUnprocessable()->assertJsonValidationErrors('closingDate');
        $data = $this->closeData();
        unset($data['cashCountBasis']);
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertUnprocessable()->assertJsonValidationErrors('cashCountBasis');
        $this->assertDatabaseHas('shifts', ['id' => $this->shift, 'status' => 'open']);
    }

    public function test_wrong_count_rolls_back_and_retry_keeps_original_report_fixed(): void
    {
        $order = $this->sale('400.00');
        $this->today();
        $data = $this->closeData();
        $wrong = $data;
        $wrong['closingCash'] = '499.00';
        $before = $this->fingerprint();
        // behaviour changed in T3 (client decision 2026-09-28): a cash difference needs a reason.
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $wrong, $this->headers)->assertUnprocessable()->assertJsonValidationErrors('cashDifferenceReason');
        $this->assertSame($before, $this->fingerprint());
        $result = $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertOk()->json('data');
        DB::table('orders')->where('id', $order)->update(['total' => '999.00']);
        $report = $this->getJson('/api/v1/shifts/'.$result['shiftNumber'].'/report', $this->headers)->assertOk()->json('data');
        $this->assertSame($result['snapshot'], $report['snapshot']);
    }

    public function test_invalid_date_and_foreign_user_cannot_preview(): void
    {
        $this->getJson("/api/v1/shifts/{$this->shift}/close-preview?closingDate=2026-09-25", $this->headers)->assertUnprocessable();
        $this->getJson("/api/v1/shifts/{$this->shift}/close-preview?closingDate=2026-09-28", $this->headers)->assertUnprocessable();
        $other = User::query()->create(['tenant_id' => $this->tenant, 'name' => 'Other owner', 'email' => 'other-history@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true]);
        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($this->tenant, $other)];
        $this->getJson("/api/v1/shifts/{$this->shift}/close-preview?closingDate=2026-09-26", $headers)->assertForbidden();
    }

    public function test_bar_preview_reconstructs_yesterday_and_current_count_posts_once(): void
    {
        [$warehouse, $item] = $this->barFixture();
        $this->today();
        $this->stockOut($warehouse, $item, '3.000');
        $preview = $this->preview();
        $this->assertSame(8, $preview['snapshot']['barCount']['lines'][0]['theoretical']);
        $this->assertSame(5, $preview['snapshot']['barCount']['lines'][0]['currentTheoretical']);
        $data = $this->closeData();
        $data['barCountBasis'] = 'current';
        $data['barCountLines'] = [['inventoryItemId' => $item, 'counted' => '5.000']];
        $result = $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertOk()->json('data');
        $this->assertSame('8.000', $result['snapshot']['barCount']['lines'][0]['counted']);
        $this->assertDatabaseHas('stock_counts', ['shift_id' => $this->shift, 'count_date' => '2026-09-26', 'status' => 'posted', 'count_basis' => 'current']);
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'quantity_on_hand' => '5.000']);
        $before = DB::table('stock_movements')->where('tenant_id', $this->tenant)->count();
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertOk();
        $this->assertSame($before, DB::table('stock_movements')->where('tenant_id', $this->tenant)->count());
    }

    public function test_incomplete_inventory_blocks_historical_close_without_using_today_as_yesterday(): void
    {
        [$warehouse, $item] = $this->barFixture();
        $this->today();
        DB::table('stock_balances')->where('warehouse_id', $warehouse)->where('inventory_item_id', $item)->update(['quantity_on_hand' => '99.000']);
        $preview = $this->preview();
        $this->assertFalse($preview['period']['canClose']);
        $this->assertSame([], $preview['snapshot']['barCount']['lines']);
        $before = $this->fingerprint();
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $this->closeData(), $this->headers)->assertUnprocessable();
        $this->assertSame($before, $this->fingerprint());
    }

    public function test_bar_variance_without_reason_rolls_back_the_new_count(): void
    {
        [$warehouse, $item] = $this->barFixture();
        $this->today();
        $data = $this->closeData();
        $data['barCountLines'] = [['inventoryItemId' => $item, 'counted' => '7.000']];
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertUnprocessable()->assertJsonValidationErrors('reason');
        $this->assertSame(0, DB::table('stock_counts')->where('tenant_id', $this->tenant)->count());
        $this->assertDatabaseHas('shifts', ['id' => $this->shift, 'status' => 'open']);
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'quantity_on_hand' => '8.000']);
        $data['barCountLines'][0]['reason'] = 'Historical recorded shortage';
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertOk();
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'quantity_on_hand' => '7.000']);
        $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $this->tenant)->where('type', 'stock_count_variance')->count());
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertOk();
        $this->assertSame(1, DB::table('stock_movements')->where('tenant_id', $this->tenant)->where('type', 'stock_count_variance')->count());
    }

    public function test_current_day_close_preserves_the_bar_variance_reason(): void
    {
        [$warehouse, $item] = $this->barFixture();
        $data = ['closingCash' => '100.00', 'barCountLines' => [['inventoryItemId' => $item, 'counted' => '7.000']]];
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)
            ->assertUnprocessable()->assertJsonValidationErrors('reason');
        $data['barCountLines'][0]['reason'] = 'Recorded current-day shortage';
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertOk();
        $this->assertDatabaseHas('stock_count_lines', ['inventory_item_id' => $item, 'reason' => 'Recorded current-day shortage']);
        $this->assertDatabaseHas('stock_balances', ['warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'quantity_on_hand' => '7.000']);
    }

    public function test_today_refund_of_yesterdays_sale_belongs_only_to_the_continuation(): void
    {
        $order = $this->sale('400.00');
        $this->today();
        $this->postJson("/api/v1/orders/{$order}/refunds", ['type' => 'partial', 'amount' => 50, 'reason' => 'Today refund', 'idempotencyKey' => 'historical-refund'], $this->headers)->assertCreated();
        $preview = $this->preview();
        $this->assertSame('500.00', $preview['period']['expectedCash']);
        $this->assertSame('450.00', $preview['period']['currentLedgerCash']);
        $this->assertSame('0.00', $preview['snapshot']['sales']['refunds']);
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $this->closeData(), $this->headers)->assertOk();
        $next = DB::table('shifts')->where('continuation_of_shift_id', $this->shift)->first();
        $this->assertDatabaseHas('payment_refunds', ['order_id' => $order, 'shift_id' => $next->id, 'amount' => 50]);
        $this->assertSame('50.00', app(ShiftCashSummaryService::class)->summarize($this->tenant, $next)['expectedCash']);
        $this->assertSame('50.00', $this->ledger());
    }

    public function test_open_order_is_carried_without_being_counted_as_an_old_sale(): void
    {
        $order = DB::table('orders')->insertGetId(['tenant_id' => $this->tenant, 'branch_id' => $this->branch, 'shift_id' => $this->shift, 'order_number' => 'H-OPEN', 'status' => 'draft', 'payment_status' => 'unpaid', 'total' => 0, 'opened_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        $this->today();
        $preview = $this->preview();
        $this->assertSame(0, $preview['snapshot']['orders']['open']);
        $this->assertSame(1, $preview['period']['laterRecords']['orders']);
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $this->closeData(), $this->headers)->assertOk();
        $next = DB::table('shifts')->where('continuation_of_shift_id', $this->shift)->first();
        $this->assertDatabaseHas('orders', ['id' => $order, 'shift_id' => $next->id, 'status' => 'draft']);
        $this->assertDatabaseHas('shifts', ['id' => $next->id, 'opening_cash' => 100, 'status' => 'open']);
    }

    public function test_existing_today_count_moves_to_continuation_and_old_count_is_separate(): void
    {
        [$warehouse, $item] = $this->barFixture();
        $this->today();
        $count = app(StockCountService::class)->startBarCheck(Request::create('/'), $this->tenant, $this->shift, $warehouse, $this->owner->id);
        $data = $this->closeData();
        $data['barCountLines'] = [['inventoryItemId' => $item, 'counted' => '8.000']];
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $data, $this->headers)->assertOk();
        $next = DB::table('shifts')->where('continuation_of_shift_id', $this->shift)->first();
        $this->assertDatabaseHas('stock_counts', ['id' => $count, 'shift_id' => $next->id, 'status' => 'in_progress', 'count_date' => '2026-09-27']);
        $this->assertSame(1, DB::table('stock_counts')->where('shift_id', $this->shift)->where('status', 'posted')->count());
    }

    public function test_voucher_drafted_yesterday_and_posted_today_moves_with_its_single_cash_movement(): void
    {
        $document = DB::table('finance_documents')->insertGetId([
            'tenant_id' => $this->tenant, 'branch_id' => $this->branch, 'shift_id' => $this->shift,
            'financial_location_id' => $this->drawer, 'document_number' => 'H-RV-1',
            'document_type' => 'receipt', 'status' => 'draft', 'document_date' => '2026-09-26',
            'amount' => '30.00', 'created_by' => $this->owner->id, 'created_at' => now(), 'updated_at' => now(),
        ]);
        foreach ([['1010', '30.00', '0.00'], ['4000', '0.00', '30.00']] as $index => [$code, $debit, $credit]) {
            DB::table('finance_document_lines')->insert(['tenant_id' => $this->tenant, 'finance_document_id' => $document,
                'financial_account_id' => DB::table('financial_accounts')->where('tenant_id', $this->tenant)->where('code', $code)->value('id'),
                'line_number' => $index + 1, 'debit' => $debit, 'credit' => $credit, 'created_at' => now(), 'updated_at' => now()]);
        }
        $this->today();
        $this->postJson("/api/v1/finance/vouchers/{$document}/post", [], $this->headers)->assertOk();
        $preview = $this->preview();
        $this->assertSame('100.00', $preview['period']['expectedCash']);
        $this->assertSame('130.00', $preview['period']['currentLedgerCash']);
        $this->assertSame(1, $preview['period']['laterRecords']['finance_documents']);
        $this->assertSame(1, $preview['period']['laterRecords']['shift_cash_movements']);
        $before = DB::table('journal_entries')->where('tenant_id', $this->tenant)->count();
        $this->postJson("/api/v1/shifts/{$this->shift}/close", $this->closeData(), $this->headers)->assertOk();
        $next = DB::table('shifts')->where('continuation_of_shift_id', $this->shift)->first();
        $this->assertDatabaseHas('finance_documents', ['id' => $document, 'shift_id' => $next->id]);
        $this->assertDatabaseHas('shift_cash_movements', ['source_type' => 'finance_document', 'source_id' => $document, 'shift_id' => $next->id, 'amount' => 30]);
        $this->assertSame($before, DB::table('journal_entries')->where('tenant_id', $this->tenant)->count());
        $this->assertSame('130.00', app(ShiftCashSummaryService::class)->summarize($this->tenant, $next)['expectedCash']);
    }

    public function test_today_close_accepts_a_stale_preview(): void
    {
        $this->today();
        $preview = $this->getJson("/api/v1/shifts/{$this->shift}/close-preview?closingDate=2026-09-27", $this->headers)->assertOk()->json('data');
        $this->sale('20.00');
        // behaviour changed in T2 (client decision 2026-09-28): today's close accepts an old preview version.
        $this->postJson("/api/v1/shifts/{$this->shift}/close", ['closingDate' => '2026-09-27', 'closingCash' => 120, 'previewVersion' => $preview['period']['version']], $this->headers)->assertOk();
        $this->assertDatabaseHas('shifts', ['id' => $this->shift, 'status' => 'closed']);
    }

    private function barFixture(): array
    {
        $warehouse = DB::table('warehouses')->insertGetId(['tenant_id' => $this->tenant, 'branch_id' => $this->branch, 'name' => 'Bar', 'code' => 'H-BAR', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $item = DB::table('inventory_items')->insertGetId(['tenant_id' => $this->tenant, 'name' => 'Beans', 'name_en' => 'Beans', 'name_ar' => 'حبوب', 'sku' => 'H-BEANS', 'unit' => 'piece', 'item_type' => 'raw_material', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('inventory_item_warehouses')->insert(['tenant_id' => $this->tenant, 'inventory_item_id' => $item, 'warehouse_id' => $warehouse, 'created_at' => now(), 'updated_at' => now()]);
        $template = DB::table('bar_check_templates')->insertGetId(['tenant_id' => $this->tenant, 'branch_id' => $this->branch, 'warehouse_id' => $warehouse, 'name' => 'Daily bar', 'is_active' => true, 'required_for_shift_close' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('bar_check_template_lines')->insert(['tenant_id' => $this->tenant, 'bar_check_template_id' => $template, 'inventory_item_id' => $item, 'count_unit' => 'piece', 'is_required' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('stock_balances')->insert(['tenant_id' => $this->tenant, 'warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'quantity_on_hand' => '10.000', 'average_unit_cost' => '0.0000', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('stock_movements')->insert(['tenant_id' => $this->tenant, 'branch_id' => $this->branch, 'warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'type' => 'opening_balance', 'quantity' => '10.000', 'quantity_in' => '10.000', 'quantity_out' => '0.000', 'quantity_before' => '0.000', 'quantity_after' => '10.000', 'occurred_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        $this->stockOut($warehouse, $item, '2.000');

        return [$warehouse, $item];
    }

    private function stockOut(int $warehouse, int $item, string $amount): void
    {
        $balance = DB::table('stock_balances')->where('warehouse_id', $warehouse)->where('inventory_item_id', $item)->first();
        $after = (float) $balance->quantity_on_hand - (float) $amount;
        DB::table('stock_movements')->insert(['tenant_id' => $this->tenant, 'branch_id' => $this->branch, 'warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'type' => 'stock_out', 'quantity' => $amount, 'quantity_in' => '0.000', 'quantity_out' => $amount, 'quantity_before' => $balance->quantity_on_hand, 'quantity_after' => $after, 'occurred_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        DB::table('stock_balances')->where('id', $balance->id)->update(['quantity_on_hand' => $after]);
    }

    private function today(): void
    {
        $this->travelTo(CarbonImmutable::parse('2026-09-27 08:00:00', 'UTC'));
    }

    private function preview(): array
    {
        return $this->getJson("/api/v1/shifts/{$this->shift}/close-preview?closingDate=2026-09-26", $this->headers)->assertOk()->json('data');
    }

    private function closeData(): array
    {
        $preview = $this->preview();

        return ['closingDate' => '2026-09-26', 'closingCash' => $preview['period']['expectedCash'], 'cashCountBasis' => 'period_recorded', 'barCountBasis' => 'period_recorded', 'barCountLines' => [], 'previewVersion' => $preview['period']['version']];
    }

    private function sale(string $amount): int
    {
        $order = DB::table('orders')->insertGetId(['tenant_id' => $this->tenant, 'branch_id' => $this->branch, 'shift_id' => $this->shift, 'order_number' => uniqid('H-'), 'type' => 'takeaway', 'status' => 'paid', 'payment_status' => 'paid', 'subtotal' => $amount, 'total' => $amount, 'opened_at' => now(), 'closed_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        DB::table('payments')->insert(['tenant_id' => $this->tenant, 'branch_id' => $this->branch, 'shift_id' => $this->shift, 'order_id' => $order, 'method' => 'cash', 'status' => 'completed', 'amount' => $amount, 'paid_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        app(AccountingPostingService::class)->postSale(Request::create('/'), $this->tenant, ['branchId' => $this->branch, 'sourceId' => $order, 'sourceEvent' => 'POS_ORDER_PAID', 'entryDate' => now()->toDateString(), 'lines' => [['accountCode' => '1010', 'debit' => $amount, 'credit' => '0.00', 'financialLocationId' => $this->drawer], ['accountCode' => '4000', 'debit' => '0.00', 'credit' => $amount]]], $this->owner->id);

        return $order;
    }

    private function ledger(): string
    {
        $account = DB::table('financial_locations')->where('id', $this->drawer)->value('financial_account_id');

        return app(FinancialAccountBalanceQuery::class)->summary($this->tenant, $account, locationId: $this->drawer)['balance'];
    }

    private function fingerprint(): string
    {
        $rows = [];
        foreach (['shifts', 'orders', 'payments', 'cash_transfers', 'journal_entries', 'journal_entry_lines', 'stock_counts', 'shift_period_reassignments'] as $table) {
            $rows[$table] = DB::table($table)->where('tenant_id', $this->tenant)->orderBy('id')->get()->all();
        }

        return json_encode($rows);
    }
}
