<?php

namespace Tests\Feature;

use App\Services\PosNumberGenerator;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use Tests\TestCase;

class PreAuthFinancialConcurrencyTest extends TestCase
{
    use DatabaseMigrations;

    protected function setUp(): void
    {
        parent::setUp();

        $this->assertSame('pgsql', config('database.default'));
        $this->assertSame('cafe_system_618_testing', config('database.connections.pgsql.database'));
        $this->seed();

        // PHPUnit seeds after migrate:fresh. Reapply this data migration so the
        // seeded Batch 12 fixtures receive the same historical high-water
        // initialization as an in-place production upgrade.
        $migration = require database_path('migrations/2026_08_30_000001_add_pre_auth_financial_hardening.php');
        $migration->down();
        $migration->up();
    }

    public function test_concurrent_different_key_payments_settle_an_order_once(): void
    {
        [$tenantId, $branchId] = $this->scope();
        $orderId = $this->makeOrder($tenantId, $branchId, 100);

        $results = $this->runConcurrently('payment', [
            $this->paymentPayload($tenantId, $orderId, 'payment-a'),
            $this->paymentPayload($tenantId, $orderId, 'payment-b'),
        ]);

        $this->assertCount(1, array_filter($results, fn (array $result): bool => $result['ok']));
        $loser = collect($results)->first(fn (array $result): bool => ! $result['ok']);
        $this->assertContains($loser['code'], ['PAYMENT_ALREADY_COMPLETED', 'ORDER_ALREADY_PAID']);
        $this->assertSame(1, DB::table('payments')->where('order_id', $orderId)->where('status', 'completed')->count());
        $this->assertSame(100.0, (float) DB::table('payments')->where('order_id', $orderId)->sum('amount'));
        $this->assertSame('paid', DB::table('orders')->where('id', $orderId)->value('payment_status'));
    }

    public function test_concurrent_same_key_payments_converge_on_one_payment(): void
    {
        [$tenantId, $branchId] = $this->scope();
        $orderId = $this->makeOrder($tenantId, $branchId, 100);
        $payload = $this->paymentPayload($tenantId, $orderId, 'same-payment-key');

        $results = $this->runConcurrently('payment', [$payload, $payload]);

        $this->assertCount(2, array_filter($results, fn (array $result): bool => $result['ok']));
        $paymentIds = collect($results)->pluck('result.data.payment.id')->unique()->values();
        $this->assertCount(1, $paymentIds);
        $this->assertSame(1, DB::table('payments')->where('order_id', $orderId)->count());
    }

    public function test_concurrent_final_discount_usage_is_consumed_once(): void
    {
        [$tenantId, $branchId] = $this->scope();
        $now = now();
        $discountId = DB::table('discounts')->insertGetId([
            'tenant_id' => $tenantId, 'name' => 'One final use', 'application_mode' => 'auto',
            'type' => 'percentage', 'value' => 10, 'scope' => 'order', 'minimum_order_amount' => 0,
            'usage_limit' => 1, 'used_count' => 0, 'is_active' => true, 'created_at' => $now, 'updated_at' => $now,
        ]);
        $firstOrder = $this->makeDiscountedOrder($tenantId, $branchId, $discountId);
        $secondOrder = $this->makeDiscountedOrder($tenantId, $branchId, $discountId);

        $results = $this->runConcurrently('payment', [
            $this->paymentPayload($tenantId, $firstOrder, 'final-discount-a'),
            $this->paymentPayload($tenantId, $secondOrder, 'final-discount-b'),
        ]);

        $this->assertCount(1, array_filter($results, fn (array $result): bool => $result['ok']));
        $loser = collect($results)->first(fn (array $result): bool => ! $result['ok']);
        $this->assertSame('DISCOUNT_USAGE_LIMIT_REACHED', $loser['code']);
        $this->assertSame(1, DB::table('discount_usages')->where('discount_id', $discountId)->count());
        $this->assertSame(1, (int) DB::table('discounts')->where('id', $discountId)->value('used_count'));
    }

