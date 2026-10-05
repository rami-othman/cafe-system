<?php

// Real local data/API verification. Every experiment is enclosed in a rollback-only transaction.
require getcwd().'/vendor/autoload.php';
$app = require getcwd().'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use App\Services\CashDrawerConsolidationService;
use App\Services\FinancialAccountBalanceQuery;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

function lifecycleCheck(bool $condition, string $message): void
{
    if (! $condition) throw new RuntimeException($message);
}

function dataFingerprints(): array
{
    $result = [];
    foreach (DB::select("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename") as $table) {
        $name = DB::connection()->getQueryGrammar()->wrapTable($table->tablename);
        $result[$table->tablename] = DB::selectOne("SELECT md5(COALESCE(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,'[]')) AS fingerprint FROM {$name} t")->fingerprint;
    }
    return $result;
}

try {
    lifecycleCheck(app()->environment('local') && DB::connection()->getDatabaseName() === 'cafe_system_618', 'Only local operational verification is allowed.');
    $before = dataFingerprints();
    DB::beginTransaction();
    DB::statement("SET LOCAL lock_timeout = '5s'");
    if (! DB::table('activity_logs')->where('tenant_id', 1)->where('action', 'finance.cash_drawer_consolidated')->where('entity_id', 12)->exists()) {
        $backupPath = getcwd().'/storage/app/private/local-tierfour-139-before-20261005.json';
        lifecycleCheck(is_file($backupPath), 'Reviewed limited backup missing.');
        $saved = json_decode(file_get_contents($backupPath), true, flags: JSON_THROW_ON_ERROR);
        lifecycleCheck((array) DB::table('financial_locations')->find(12) === $saved['targetBefore'], 'Target metadata differs from limited backup.');
        DB::table('financial_locations')->where('id', 12)->update($saved['targetPatch']);
        $service = app(CashDrawerConsolidationService::class);
        $dry = $service->run(1, 5, 4861, 4869, [4], 12, historicalLocations: [1]);
        lifecycleCheck($dry['fingerprint'] === $saved['consolidation']['fingerprint'], 'Fresh consolidation differs from limited backup.');
        $service->run(1, 5, 4861, 4869, [4], 12, true, $dry['fingerprint'], hash_file('sha256', $backupPath), [1]);
    }
    // Prove a zero close works even when configured to retain a 500 float.
    DB::table('branches')->where('id', 5)->update(['shift_closing_float_amount' => '500.00']);
    $operator = DB::table('users')->where('tenant_id', 1)->where('id', 5)->where('is_active', true)->whereNull('deleted_at')->first();
    lifecycleCheck($operator && in_array($operator->role, ['employee', 'cashier'], true), 'Expected local cashier unavailable.');
    $token = bin2hex(random_bytes(32));
    DB::table('api_tokens')->insert(['tenant_id' => 1, 'user_id' => 5, 'name' => 'local-lifecycle-rollback', 'token_hash' => hash('sha256', $token),
        'expires_at' => now()->addMinutes(10), 'created_at' => now(), 'updated_at' => now()]);
    $kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);
    $call = static function (string $method, string $url, array $body = [], int $expectedStatus = 200, ?string $bearer = null) use ($kernel, $token): array {
        $request = Request::create($url, $method, [], [], [], ['HTTP_ACCEPT' => 'application/json', 'CONTENT_TYPE' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.($bearer ?? $token)], json_encode($body));
        $response = $kernel->handle($request);
        $payload = json_decode($response->getContent(), true, flags: JSON_THROW_ON_ERROR);
        lifecycleCheck($response->getStatusCode() === $expectedStatus, $url.' returned '.$response->getStatusCode().': '.json_encode($payload, JSON_UNESCAPED_UNICODE));
        return $payload;
    };
    $balance = static fn (int $account, int $location): string => app(FinancialAccountBalanceQuery::class)->summary(1, $account, locationId: $location)['balance'];
    $ready = $call('GET', '/api/v1/shifts/readiness?branchId=5')['data'];
    lifecycleCheck($ready['canOpenShift'] && (int) $ready['drawer']['id'] === 12 && $balance(4869, 12) === '0.00', 'Drawer not ready at zero.');
    lifecycleCheck($call('POST', '/api/v1/finance/vouchers', ['branchId' => 5], 422)['code'] === 'NO_OPEN_SHIFT', 'Voucher was not blocked before opening.');
    lifecycleCheck($call('POST', '/api/v1/orders', ['branchId' => 5], 422)['code'] === 'NO_OPEN_SHIFT', 'Order was not blocked before opening.');
    $opened = $call('POST', '/api/v1/shifts/current', ['branchId' => 5, 'openingCash' => '0.00'], 201)['data'];
    $shift = (int) $opened['id'];
    lifecycleCheck((int) $opened['financialLocationId'] === 12, 'Opened on a different drawer.');
    $state = $call('GET', '/api/v1/pos/state?branchId=5')['data'];
    lifecycleCheck($state['terminal']['status'] === 'open' && (int) $state['currentShift']['id'] === $shift, 'POS still considers shift closed.');
    $version = DB::table('published_menu_versions')->where('tenant_id', 1)->where('branch_id', 5)->where('channel', 'pos')->where('status', 'current')->orderByDesc('id')->first();
    lifecycleCheck((bool) $version, 'Published local menu unavailable.');
    $menu = json_decode($version->payload_json, true, flags: JSON_THROW_ON_ERROR);
    $product = $menu['menus'][0]['sections'][0]['products'][0];
    $options = [];
    foreach ($product['modifierGroups'] ?? [] as $group) {
        if (($group['isRequired'] ?? false) || ($group['minSelections'] ?? 0) > 0) {
            $available = array_values(array_filter($group['options'], fn ($option) => $option['isAvailable'] ?? true));
            foreach (array_slice($available, 0, max(1, $group['minSelections'] ?? 1)) as $option) $options[] = $option['id'];
        }
    }
    $order = $call('POST', '/api/v1/orders', ['branchId' => 5, 'shiftId' => $shift, 'orderType' => 'takeaway', 'publishedMenuVersionId' => $version->id,
        'items' => [['productId' => $product['productId'], 'placementId' => $product['placementId'], 'variantId' => $product['variants'][0]['id'], 'modifierOptionIds' => $options, 'quantity' => 1]]], 201)['data'];
    $id = (int) $order['id'];
    $call('POST', "/api/v1/orders/{$id}/pay", ['method' => 'cash', 'amount' => $order['totals']['total'], 'idempotencyKey' => 'local-lifecycle-cash-'.bin2hex(random_bytes(8))]);
    lifecycleCheck(DB::table('journal_entries as e')->join('journal_entry_lines as l', 'l.journal_entry_id', '=', 'e.id')
        ->where('e.source_type', 'pos_order')->where('e.source_id', $id)->where('l.financial_account_id', 4869)->where('l.financial_location_id', 12)->where('l.debit', '>', 0)->count() === 1, 'Cash sale did not post to 139 drawer.');
    $call('POST', "/api/v1/orders/{$id}/refunds", ['type' => 'full', 'reason' => 'Rollback-only local verification', 'idempotencyKey' => 'local-lifecycle-refund-'.bin2hex(random_bytes(8))], 201);
    lifecycleCheck($balance(4869, 12) === '0.00', 'Refund did not return drawer to zero.');
    $preview = $call('GET', "/api/v1/shifts/{$shift}/close-preview")['data'];
    lifecycleCheck($preview['period']['canClose'] && (float) $preview['period']['transferAmount'] === 0.0, 'Zero close preview blocked.');
    $counts = array_map(fn ($line) => ['inventoryItemId' => (int) $line['id'], 'counted' => max(0, (float) $line['theoretical']), 'reason' => 'Rollback-only verification'], $preview['snapshot']['barCount']['lines']);
    $closed = $call('POST', "/api/v1/shifts/{$shift}/close", ['closingCash' => '0.00', 'barCountLines' => $counts])['data'];
    lifecycleCheck($closed['status'] === 'closed' && $closed['closeTransferId'] === null && $balance(4869, 12) === '0.00', 'Zero close failed or created a transfer.');
    lifecycleCheck($call('POST', '/api/v1/orders', ['branchId' => 5, 'shiftId' => $shift], 422)['code'] === 'NO_OPEN_SHIFT', 'Closed shift still permits orders.');
    $beforeTransfers = DB::table('cash_transfers')->count();
    $funded = $call('POST', '/api/v1/shifts/current', ['branchId' => 5, 'openingCash' => '500.00', 'fundOpeningCash' => true], 201)['data'];
    lifecycleCheck((int) $funded['financialLocationId'] === 12 && $balance(4869, 12) === '500.00'
        && $balance(4862, 2) === '29569.00' && DB::table('cash_transfers')->count() === $beforeTransfers + 1, 'Funded opening was not one 500 transfer.');
    $call('POST', '/api/v1/shifts/current', ['branchId' => 5, 'openingCash' => '500.00', 'fundOpeningCash' => true], 422);
    lifecycleCheck(DB::table('cash_transfers')->count() === $beforeTransfers + 1, 'Opening retry duplicated cash funding.');
    $ownerId = DB::table('users')->where('tenant_id', 1)->where('role', 'owner')->where('is_active', true)->whereNull('deleted_at')->orderBy('id')->value('id');
    lifecycleCheck((bool) $ownerId, 'Local owner unavailable for cash-screen read verification.');
    $ownerToken = bin2hex(random_bytes(32));
    DB::table('api_tokens')->insert(['tenant_id' => 1, 'user_id' => $ownerId, 'name' => 'local-cash-screen-rollback', 'token_hash' => hash('sha256', $ownerToken),
        'expires_at' => now()->addMinutes(10), 'created_at' => now(), 'updated_at' => now()]);
    $cashAccounts = $call('GET', '/api/v1/finance/cash-accounts', [], 200, $ownerToken)['data'];
    $live = array_values(array_filter($cashAccounts, fn ($location) => $location['isActive'] && (int) $location['id'] === 12));
    lifecycleCheck(count($live) === 1 && $live[0]['financialAccountCode'] === '139' && $live[0]['balance'] === '500.00', 'Cash screen did not expose the actual funded drawer balance.');
    lifecycleCheck(count(array_filter($cashAccounts, fn ($location) => $location['isActive'] && in_array((int) $location['id'], [1,4], true))) === 0, 'Old cash locations are still active.');
    DB::rollBack();
    lifecycleCheck(dataFingerprints() === $before, 'Operational rows changed after rollback.');
    echo json_encode(['database' => 'cafe_system_618', 'drawer' => 12, 'cashAccount' => '139', 'openAtZero' => true, 'posRecognizesOpenShift' => true,
        'cashSaleAndRefund' => true, 'zeroCloseWith500RetainedFloat' => true, 'cashierWritesBlockedBeforeAndAfterShift' => true,
        'funded500OpeningOnce' => true, 'cashScreenShowsPhysicalDrawerBalance' => true, 'oldLocationsInactive' => true,
        'rollbackOnly' => true, 'allTablesUnchanged' => count($before)], JSON_PRETTY_PRINT).PHP_EOL;
} catch (Throwable $error) {
    if (DB::transactionLevel() > 0) DB::rollBack();
    fwrite(STDERR, $error->getMessage().PHP_EOL);
    exit(1);
}
