<?php

// One-voucher maintenance, never an automatic migration. Posted amounts,
// dates and document numbers remain unchanged; full affected rows are audited.
require getcwd().'/vendor/autoload.php';
$app = require getcwd().'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use Illuminate\Support\Facades\DB;

$options = getopt('', ['database:', 'backup:', 'expect:', 'apply', 'rehearse']);
$database = $options['database'] ?? '';
$backup = $options['backup'] ?? '';
$apply = array_key_exists('apply', $options);
$rehearse = array_key_exists('rehearse', $options);
$action = 'finance.voucher22_cash_source_corrected';
if (! in_array($database, ['cafe_system_618', 'cafe618_production'], true)
    || DB::connection()->getDatabaseName() !== $database || ! $backup || ($apply && $rehearse)) {
    throw new RuntimeException('Invalid database, backup path, or mode.');
}

function requireCondition(bool $condition, string $message): void
{
    if (! $condition) throw new RuntimeException($message);
}

function balances(): array
{
    return DB::select("SELECT a.id,a.code,COALESCE(SUM(CASE WHEN e.status='posted' THEN l.debit-l.credit ELSE 0 END),0)::text AS balance
        FROM financial_accounts a LEFT JOIN journal_entry_lines l ON l.financial_account_id=a.id
        LEFT JOIN journal_entries e ON e.id=l.journal_entry_id
        WHERE a.tenant_id=1 AND a.code IN ('1010','1020','131','132') GROUP BY a.id,a.code ORDER BY a.id");
}

function locationBalances(): array
{
    return DB::select("SELECT f.id,COALESCE(SUM(CASE WHEN e.status='posted' THEN l.debit-l.credit ELSE 0 END),0)::text AS balance
        FROM financial_locations f LEFT JOIN journal_entry_lines l ON l.financial_location_id=f.id AND l.financial_account_id=f.financial_account_id
        LEFT JOIN journal_entries e ON e.id=l.journal_entry_id
        WHERE f.id IN (2,4) GROUP BY f.id ORDER BY f.id");
}

function totals(): object
{
    return DB::selectOne("SELECT (SELECT COUNT(*) FROM finance_documents) AS documents,
        (SELECT COUNT(*) FROM finance_document_lines) AS document_lines,
        (SELECT COUNT(*) FROM journal_entries) AS entries,COUNT(*) AS lines,
        SUM(debit)::text AS debit,SUM(credit)::text AS credit FROM journal_entry_lines");
}

if ($log = DB::table('activity_logs')->where('tenant_id', 1)->where('action', $action)->where('entity_id', 22)->first()) {
    $saved = json_decode($log->after_state, true, flags: JSON_THROW_ON_ERROR);
    requireCondition((int) DB::table('finance_documents')->where('id', 22)->value('financial_location_id') === 2, 'Previously corrected voucher changed again.');
    foreach ($saved['patches'] as $patch) {
        $row = (array) DB::table($patch['table'])->where('id', $patch['id'])->first();
        foreach ($patch['after'] as $key => $value) {
            requireCondition((string) ($row[$key] ?? '') === (string) $value, 'Previously corrected line changed again.');
        }
    }
    echo json_encode(['database' => $database, 'alreadyApplied' => true, 'balances' => locationBalances()], JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE).PHP_EOL;
    exit;
}

DB::beginTransaction();
try {
    DB::statement($apply || $rehearse ? 'SET TRANSACTION ISOLATION LEVEL SERIALIZABLE' : 'SET TRANSACTION READ ONLY');
    $lock = static function ($query) use ($apply, $rehearse) {
        return $apply || $rehearse ? $query->lockForUpdate() : $query;
    };
    $locations = $lock(DB::table('financial_locations')->whereIn('id', [2,4])->orderBy('id'))->get()->keyBy('id');
    $document = $lock(DB::table('finance_documents')->where('tenant_id', 1)->where('id', 22))->first();
    requireCondition($document && $document->document_number === 'PV-2026-000021'
        && $document->document_type === 'payment' && $document->status === 'posted'
        && $document->document_date === '2026-08-31' && $document->amount === '350.00'
        && $document->description === 'طريق + توصيل + حساب اجل'
        && (int) $document->financial_location_id === 4 && (int) $document->journal_entry_id === 328
        && $document->shift_id === null && $document->deleted_at === null
        && $document->reversal_journal_entry_id === null, 'Voucher does not match the approved correction.');
    requireCondition(! DB::table('shifts')->where('tenant_id', 1)->whereIn('financial_location_id', [2,4])
        ->where('status', 'open')->whereNull('deleted_at')->exists(), 'A affected cash location now has an open shift.');
    requireCondition(! DB::table('journal_entries')->where('reversal_of_id', 328)->exists(), 'Original entry has a reversal.');
    $accounts = DB::table('financial_accounts')->where('tenant_id', 1)->whereIn('code', ['1010','1020','131','132'])->get()->keyBy('code');
    requireCondition((int) $locations[2]->financial_account_id === (int) $accounts['132']->id
        && (int) $locations[4]->financial_account_id === (int) $accounts['131']->id, 'Physical cash locations changed.');
    $headers = $lock(DB::table('journal_entries')->whereIn('id', [328,329])->orderBy('id'))->get()->keyBy('id');
    requireCondition($headers[328]->status === 'posted' && $headers[328]->source_type === 'finance_document'
        && (int) $headers[328]->source_id === 22, 'Original posting changed.');
    $lines = $lock(DB::table('journal_entry_lines')->where('journal_entry_id', 328)->orderBy('id'))->get()->keyBy('id');
    $documentLines = $lock(DB::table('finance_document_lines')->where('finance_document_id', 22)->orderBy('id'))->get()->keyBy('id');
    requireCondition($lines->count() === 2 && $documentLines->count() === 2 && isset($lines[868], $lines[869], $documentLines[43], $documentLines[44]), 'Unexpected line set.');
    requireCondition($lines[868]->debit === '0.00' && $lines[868]->credit === '350.00'
        && (int) $lines[868]->financial_location_id === 4 && $lines[869]->debit === '350.00'
        && $lines[869]->credit === '0.00' && $documentLines[43]->debit === '0.00'
        && $documentLines[43]->credit === '350.00', 'Original amounts changed.');

    $patches = [];
    $add = static function (string $table, object $row, array $after) use (&$patches) {
        $patches[] = ['table' => $table, 'id' => (int) $row->id,
            'before' => (array) $row, 'after' => $after];
    };
    $add('finance_documents', $document, ['financial_location_id' => 2]);
    $cashAccount = (int) $lines[868]->financial_account_id;
    if ($cashAccount === (int) $accounts['131']->id) {
        requireCondition($headers[329]->status === 'superseded' && $database === 'cafe_system_618', 'Unexpected consolidated-history state.');
        $newOriginalAccount = (int) $accounts['132']->id;
    } else {
        requireCondition($cashAccount === (int) $accounts['1010']->id && $headers[329]->status === 'posted'
            && $database === 'cafe618_production', 'Unexpected legacy-history state.');
        $newOriginalAccount = (int) $accounts['1020']->id;
        $legacy = $lock(DB::table('journal_entry_lines')->where('journal_entry_id', 329)
            ->where('financial_location_id', 4)->orderBy('id'))->get()->keyBy('id');
        requireCondition($legacy->count() === 2 && isset($legacy[874], $legacy[875])
            && (int) $legacy[874]->financial_account_id === (int) $accounts['1010']->id
            && $legacy[874]->debit === '350.00' && $legacy[874]->credit === '0.00'
            && (int) $legacy[875]->financial_account_id === (int) $accounts['131']->id
            && $legacy[875]->debit === '0.00' && $legacy[875]->credit === '350.00', 'Legacy allocation is not the same 350.');
        $add('journal_entry_lines', $legacy[874], ['financial_account_id' => $newOriginalAccount, 'financial_location_id' => 2]);
        $add('journal_entry_lines', $legacy[875], ['financial_account_id' => (int) $accounts['132']->id, 'financial_location_id' => 2]);
    }
    requireCondition((int) $documentLines[43]->financial_account_id === $cashAccount, 'Document cash line differs from its journal.');
    $add('journal_entry_lines', $lines[868], ['financial_account_id' => $newOriginalAccount, 'financial_location_id' => 2]);
    $add('finance_document_lines', $documentLines[43], ['financial_account_id' => $newOriginalAccount]);

    $beforeBalances = balances();
    $beforeLocations = locationBalances();
    $beforeTotals = totals();
    $plan = ['database' => $database, 'voucher' => 'PV-2026-000021', 'amount' => '350.00',
        'patches' => $patches, 'originalHeader' => $headers[328], 'expenseLine' => $lines[869],
        'documentExpenseLine' => $documentLines[44], 'balances' => $beforeBalances,
        'locationBalances' => $beforeLocations, 'totals' => $beforeTotals];
    $encoded = json_encode($plan, JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR);
    $fingerprint = hash('sha256', $encoded);
    if (! $apply && ! $rehearse) {
        if (is_file($backup)) requireCondition(hash_file('sha256', $backup) === $fingerprint, 'Existing limited backup does not match.');
        else {
            requireCondition(is_dir(dirname($backup)), 'Backup directory is missing.');
            requireCondition(file_put_contents($backup, $encoded, LOCK_EX) !== false, 'Limited backup could not be written.');
            chmod($backup, 0600);
        }
        DB::rollBack();
        echo json_encode(['database' => $database, 'dryRun' => true, 'fingerprint' => $fingerprint,
            'backup' => $backup, 'rowsToChange' => count($patches), 'currentBalances' => $beforeLocations,
            'expectedBalances' => ['drawer' => '0.00', 'mainSafe' => '30069.00']], JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE).PHP_EOL;
        exit;
    }
    requireCondition(($options['expect'] ?? '') === $fingerprint && is_file($backup)
        && hash_file('sha256', $backup) === $fingerprint, 'Plan or limited backup fingerprint mismatch.');
    requireCondition($beforeLocations[0]->balance === '30419.00' && $beforeLocations[1]->balance === '-350.00', 'Cash balances changed since the approved scenario.');
    foreach ($patches as $patch) {
        $query = DB::table($patch['table'])->where('id', $patch['id']);
        foreach ($patch['after'] as $key => $_) $query->where($key, $patch['before'][$key]);
        requireCondition($query->update($patch['after']) === 1, 'A planned row could not be corrected.');
    }
    $afterLocations = locationBalances();
    requireCondition($afterLocations[0]->balance === '30069.00' && in_array($afterLocations[1]->balance, ['0', '0.00'], true), 'Unexpected cash-location outcome: '.json_encode($afterLocations));
    requireCondition(json_encode(totals()) === json_encode($beforeTotals), 'Counts or total debits/credits changed.');
    requireCondition(json_encode(DB::table('journal_entries')->where('id', 328)->first()) === json_encode($headers[328]), 'Original entry metadata changed.');
    requireCondition(json_encode(DB::table('journal_entry_lines')->where('id', 869)->first()) === json_encode($lines[869]), 'Expense classification changed.');
    $afterBalances = balances();
    foreach ($beforeBalances as $index => $before) {
        $delta = $before->code === '131' ? 35000 : ($before->code === '132' ? -35000 : 0);
        requireCondition((int) round((float) $afterBalances[$index]->balance * 100)
            === (int) round((float) $before->balance * 100) + $delta, 'Unexpected account balance change.');
    }
    $result = ['database' => $database, 'fingerprint' => $fingerprint, 'patches' => $patches,
        'limitedBackupSha256' => $fingerprint, 'beforeBalances' => $beforeLocations, 'afterBalances' => $afterLocations,
        'reason' => 'User-authorized correction of voucher PV-2026-000021 cash source from branch drawer to main safe.'];
    if ($rehearse) DB::rollBack();
    else {
        $now = now();
        DB::table('activity_logs')->insert(['tenant_id' => 1, 'branch_id' => $document->branch_id, 'user_id' => null,
            'action' => $action, 'entity_type' => 'finance_document', 'entity_id' => 22,
            'description' => 'تصحيح مصدر سند دفع 350 إلى الصندوق الرئيسي بطلب المستخدم عبر Codex',
            'ip_address' => null, 'before_state' => $encoded, 'after_state' => json_encode($result, JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR),
            'created_at' => $now, 'updated_at' => $now]);
        DB::commit();
    }
    echo json_encode(['database' => $database, 'applied' => $apply, 'rehearsedAndRolledBack' => $rehearse,
        'rowsChanged' => count($patches), 'fingerprint' => $fingerprint, 'afterBalances' => $afterLocations,
        'totalsPreserved' => true], JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE).PHP_EOL;
} catch (Throwable $error) {
    if (DB::transactionLevel() > 0) DB::rollBack();
    throw $error;
}
