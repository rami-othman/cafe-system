<?php

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;

require dirname(__DIR__, 2).'/vendor/autoload.php';
$app = require dirname(__DIR__, 2).'/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();
if (! $app->environment('testing')) {
    throw new RuntimeException('APP_ENV=testing is required.');
}
foreach (['pgsql' => 'cafe_system_618_testing', 'pgsql_migrations' => 'cafe_system_618_testing_migrations'] as $connection => $expected) {
    $identity = DB::connection($connection)->selectOne('select current_database() as database, current_user as username, version() as version');
    if ($identity->database !== $expected || config("database.connections.$connection.host") !== 'accept-postgres') {
        throw new RuntimeException('Unexpected isolated database identity.');
    }
    echo json_encode(['APP_ENV' => $app->environment(), 'connection' => $connection, 'identity' => $identity], JSON_THROW_ON_ERROR).PHP_EOL;
}