    public function test_payment_conflict_and_lost_response_retry_have_no_second_effect(): void
    {
        [$tenantId, $branchId] = $this->scope();
        $orderId = $this->makeOrder($tenantId, $branchId, 100);
        $payload = ['method' => 'cash', 'amount' => 100, 'idempotencyKey' => 'lost-payment-response'];

        // The worker's successful response is intentionally discarded: this models a committed request whose response was lost.
        $this->runConcurrently('payment', [[
            'tenantId' => $tenantId, 'orderId' => $orderId, 'request' => $payload,
        ]]);
        $existingId = DB::table('payments')->where('order_id', $orderId)->value('id');

        $this->postJson("/api/v1/orders/{$orderId}/pay", $payload)
            ->assertOk()->assertJsonPath('data.payment.id', $existingId);
        $this->postJson("/api/v1/orders/{$orderId}/pay", [...$payload, 'method' => 'card'])
            ->assertUnprocessable()->assertJsonPath('code', 'PAYMENT_IDEMPOTENCY_CONFLICT');
        $this->assertSame(1, DB::table('payments')->where('order_id', $orderId)->count());
    }

    public function test_concurrent_different_key_refunds_cannot_over_refund(): void
    {
        [$tenantId, $branchId] = $this->scope();
        [$orderId] = $this->makePaidOrder($tenantId, $branchId, 100);

        $results = $this->runConcurrently('refund', [
            $this->refundPayload($tenantId, $orderId, 'refund-a', 70),
            $this->refundPayload($tenantId, $orderId, 'refund-b', 70),
        ]);

        $this->assertCount(1, array_filter($results, fn (array $result): bool => $result['ok']));
        $loser = collect($results)->first(fn (array $result): bool => ! $result['ok']);
        $this->assertSame('REFUND_EXCEEDS_REMAINING', $loser['code']);
        $this->assertSame(70.0, (float) DB::table('payment_refunds')->where('order_id', $orderId)->sum('amount'));
        $this->assertLessThanOrEqual(100.0, (float) DB::table('payment_refunds')->where('order_id', $orderId)->sum('amount'));
        $this->assertSame('partially_refunded', DB::table('orders')->where('id', $orderId)->value('payment_status'));
    }

    public function test_concurrent_same_key_refunds_and_lost_response_retry_create_one_effect(): void
    {
        [$tenantId, $branchId] = $this->scope();
        [$orderId] = $this->makePaidOrder($tenantId, $branchId, 100);
        $payload = $this->refundPayload($tenantId, $orderId, 'same-refund-key', 70);

        $results = $this->runConcurrently('refund', [$payload, $payload]);

        $this->assertCount(2, array_filter($results, fn (array $result): bool => $result['ok']));
        $refundIds = collect($results)->pluck('result.data.id')->unique()->values();
        $this->assertCount(1, $refundIds);
        $this->assertSame(1, DB::table('payment_refunds')->where('order_id', $orderId)->count());
        $this->assertSame(70.0, (float) DB::table('payment_refunds')->where('order_id', $orderId)->sum('amount'));

        $this->postJson("/api/v1/orders/{$orderId}/refunds", $payload['request'])
            ->assertCreated()->assertJsonPath('data.id', $refundIds->first());
        $this->assertSame(1, DB::table('payment_refunds')->where('order_id', $orderId)->count());
        $this->assertSame(30.0, 100 - (float) DB::table('payment_refunds')->where('order_id', $orderId)->sum('amount'));
    }

