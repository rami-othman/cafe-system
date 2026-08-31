<?php

declare(strict_types=1);

use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\RefundController;
use App\Services\PosNumberGenerator;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\JsonResponse;

[$mode, $encodedPayload] = array_pad(array_slice($argv, 1), 2, null);
$payload = json_decode((string) base64_decode((string) $encodedPayload), true, 512, JSON_THROW_ON_ERROR);

// A worker is deliberately an independent Laravel/PDO process. Never inherit
// the local development database when this fixture is launched outside PHPUnit.
putenv('APP_ENV=testing');
putenv('DB_CONNECTION=pgsql');
putenv('DB_DATABASE=cafe_system_618_testing');

require dirname(__DIR__, 2).'/vendor/autoload.php';

$app = require dirname(__DIR__, 2).'/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

if (config('database.default') !== 'pgsql' || config('database.connections.pgsql.database') !== 'cafe_system_618_testing') {
    throw new RuntimeException('Concurrent worker refused a non-testing PostgreSQL connection.');
}

// The parent holds this session lock until every worker is waiting on it.
// Releasing it provides a deterministic start gate without timing sleeps.
DB::select('select pg_advisory_lock(?)', [$payload['barrier']]);
DB::select('select pg_advisory_unlock(?)', [$payload['barrier']]);

try {
    $result = match ($mode) {
        'payment' => app(PaymentController::class)->pay(
            Request::create('/api/v1/orders/'.$payload['orderId'].'/pay', 'POST', $payload['request'], [], [], [
                'HTTP_X_TENANT_ID' => (string) $payload['tenantId'],
            ]),
            $payload['orderId'],
        ),
        'refund' => app(RefundController::class)->store(
            Request::create('/api/v1/orders/'.$payload['orderId'].'/refunds', 'POST', $payload['request'], [], [], [
                'HTTP_X_TENANT_ID' => (string) $payload['tenantId'],
            ]),
            $payload['orderId'],
        ),
        'order-number' => DB::transaction(function () use ($payload): array {
            $number = app(PosNumberGenerator::class)->nextOrderNumber($payload['tenantId'], $payload['branchId']);
            $now = now();
            DB::table('orders')->insert([
                'tenant_id' => $payload['tenantId'],
                'branch_id' => $payload['branchId'],
                'order_number' => $number,
                'type' => 'takeaway',
                'status' => 'draft',
                'payment_status' => 'unpaid',
                'tax_rate' => 0,
                'opened_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            return ['orderNumber' => $number];
        }),
        default => throw new InvalidArgumentException("Unknown concurrent worker mode [{$mode}]."),
    };

    if ($result instanceof JsonResponse) {
        $result = json_decode((string) $result->getContent(), true, 512, JSON_THROW_ON_ERROR);
    }

    echo json_encode(['ok' => true, 'result' => $result], JSON_THROW_ON_ERROR);
} catch (Throwable $exception) {
    echo json_encode([
        'ok' => false,
        'exception' => $exception::class,
        'code' => property_exists($exception, 'domainCode') ? $exception->domainCode : null,
        'message' => $exception->getMessage(),
    ], JSON_THROW_ON_ERROR);
    exit(1);
}
