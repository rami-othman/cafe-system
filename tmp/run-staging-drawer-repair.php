<?php
$root = $argv[1] ?? '/root/cafe618-shift-fix-test';
if (!in_array($root, ['/root/cafe618-shift-fix-test','/var/www/cafe-system-staging/backend'], true)) throw new RuntimeException('Unexpected root');
require $root.'/vendor/autoload.php';
$app = require $root.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use Illuminate\Support\Facades\DB;
$db = DB::connection()->getDatabaseName();
if (!in_array($db,['cafe618_shift_fix_test','cafe618_staging'],true)) throw new RuntimeException('Unexpected database');
if ($db === 'cafe618_staging' && !app()->environment('staging')) throw new RuntimeException('Unexpected environment');
$service = app(App\Services\CashDrawerConsolidationService::class);
$dry = $service->run(1,5,4861,4869,[1,4],12);
echo json_encode($dry,JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE).PHP_EOL;
if (($argv[2] ?? '') === '--apply') {
    $backup = $argv[3] ?? '';
    if (!is_file($backup) || file_get_contents($backup,false,null,0,5) !== 'PGDMP') throw new RuntimeException('Missing valid backup');
    if ($dry['alreadyApplied']) exit(0);
    echo json_encode($service->run(1,5,4861,4869,[1,4],12,true,$dry['fingerprint'],hash_file('sha256',$backup)),JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE).PHP_EOL;
}