    public function test_order_and_refund_numbers_survive_true_contention_and_rollback(): void
    {
        [$tenantId, $branchId] = $this->scope();
        $startingOrderSequence = (int) (DB::table('pos_number_counters')->where([
            'tenant_id' => $tenantId, 'kind' => 'order', 'branch_scope_id' => $branchId,
        ])->value('next_value') ?? 0);
        $orderResults = $this->runConcurrently('order-number', array_fill(0, 4, [
            'tenantId' => $tenantId, 'branchId' => $branchId,
        ]));
        $orderNumbers = collect($orderResults)->pluck('result.orderNumber')->values();
        $this->assertCount(4, $orderNumbers->unique());
        $this->assertTrue($orderNumbers->every(fn (string $number): bool => preg_match('/^'.now()->format('Ymd').'-\\d{4,}$/', $number) === 1));
        $this->assertSame($startingOrderSequence + 4, DB::table('pos_number_counters')->where([
            'tenant_id' => $tenantId, 'kind' => 'order', 'branch_scope_id' => $branchId,
        ])->value('next_value'));

        $rollbackNumber = null;
        try {
            DB::transaction(function () use ($tenantId, $branchId, &$rollbackNumber): void {
                $rollbackNumber = app(PosNumberGenerator::class)->nextOrderNumber($tenantId, $branchId);
                throw new RuntimeException('Intentional transaction rollback.');
            });
        } catch (RuntimeException $exception) {
            $this->assertSame('Intentional transaction rollback.', $exception->getMessage());
        }
        $this->assertSame($rollbackNumber, app(PosNumberGenerator::class)->nextOrderNumber($tenantId, $branchId));

        $startingRefundSequence = (int) (DB::table('pos_number_counters')->where([
            'tenant_id' => $tenantId, 'kind' => 'refund', 'branch_scope_id' => 0,
        ])->value('next_value') ?? 0);
        $paidOrders = array_map(fn (): array => $this->makePaidOrder($tenantId, $branchId, 100), range(1, 4));
        $refundResults = $this->runConcurrently('refund', array_map(
            fn (array $paid): array => $this->refundPayload($tenantId, $paid[0], 'refund-number-'.$paid[0], 100),
            $paidOrders,
        ));
        $refundNumbers = collect($refundResults)->pluck('result.data.refundNumber')->values();
        $this->assertCount(4, $refundNumbers->unique());
        $this->assertTrue($refundNumbers->every(fn (string $number): bool => preg_match('/^RF-'.now()->format('Ymd').'-\\d{4,}$/', $number) === 1));
        $this->assertSame($startingRefundSequence + 4, DB::table('pos_number_counters')->where([
            'tenant_id' => $tenantId, 'kind' => 'refund', 'branch_scope_id' => 0,
        ])->value('next_value'));
    }

    public function test_hardening_migration_preserves_existing_batch_twelve_financial_records(): void
    {
        [$tenantId, $branchId] = $this->scope();
        $migration = require database_path('migrations/2026_08_30_000001_add_pre_auth_financial_hardening.php');
        $migration->down();

        [$orderId, $paymentId] = $this->makePaidOrder($tenantId, $branchId, 100);
        $refundId = DB::table('payment_refunds')->insertGetId([
            'tenant_id' => $tenantId, 'branch_id' => $branchId, 'order_id' => $orderId,
            'payment_id' => $paymentId, 'refund_number' => 'RF-historical-'.uniqid(),
            'type' => 'partial', 'amount' => 20, 'reason' => 'Historical record', 'status' => 'completed',
            'refunded_at' => now(), 'created_at' => now(), 'updated_at' => now(),
        ]);

        $migration->up();

        $this->assertSame(100.0, (float) DB::table('payments')->where('id', $paymentId)->value('amount'));
        $this->assertSame(20.0, (float) DB::table('payment_refunds')->where('id', $refundId)->value('amount'));
        $this->assertSame($orderId, (int) DB::table('payment_refunds')->where('id', $refundId)->value('order_id'));
        $this->assertNull(DB::table('payments')->where('id', $paymentId)->value('idempotency_key'));
        $this->assertNull(DB::table('payment_refunds')->where('id', $refundId)->value('idempotency_key'));
    }

    private function scope(): array
    {
        return [(int) DB::table('tenants')->orderBy('id')->value('id'), (int) DB::table('branches')->orderBy('id')->value('id')];
    }

    private function makeOrder(int $tenantId, int $branchId, float $total): int
    {
        $now = now();

        return DB::table('orders')->insertGetId([
            'tenant_id' => $tenantId, 'branch_id' => $branchId,
            'order_number' => 'concurrency-'.uniqid(), 'type' => 'takeaway',
            'status' => 'draft', 'payment_status' => 'unpaid', 'tax_rate' => 0,
            'subtotal' => $total, 'total' => $total, 'opened_at' => $now,
            'created_at' => $now, 'updated_at' => $now,
        ]);
    }

    private function makePaidOrder(int $tenantId, int $branchId, float $total): array
    {
        $orderId = $this->makeOrder($tenantId, $branchId, $total);
        $now = now();
        DB::table('orders')->where('id', $orderId)->update(['status' => 'paid', 'payment_status' => 'paid', 'closed_at' => $now]);
        $paymentId = DB::table('payments')->insertGetId([
            'tenant_id' => $tenantId, 'branch_id' => $branchId, 'order_id' => $orderId,
            'method' => 'cash', 'amount' => $total, 'currency' => 'SYP', 'status' => 'completed',
            'paid_at' => $now, 'created_at' => $now, 'updated_at' => $now,
        ]);

        return [$orderId, $paymentId];
    }

