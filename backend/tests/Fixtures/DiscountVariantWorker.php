<?php

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Contracts\Http\Kernel as HttpKernel;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

require dirname(__DIR__, 2).'/vendor/autoload.php';
$database = getenv('DB_DATABASE');
if (! $database || ! str_contains($database, 'testing')) {
    throw new RuntimeException('A testing database is required.');
}
$app = require dirname(__DIR__, 2).'/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();
if (DB::selectOne('select current_database() as name')->name !== $database) {
    throw new RuntimeException('Unexpected worker database.');
}
$payload = json_decode(base64_decode($argv[1]), true, 512, JSON_THROW_ON_ERROR);
DB::select("select set_config('application_name', ?, false)", [$payload['workerName']]);
$request = Request::create($payload['path'], $payload['method'], [], [], [], [
    'HTTP_ACCEPT' => 'application/json', 'CONTENT_TYPE' => 'application/json',
    'HTTP_AUTHORIZATION' => 'Bearer '.$payload['token'],
], json_encode($payload['data'], JSON_THROW_ON_ERROR));
$kernel = $app->make(HttpKernel::class);
$response = $kernel->handle($request);
echo json_encode(['status' => $response->getStatusCode(), 'body' => json_decode($response->getContent(), true)], JSON_THROW_ON_ERROR);
$kernel->terminate($request, $response);
