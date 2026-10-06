<?php

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Contracts\Http\Kernel as HttpKernel;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

require dirname(__DIR__, 2).'/vendor/autoload.php';
$database = getenv('DB_DATABASE');
if ($database !== 'cafe_system_618_testing_migrations') {
    throw new RuntimeException('The isolated engine migration database is required.');
}
$app = require dirname(__DIR__, 2).'/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();
if (! $app->environment('testing') || DB::selectOne('select current_database() as name')->name !== $database) {
    throw new RuntimeException('Unexpected worker authority.');
}
config(['discount_engine.isolated_automatic' => true]);
$payload = json_decode(base64_decode($argv[1]), true, 512, JSON_THROW_ON_ERROR);
DB::select("select set_config('application_name', ?, false)", [$payload['workerName']]);
// Test-only observation/pause at a completed SQL lock acquisition. Every
// business query still runs through the real HTTP kernel and PostgreSQL.
if (isset($payload['pauseAfterEngineLock'])) {
    DB::statement("SET deadlock_timeout = '10s'");
    $paused = false;
    DB::listen(function ($query) use ($payload, &$paused): void {
        if (! $paused && $query->sql === 'select pg_advisory_xact_lock(?, ?)' && (int) $query->bindings[0] === 20402) {
            $paused = true;
            DB::select('select pg_advisory_xact_lock(?, ?)', [20406, $payload['pauseAfterEngineLock']]);
        }
    });
}
$request = Request::create($payload['path'], $payload['method'], [], [], [], [
    'HTTP_ACCEPT' => 'application/json', 'CONTENT_TYPE' => 'application/json',
    'HTTP_AUTHORIZATION' => 'Bearer '.$payload['token'], 'HTTP_X_DISCOUNT_CONTRACT' => '2',
], json_encode($payload['data'], JSON_THROW_ON_ERROR));
$kernel = $app->make(HttpKernel::class);
$response = $kernel->handle($request);
echo json_encode(['status' => $response->getStatusCode(), 'body' => json_decode($response->getContent(), true)], JSON_THROW_ON_ERROR);
$kernel->terminate($request, $response);