    private function makeDiscountedOrder(int $tenantId, int $branchId, int $discountId): int
    {
        $orderId = $this->makeOrder($tenantId, $branchId, 100);
        $product = DB::table('products')->where('tenant_id', $tenantId)->first();
        DB::table('order_items')->insert([
            'tenant_id' => $tenantId, 'order_id' => $orderId, 'product_id' => $product->id,
            'category_id' => $product->category_id, 'product_name' => $product->name,
            'quantity' => 1, 'unit_price' => 100, 'total' => 100, 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('order_discounts')->insert([
            'tenant_id' => $tenantId, 'order_id' => $orderId, 'discount_id' => $discountId,
            'discount_name' => 'One final use', 'discount_type' => 'percentage', 'discount_value' => 10,
            'discount_amount' => 10, 'created_at' => now(), 'updated_at' => now(),
        ]);

        return $orderId;
    }

    private function paymentPayload(int $tenantId, int $orderId, string $key): array
    {
        return ['tenantId' => $tenantId, 'orderId' => $orderId, 'request' => [
            'method' => 'cash', 'amount' => 100, 'idempotencyKey' => $key,
        ]];
    }

    private function refundPayload(int $tenantId, int $orderId, string $key, float $amount): array
    {
        return ['tenantId' => $tenantId, 'orderId' => $orderId, 'request' => [
            'type' => 'partial', 'amount' => $amount, 'reason' => 'Concurrency test', 'idempotencyKey' => $key,
        ]];
    }

    /** @return list<array{ok: bool, result?: array, code?: string|null, message?: string}> */
    private function runConcurrently(string $mode, array $payloads): array
    {
        $barrier = random_int(1, PHP_INT_MAX);
        DB::select('select pg_advisory_lock(?)', [$barrier]);
        $workers = [];

        try {
            foreach ($payloads as $payload) {
                $payload['barrier'] = $barrier;
                $pipes = [];
                $process = proc_open([
                    PHP_BINARY,
                    base_path('tests/Fixtures/ConcurrentFinancialWorker.php'),
                    $mode,
                    base64_encode(json_encode($payload, JSON_THROW_ON_ERROR)),
                ], [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path());
                if (! is_resource($process)) {
                    throw new RuntimeException('Could not start concurrent financial worker.');
                }
                $workers[] = compact('process', 'pipes');
            }

            $this->waitForBarrierWorkers(count($workers));
            DB::select('select pg_advisory_unlock(?)', [$barrier]);
            $barrier = null;

            return array_map(function (array $worker): array {
                $stdout = stream_get_contents($worker['pipes'][1]);
                $stderr = stream_get_contents($worker['pipes'][2]);
                fclose($worker['pipes'][1]);
                fclose($worker['pipes'][2]);
                $exitCode = proc_close($worker['process']);
                $result = json_decode($stdout, true);
                if (! is_array($result)) {
                    throw new RuntimeException("Concurrent worker did not return JSON (exit {$exitCode}): {$stderr}");
                }

                return $result;
            }, $workers);
        } finally {
            if ($barrier !== null) {
                DB::select('select pg_advisory_unlock(?)', [$barrier]);
            }
            foreach ($workers as $worker) {
                if (is_resource($worker['process'])) {
                    proc_terminate($worker['process']);
                }
            }
        }
    }

    private function waitForBarrierWorkers(int $expected): void
    {
        $deadline = microtime(true) + 10;
        do {
            $waiting = (int) DB::table('pg_stat_activity')
                ->where('datname', DB::raw('current_database()'))
                ->where('wait_event_type', 'Lock')
                ->where('wait_event', 'advisory')
                ->whereRaw("query ilike '%pg_advisory_lock%'")
                ->count();
            if ($waiting >= $expected) {
                return;
            }
            usleep(10_000);
        } while (microtime(true) < $deadline);

        throw new RuntimeException("Only {$waiting} of {$expected} workers reached the PostgreSQL start barrier.");
    }
}
