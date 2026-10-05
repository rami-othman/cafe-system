<?php

// Explicit local maintenance. Original dates, amounts and historical provenance are retained.
require getcwd().'/vendor/autoload.php';
$app = require getcwd().'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use App\Services\CashDrawerConsolidationService;
use App\Services\FinancialAccountBalanceQuery;
use App\Services\OperationalAuditService;
use App\Services\ShiftDrawerReadinessService;
use Illuminate\Support\Facades\DB;

$options = getopt('', ['backup:', 'expect:', 'apply', 'rehearse']);
$apply = array_key_exists('apply', $options);
$rehearse = array_key_exists('rehearse', $options);
$backup = $options['backup'] ?? '';

function ensureLocalDrawer(bool $condition, string $message): void
{
    if (! $condition) throw new RuntimeException($message);
}

function accountNet(int $account, ?int $location = null): string
{
    return app(FinancialAccountBalanceQuery::class)->summary(1, $account, locationId: $location)['balance'];
}

try {
    ensureLocalDrawer(app()->environment('local') && DB::connection()->getDatabaseName() === 'cafe_system_618'
        && in_array(config('database.connections.pgsql.host'), ['postgres', '127.0.0.1', 'localhost'], true), 'Only the local operational database is allowed.');
    ensureLocalDrawer($backup && ! ($apply && $rehearse), 'Backup path or mode missing.');
    $service = app(CashDrawerConsolidationService::class);
    if (DB::table('activity_logs')->where('tenant_id', 1)->where('action', 'finance.cash_drawer_consolidated')->where('entity_id', 12)->exists()) {
        $drawer = DB::table('financial_locations')->find(12);
        ensureLocalDrawer((int) $drawer->branch_id === 5 && $drawer->type === 'cash_drawer'
            && (int) $drawer->financial_account_id === 4869
            && (int) DB::table('branches')->where('id', 5)->value('pos_cash_financial_location_id') === 12,
            'Previously consolidated drawer mapping changed.');
        echo json_encode(['alreadyApplied' => true, 'drawerBalance' => accountNet(4869, 12), 'account139Balance' => accountNet(4869)], JSON_PRETTY_PRINT).PHP_EOL;
        exit;
    }
    DB::beginTransaction();
    DB::statement("SET LOCAL lock_timeout = '5s'");
    DB::statement('LOCK TABLE financial_locations, branches, journal_entries, journal_entry_lines IN SHARE ROW EXCLUSIVE MODE');
    $target = DB::table('financial_locations')->where('tenant_id', 1)->where('id', 12)->first();
    ensureLocalDrawer($target && $target->branch_id === null && $target->type === 'main_safe'
        && $target->is_active && (int) $target->financial_account_id === 4869, 'The unused 139 location changed.');
    foreach (['131' => 4861, '132' => 4862, '139' => 4869] as $code => $id) {
        ensureLocalDrawer(DB::table('financial_accounts')->where('tenant_id', 1)->where('id', $id)->where('code', (string) $code)->where('is_active', true)->exists(), 'Expected chart mapping changed.');
    }
    foreach (DB::select("SELECT table_name,column_name FROM information_schema.columns WHERE table_schema='public' AND column_name LIKE '%financial_location_id'") as $reference) {
        ensureLocalDrawer(! DB::table($reference->table_name)->where($reference->column_name, 12)->exists(), 'Target 139 location already has a reference.');
    }
    ensureLocalDrawer(! DB::table('shifts')->where('tenant_id', 1)->whereIn('financial_location_id', [1,4,12])->where('status', 'open')->whereNull('deleted_at')->exists(), 'A cash shift opened meanwhile.');
    ensureLocalDrawer(! DB::table('journal_entry_lines as l')->join('journal_entries as e', 'e.id', '=', 'l.journal_entry_id')
        ->where('l.tenant_id', 1)->where('l.financial_account_id', 4861)->whereNotNull('e.branch_id')->where('e.branch_id', '<>', 5)->exists(), 'Source contains another branch history.');
    ensureLocalDrawer(accountNet(4861) === '-2758.00' && accountNet(4861, 4) === '0.00'
        && accountNet(4869) === '0.00' && accountNet(4862, 2) === '30069.00', 'Expected post-voucher balances changed.');
    $beforeLines = DB::table('journal_entry_lines')->orderBy('id')->get()->keyBy('id');
    $beforeHeaders = DB::table('journal_entries')->orderBy('id')->get();
    $factory = DB::table('financial_locations')->find(5);
    $factoryBranch = DB::table('branches')->find(6);
    $voucher = DB::table('finance_documents')->find(22);
    $targetPatch = ['branch_id' => 5, 'type' => 'cash_drawer'];
    DB::table('financial_locations')->where('id', 12)->update($targetPatch);
    $dry = $service->run(1, 5, 4861, 4869, [4], 12, historicalLocations: [1], includePlan: true);
    $plan = ['database' => 'cafe_system_618', 'targetBefore' => $target, 'targetPatch' => $targetPatch, 'consolidation' => $dry,
        'balancesBefore' => ['account131' => '-2758.00', 'account139' => '0.00', 'drawer' => '0.00', 'mainSafe' => '30069.00'],
        'policy' => 'Move every 131 account reference to 139; retain historical location 1 and NULL provenance; move only physical branch drawer 4 to 12.'];
    $encoded = json_encode($plan, JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR);
    $hash = hash('sha256', $encoded);
    if (! $apply && ! $rehearse) {
        if (is_file($backup)) ensureLocalDrawer(hash_file('sha256', $backup) === $hash, 'Existing limited backup differs.');
        else {
            ensureLocalDrawer(is_dir(dirname($backup)), 'Backup directory missing.');
            ensureLocalDrawer(file_put_contents($backup, $encoded, LOCK_EX) !== false, 'Cannot save affected-row backup.');
            chmod($backup, 0600);
        }
        DB::rollBack();
        unset($dry['beforeState'], $dry['patches']);
        echo json_encode(['dryRun' => true, 'fingerprint' => $hash, 'backup' => $backup, 'report' => $dry, 'targetPatch' => $targetPatch,
            'expectedLiveDrawerBalance' => '0.00', 'expectedAccount139HistoricalNet' => '-2758.00'], JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE).PHP_EOL;
        exit;
    }
    ensureLocalDrawer(($options['expect'] ?? '') === $hash && is_file($backup) && hash_file('sha256', $backup) === $hash, 'Plan or limited backup fingerprint mismatch.');
    $applied = $service->run(1, 5, 4861, 4869, [4], 12, true, $dry['fingerprint'], $hash, [1]);
    $afterLines = DB::table('journal_entry_lines')->orderBy('id')->get()->keyBy('id');
    ensureLocalDrawer($beforeLines->count() === $afterLines->count(), 'Journal line count changed.');
    foreach ($beforeLines as $id => $line) {
        $expected = (array) $line;
        foreach ($dry['patches']['journal_entry_lines'][$id] ?? [] as $column => $value) $expected[$column] = $value;
        ensureLocalDrawer((array) $afterLines[$id] === $expected, 'Unexpected journal line mutation.');
    }
    ensureLocalDrawer(json_encode($beforeHeaders) === json_encode(DB::table('journal_entries')->orderBy('id')->get()), 'Journal metadata changed.');
    ensureLocalDrawer(json_encode($factory) === json_encode(DB::table('financial_locations')->find(5))
        && json_encode($factoryBranch) === json_encode(DB::table('branches')->find(6)), 'Factory changed.');
    ensureLocalDrawer(json_encode($voucher) === json_encode(DB::table('finance_documents')->find(22)), 'Corrected 350 voucher changed.');
    ensureLocalDrawer(accountNet(4861) === '0.00' && accountNet(4869) === '-2758.00'
        && accountNet(4869, 12) === '0.00' && accountNet(4862, 2) === '30069.00', 'Unexpected post-consolidation balances.');
    $readiness = app(ShiftDrawerReadinessService::class)->payload(1, 5);
    ensureLocalDrawer($readiness['canOpenShift'] && (int) $readiness['drawer']['id'] === 12, 'Local branch is not ready to open.');
    app(OperationalAuditService::class)->recordContext(1, 'finance.tierfour_local_drawer_ready', 'financial_location', 12,
        ['targetPatch' => $targetPatch, 'limitedBackupSha256' => $hash, 'policy' => $plan['policy']], branchId: 5, before: ['target' => (array) $target]);
    if ($rehearse) DB::rollBack();
    else DB::commit();
    echo json_encode(['applied' => $apply, 'rehearsedAndRolledBack' => $rehearse, 'fingerprint' => $hash, 'report' => $applied,
        'canOpenShift' => true, 'drawerId' => 12, 'drawerBalance' => '0.00', 'account139HistoricalNet' => '-2758.00', 'mainSafeBalance' => '30069.00',
        'journalHistoryPreserved' => true, 'factoryPreserved' => true, 'voucher350Preserved' => true], JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE).PHP_EOL;
} catch (Throwable $error) {
    if (DB::transactionLevel() > 0) DB::rollBack();
    fwrite(STDERR, $error->getMessage().PHP_EOL);
    exit(1);
}
