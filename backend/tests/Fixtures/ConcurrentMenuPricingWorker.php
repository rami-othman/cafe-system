<?php

declare(strict_types=1);

use App\Models\Product;
use App\Services\Catalog\CatalogProductService;
use App\Services\Catalog\ProductVariantPriceOverrideService;
use App\Services\Menu\MenuPriceAdjustmentService;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;

[$encoded] = array_pad(array_slice($argv, 1), 1, null);
$payload = json_decode((string) base64_decode((string) $encoded), true, 512, JSON_THROW_ON_ERROR);
$database = getenv('DB_DATABASE') ?: throw new RuntimeException('Concurrent menu pricing worker requires DB_DATABASE.');
putenv('APP_ENV=testing');
putenv('DB_CONNECTION=pgsql');
putenv('DB_DATABASE='.$database);
require dirname(__DIR__, 2).'/vendor/autoload.php';
$app = require dirname(__DIR__, 2).'/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();
if (config('database.default') !== 'pgsql' || config('database.connections.pgsql.database') !== $database || ! str_contains($database, 'testing')) throw new RuntimeException('Concurrent menu pricing worker refused a non-testing PostgreSQL database.');

if (isset($payload['barrier'])) {
    DB::select('select pg_advisory_lock(?)', [$payload['barrier']]);
    DB::select('select pg_advisory_unlock(?)', [$payload['barrier']]);
}
try {
    if ($payload['action'] === 'apply') {
        $result = app(MenuPriceAdjustmentService::class)->apply($payload['tenantId'], $payload['actorId'], $payload['menuId'], $payload['adjustmentId'], ['previewFingerprint' => $payload['fingerprint'], 'confirmReviewedResults' => true]);
    } elseif ($payload['action'] === 'sync_shared_override') {
        $result = app(ProductVariantPriceOverrideService::class)->sync($payload['tenantId'], $payload['variantId'], [[
            'scopeType' => 'branch_channel',
            'branchId' => $payload['branchId'],
            'channel' => $payload['channel'],
            'overridePrice' => $payload['overridePrice'],
        ]]);
    } elseif ($payload['action'] === 'hold_product') {
        DB::beginTransaction();
        try {
            Product::query()->whereKey($payload['productId'])->lockForUpdate()->firstOrFail();
            DB::select('select pg_advisory_lock(?)', [$payload['releaseBarrier']]);
            DB::commit();
            $result = ['released' => true];
        } catch (Throwable $exception) {
            if (DB::transactionLevel() > 0) {
                DB::rollBack();
            }
            throw $exception;
        }
    } else {
        $result = app(CatalogProductService::class)->archive(Product::query()->whereKey($payload['productId'])->firstOrFail())->toArray();
    }
    echo json_encode(['ok' => true, 'result' => $result], JSON_THROW_ON_ERROR);
} catch (Throwable $exception) {
    echo json_encode(['ok' => false, 'code' => method_exists($exception, 'getDomainCode') ? $exception->getDomainCode() : $exception->getMessage(), 'message' => $exception->getMessage()], JSON_THROW_ON_ERROR);
    exit(1);
}
