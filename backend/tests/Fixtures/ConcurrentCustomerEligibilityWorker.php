<?php

declare(strict_types=1);

use App\Domain\Customer\CustomerOperationalEligibility;
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
    throw new RuntimeException('Concurrent customer worker refused a non-testing PostgreSQL connection.');
}

DB::select('select pg_advisory_lock(?)', [$payload['barrier']]);
DB::select('select pg_advisory_unlock(?)', [$payload['barrier']]);

try {
    $result = DB::transaction(function () use ($payload): array {
        $customer = DB::table('customers')
            ->where('tenant_id', $payload['tenantId'])
            ->where('id', $payload['customerId'])
            ->lockForUpdate()
            ->first();

        if (! $customer) {
            throw new RuntimeException('Customer fixture disappeared.');
        }

        if ($payload['mode'] === 'archive') {
            DB::table('customers')->where('id', $payload['customerId'])->update([
                'is_active' => false,
                'deleted_at' => now(),
                'updated_at' => now(),
            ]);

            return ['action' => 'archived'];
        }

        if ($payload['mode'] !== 'attach') {
            throw new InvalidArgumentException("Unknown customer race mode [{$payload['mode']}].");
        }

        app(CustomerOperationalEligibility::class)->assert($payload['tenantId'], $payload['customerId']);
        $updated = DB::table('orders')->where('tenant_id', $payload['tenantId'])->where('id', $payload['orderId'])->update([
            'customer_id' => $payload['customerId'],
            'updated_at' => now(),
        ]);

        return [
            'action' => 'attached',
            'attached' => $updated === 1,
            'eligibleAtCommit' => true,
        ];
    });

    echo json_encode(['ok' => true, 'result' => $result], JSON_THROW_ON_ERROR);
} catch (Throwable $exception) {
    echo json_encode([
        'ok' => false,
        'code' => property_exists($exception, 'domainCode') ? $exception->domainCode : null,
        'message' => $exception->getMessage(),
    ], JSON_THROW_ON_ERROR);
    exit(1);
}
