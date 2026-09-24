<?php

declare(strict_types=1);

use App\Models\ProductVariant;
use App\Services\Catalog\RecipeConfigurationService;
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
    throw new RuntimeException('Concurrent recipe worker refused a non-testing PostgreSQL connection.');
}

DB::select('select pg_advisory_lock(?)', [$payload['barrier']]);
DB::select('select pg_advisory_unlock(?)', [$payload['barrier']]);

try {
    $variant = ProductVariant::query()
        ->where('tenant_id', $payload['tenantId'])
        ->whereKey($payload['variantId'])
        ->firstOrFail();
    $service = app(RecipeConfigurationService::class);
    $result = $payload['mode'] === 'clear'
        ? $service->deleteRecipe($variant)
        : $service->replaceRecipe($variant, [[
            'materialId' => $payload['materialId'],
            'quantity' => $payload['quantity'],
            'unitCode' => 'g',
        ]]);

    echo json_encode(['ok' => true, 'result' => $result], JSON_THROW_ON_ERROR);
} catch (Throwable $exception) {
    echo json_encode(['ok' => false, 'message' => $exception->getMessage()], JSON_THROW_ON_ERROR);
    exit(1);
}
