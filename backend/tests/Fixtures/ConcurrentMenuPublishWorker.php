<?php

declare(strict_types=1);

use App\Services\Menu\MenuPublishingService;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;

[$encodedPayload] = array_pad(array_slice($argv, 1), 1, null);
$payload = json_decode((string) base64_decode((string) $encodedPayload), true, 512, JSON_THROW_ON_ERROR);

putenv('APP_ENV=testing');
putenv('DB_CONNECTION=pgsql');
putenv('DB_DATABASE=cafe_system_618_testing');

require dirname(__DIR__, 2).'/vendor/autoload.php';

$app = require dirname(__DIR__, 2).'/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

if (config('database.default') !== 'pgsql' || config('database.connections.pgsql.database') !== 'cafe_system_618_testing') {
    throw new RuntimeException('Concurrent menu worker refused a non-testing PostgreSQL connection.');
}

// The parent releases this session barrier only after every independent worker
// is blocked on it. This is a deterministic concurrent start, not a sleep.
DB::select('select pg_advisory_lock(?)', [$payload['barrier']]);
DB::select('select pg_advisory_unlock(?)', [$payload['barrier']]);

try {
    $result = app(MenuPublishingService::class)->publish($payload['tenantId'], $payload['input']);
    echo json_encode(['ok' => true, 'result' => $result], JSON_THROW_ON_ERROR);
} catch (Throwable $exception) {
    echo json_encode(['ok' => false, 'message' => $exception->getMessage()], JSON_THROW_ON_ERROR);
    exit(1);
}
