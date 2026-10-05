<?php

namespace Tests\Feature;

use App\Services\FinancialAccountBalanceQuery;
use App\Services\PhinixHistoryConsolidation;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use Tests\TestCase;

final class PhinixHistoryConsolidationTest extends TestCase
{
    use RefreshDatabase;

    private int $tenant;

    private array $accounts = [];

    private int $document;

    private int $sale;

    private int $transfer;

    private int $split;

    protected function setUp(): void
    {
        parent::setUp();
        $this->tenant = DB::table('tenants')->insertGetId(['name' => 'History fixture', 'slug' => 'history-fixture', 'status' => 'active']);
        foreach (['1010', '4000', '6120', '131', '41', '124', '502', '511', '5043'] as $code) {
            $this->accounts[$code] = DB::table('financial_accounts')->insertGetId([
                'tenant_id' => $this->tenant, 'code' => $code, 'name_ar' => $code, 'name_en' => $code,
                'account_group' => in_array($code, ['41', '4000']) ? 'revenue' : 'assets',
                'normal_balance' => in_array($code, ['41', '4000']) ? 'credit' : 'debit',
                'catalog_source' => in_array($code, ['1010', '4000', '6120']) ? null : 'phinix',
            ]);
        }
        $location = DB::table('financial_locations')->insertGetId([
            'tenant_id' => $this->tenant, 'financial_account_id' => $this->accounts['131'],
            'code' => 'CASH', 'name' => 'Cash', 'kind' => 'cash', 'type' => 'cash_drawer',
        ]);
        $this->document = DB::table('finance_documents')->insertGetId([
            'tenant_id' => $this->tenant, 'document_number' => 'PV-1', 'document_type' => 'payment',
            'document_date' => '2026-09-01', 'financial_location_id' => $location, 'amount' => '20.00', 'status' => 'posted',
        ]);
        foreach ([['6120', '20.00', '0.00'], ['1010', '0.00', '20.00']] as $i => [$code, $debit, $credit]) {
            DB::table('finance_document_lines')->insert(['tenant_id' => $this->tenant, 'finance_document_id' => $this->document,
                'financial_account_id' => $this->accounts[$code], 'line_number' => $i + 1, 'debit' => $debit, 'credit' => $credit]);
        }
        $this->sale = $this->journal('pos_order', 1, 'SALE', [['1010', 100, 0], ['4000', 0, 100]]);
        $this->journal('journal_reversal', $this->sale, null, [['1010', 0, 10], ['4000', 10, 0]], $this->sale);
        $expense = $this->journal('finance_document', $this->document, 'FINANCE_DOCUMENT_POSTED', [['6120', 20, 0], ['1010', 0, 20]]);
        DB::table('finance_documents')->where('id', $this->document)->update(['journal_entry_id' => $expense]);
        $this->transfer = $this->journal('legacy_reclassification', $this->tenant, 'LEGACY_TO_PHINIX', [
            ['1010', 0, 70], ['131', 70, 0], ['4000', 90, 0], ['41', 0, 90], ['6120', 0, 20], ['502', 20, 0],
        ]);
        $this->split = $this->journal('legacy_reclassification', $this->tenant, 'SERVICES_EXPENSE_SPLIT', [['502', 0, 20], ['511', 20, 0]]);
    }

    public function test_history_is_preserved_references_follow_it_and_transfers_remain_auditable(): void
    {
        $service = app(PhinixHistoryConsolidation::class);
        $plan = [$this->document => '511'];
        $original = DB::table('journal_entry_lines')->orderBy('id')->get()->map(fn ($r) => (array) $r)->all();
        $preview = $service->run($this->tenant, $plan);
        $this->assertSame($original, DB::table('journal_entry_lines')->orderBy('id')->get()->map(fn ($r) => (array) $r)->all());
        $service->run($this->tenant, $plan, true, $preview['fingerprint'], str_repeat('a', 64));
        $this->assertSame(count($original), DB::table('journal_entry_lines')->count());
        foreach ($original as $line) {
            $actual = (array) DB::table('journal_entry_lines')->find($line['id']);
            if (! in_array($line['journal_entry_id'], [$this->transfer, $this->split])) {
                unset($line['financial_account_id'], $actual['financial_account_id']);
            }
            $this->assertSame($line, $actual);
        }
        $this->assertSame('superseded', DB::table('journal_entries')->where('id', $this->transfer)->value('status'));
        $this->assertSame(5, DB::table('journal_entries')->count());
        $this->assertFalse(DB::table('financial_accounts')->where('id', $this->accounts['4000'])->value('is_active'));
        $this->assertSame($this->accounts['511'], DB::table('finance_document_lines')->where('finance_document_id', $this->document)->where('line_number', 1)->value('financial_account_id'));
        $query = app(FinancialAccountBalanceQuery::class);
        $this->assertSame('90.00', $query->summary($this->tenant, $this->accounts['41'], '2026-09-01', '2026-09-30')['balance']);
        $this->assertCount(2, $query->transactions($this->tenant, $this->accounts['41'], '2026-09-01', '2026-09-30'));
        $audit = DB::table('activity_logs')->where('action', PhinixHistoryConsolidation::ACTION)->first();
        $this->assertNotNull($audit);
        $this->assertNotEmpty(json_decode($audit->before_state, true)['rows']['journal_entry_lines']);
        $this->assertTrue($service->run($this->tenant, $plan, true)['alreadyApplied']);
        $this->assertSame(1, DB::table('activity_logs')->where('action', PhinixHistoryConsolidation::ACTION)->count());
        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($this->tenant)];
        $this->getJson('/api/v1/finance/journal-entries/'.$this->transfer, $headers)->assertOk()
            ->assertJsonPath('data.status', 'superseded')->assertJsonPath('data.allowedActions', [])->assertJsonCount(6, 'data.lines');
        $this->postJson('/api/v1/finance/journal-entries/'.$this->transfer.'/reverse', [], $headers)->assertUnprocessable();
        $this->getJson('/api/v1/finance/transactions?status=superseded', $headers)->assertOk()->assertJsonCount(2, 'data');
    }

    public function test_unreviewed_service_document_aborts_without_changes(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('needs an explicit reviewed account');
        app(PhinixHistoryConsolidation::class)->run($this->tenant, []);
    }

    public function test_wrong_split_is_rejected_even_though_total_debit_equals_credit(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('balances would change');
        app(PhinixHistoryConsolidation::class)->run($this->tenant, [$this->document => '5043']);
    }

    public function test_stale_preview_aborts_before_writing(): void
    {
        $service = app(PhinixHistoryConsolidation::class);
        $plan = [$this->document => '511'];
        $preview = $service->run($this->tenant, $plan);
        DB::table('journal_entries')->where('id', $this->sale)->update(['description' => 'Changed after preview']);
        try {
            $service->run($this->tenant, $plan, true, $preview['fingerprint'], str_repeat('a', 64));
            $this->fail('Stale preview accepted');
        } catch (RuntimeException $error) {
            $this->assertStringContainsString('Source changed', $error->getMessage());
        }
        $this->assertSame('posted', DB::table('journal_entries')->where('id', $this->transfer)->value('status'));
        $this->assertSame($this->accounts['1010'], DB::table('journal_entry_lines')->where('journal_entry_id', $this->sale)->where('line_number', 1)->value('financial_account_id'));
    }

    public function test_business_reference_to_transfer_prevents_superseding_it(): void
    {
        DB::table('finance_documents')->where('id', $this->document)->update(['journal_entry_id' => $this->transfer]);
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Transfer referenced');
        app(PhinixHistoryConsolidation::class)->run($this->tenant, [$this->document => '511']);
    }

    public function test_unexpected_write_rolls_back_every_change(): void
    {
        $service = app(PhinixHistoryConsolidation::class);
        $plan = [$this->document => '511'];
        $preview = $service->run($this->tenant, $plan);
        $before = DB::table('journal_entry_lines')->orderBy('id')->get();
        DB::unprepared("CREATE FUNCTION pg_temp.history_test_trigger() RETURNS trigger LANGUAGE plpgsql AS 'BEGIN NEW.description := ''unexpected trigger mutation''; RETURN NEW; END';
            CREATE TRIGGER history_test_trigger BEFORE UPDATE ON journal_entry_lines FOR EACH ROW EXECUTE FUNCTION pg_temp.history_test_trigger()");
        try {
            $service->run($this->tenant, $plan, true, $preview['fingerprint'], str_repeat('a', 64));
            $this->fail('Unexpected mutation was accepted');
        } catch (RuntimeException $error) {
            $this->assertStringContainsString('Unexpected data change', $error->getMessage());
        }
        $this->assertEquals($before, DB::table('journal_entry_lines')->orderBy('id')->get());
        $this->assertSame('posted', DB::table('journal_entries')->where('id', $this->transfer)->value('status'));
        $this->assertTrue(DB::table('financial_accounts')->where('id', $this->accounts['4000'])->value('is_active'));
        $this->assertFalse(DB::table('activity_logs')->where('action', PhinixHistoryConsolidation::ACTION)->exists());
    }

    private function journal(string $source, int $sourceId, ?string $event, array $lines, ?int $reversal = null): int
    {
        $id = DB::table('journal_entries')->insertGetId(['tenant_id' => $this->tenant, 'entry_number' => 'JE-'.DB::table('journal_entries')->count(),
            'entry_date' => $source === 'legacy_reclassification' ? '2026-10-03' : '2026-09-01', 'source_type' => $source,
            'source_id' => $sourceId, 'source_event' => $event, 'status' => 'posted', 'reversal_of_id' => $reversal]);
        foreach ($lines as $i => [$code, $debit, $credit]) {
            DB::table('journal_entry_lines')->insert(['tenant_id' => $this->tenant, 'journal_entry_id' => $id,
                'financial_account_id' => $this->accounts[$code], 'line_number' => $i + 1, 'debit' => $debit, 'credit' => $credit]);
        }

        return $id;
    }
}
