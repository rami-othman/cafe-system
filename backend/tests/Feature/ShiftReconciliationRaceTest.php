<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use Tests\Concerns\UsesIsolatedMigrationDatabase;
use Tests\TestCase;

/**
 * H1 — true multi-process PostgreSQL regression tests. shifts:reconcile-overlap
 * exclusively locks every overlapping open shift on a drawer for the whole of
 * its transaction; every operational writer that depends on one of those
 * shifts remaining open (cash refund, card payment, new order creation) must
 * take a row lock on the same shift, held for its own whole transaction, so
 * the two can never both commit against contradictory state.
 *
 * Each scenario proves one of exactly two safe outcomes:
 *  - the operation commits first; reconciliation, once unblocked, re-reads
 *    the now-changed state (ledger balance or active orders) and correctly
 *    refuses to apply, or
 *  - reconciliation commits first (closing the shift); the operation, once
 *    unblocked, observes the shift closed and fails.
 * It must never observe both having committed as if the shift stayed open
 * the whole time.
 */
final class ShiftReconciliationRaceTest extends TestCase
{
    use DatabaseMigrations, UsesIsolatedMigrationDatabase {
        UsesIsolatedMigrationDatabase::beforeRefreshingDatabase insteadof DatabaseMigrations;
    }

    public function test_reconciliation_vs_cash_refund_never_double_commits(): void
    {
        [$tenant, $branch, $owner, $drawer, $shift1, $shift2] = $this->overlappingScope();

        $orderId = (int) DB::table('orders')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'shift_id' => $shift1,
            'order_number' => 'RACE-REFUND-'.uniqid(), 'type' => 'takeaway', 'status' => 'paid', 'payment_status' => 'paid',
            'subtotal' => '30.00', 'total' => '30.00', 'tax_total' => '0.00', 'tax_rate' => 0,
            'opened_at' => now(), 'closed_at' => now(), 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('payments')->insert([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'order_id' => $orderId, 'shift_id' => $shift1,
            'method' => 'cash', 'amount' => '30.00', 'currency' => 'SYP', 'status' => 'completed',
            'idempotency_key' => 'race-refund-payment-'.uniqid(), 'paid_at' => now(), 'created_at' => now(), 'updated_at' => now(),
        ]);
        $token = $this->authenticateTenantUser($tenant);

        $results = $this->runConcurrently([
            'reconcile' => ['mode' => 'reconcile', 'tenantId' => $tenant, 'financialLocationId' => $drawer,
                'confirmedCash' => '0.00', 'reason' => 'race test', 'actorId' => $owner],
            'refund' => ['mode' => 'refund', 'orderId' => $orderId, 'accessToken' => $token, 'request' => [
                'type' => 'full', 'reason' => 'race refund', 'idempotencyKey' => 'race-refund-'.uniqid(),
            ]],
        ]);

        $refundOk = $results['refund']['ok'];
        $reconcileApplied = $results['reconcile']['ok'] && ($results['reconcile']['result']['applied'] ?? false);

        $this->assertFalse($refundOk && $reconcileApplied, 'Refund and reconciliation must never both commit: '.json_encode($results));
        if ($refundOk) {
            $this->assertFalse($reconcileApplied);
            $this->assertContains('CONFIRMED_CASH_MISMATCH', array_column($results['reconcile']['result']['blockers'], 'code'));
            $this->assertSame('open', DB::table('shifts')->where('id', $shift1)->value('status'));
        } else {
            $this->assertTrue($reconcileApplied, json_encode($results));
            $this->assertSame('CASH_REFUND_SHIFT_CLOSED', $results['refund']['code']);
            $this->assertSame('closed', DB::table('shifts')->where('id', $shift1)->value('status'));
            $this->assertSame(0, DB::table('payment_refunds')->where('order_id', $orderId)->count());
        }
    }

    public function test_reconciliation_vs_card_payment_attachment_never_double_commits(): void
    {
        [$tenant, $branch, $owner, $drawer, $shift1, $shift2] = $this->overlappingScope();
        $orderId = (int) DB::table('orders')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'shift_id' => $shift1,
            'order_number' => 'RACE-PAY-'.uniqid(), 'type' => 'takeaway', 'status' => 'draft', 'payment_status' => 'unpaid',
            'subtotal' => '20.00', 'total' => '20.00', 'tax_total' => '0.00', 'tax_rate' => 0,
            'opened_at' => now(), 'created_at' => now(), 'updated_at' => now(),
        ]);
        $token = $this->authenticateTenantUser($tenant);

        $results = $this->runConcurrently([
            'reconcile' => ['mode' => 'reconcile', 'tenantId' => $tenant, 'financialLocationId' => $drawer,
                'confirmedCash' => '0.00', 'reason' => 'race test', 'actorId' => $owner],
            'payment' => ['mode' => 'payment', 'orderId' => $orderId, 'accessToken' => $token, 'request' => [
                'method' => 'cash', 'amount' => '20.00', 'idempotencyKey' => 'race-pay-'.uniqid(),
            ]],
        ]);

        $paymentOk = $results['payment']['ok'];
        $reconcileApplied = $results['reconcile']['ok'] && ($results['reconcile']['result']['applied'] ?? false);

        // Either the payment succeeded and reconciliation never applied (it
        // still legitimately sees the shift's now-paid or still-active order
        // and cannot apply against a stale ledger/order snapshot), or
        // reconciliation applied first and the payment then finds no open
        // shift. Never both.
        $this->assertFalse($paymentOk && $reconcileApplied, 'Payment and reconciliation must never both commit: '.json_encode($results));
        if ($paymentOk) {
            $this->assertFalse($reconcileApplied);
            $this->assertSame('open', DB::table('shifts')->where('id', $shift1)->value('status'));
            $this->assertSame('paid', DB::table('orders')->where('id', $orderId)->value('status'));
        } else {
            $this->assertTrue($reconcileApplied, json_encode($results));
            $this->assertSame('closed', DB::table('shifts')->where('id', $shift1)->value('status'));
            $this->assertSame('draft', DB::table('orders')->where('id', $orderId)->value('status'));
        }
    }

    public function test_reconciliation_vs_new_order_creation_never_double_commits(): void
    {
        [$tenant, $branch, $owner, $drawer, $shift1, $shift2] = $this->overlappingScope();
        $token = $this->authenticateTenantUser($tenant);
        $product = DB::table('products')->where('tenant_id', $tenant)->first();

        $results = $this->runConcurrently([
            'reconcile' => ['mode' => 'reconcile', 'tenantId' => $tenant, 'financialLocationId' => $drawer,
                'confirmedCash' => '0.00', 'reason' => 'race test', 'actorId' => $owner],
            'order' => ['mode' => 'order-create', 'accessToken' => $token, 'request' => [
                'branchId' => $branch, 'shiftId' => $shift1, 'orderType' => 'takeaway',
                'items' => [['productId' => $product->id, 'quantity' => 1, 'modifiers' => []]],
                'idempotencyKey' => 'race-order-'.uniqid(),
            ]],
        ]);

        $orderOk = $results['order']['ok'];
        $reconcileApplied = $results['reconcile']['ok'] && ($results['reconcile']['result']['applied'] ?? false);

        $this->assertFalse($orderOk && $reconcileApplied, 'Order creation and reconciliation must never both commit: '.json_encode($results));
        if ($orderOk) {
            // The new order attached to shift1 while reconciliation was
            // still validating; that order must be visible to it, so
            // reconciliation could not have applied.
            $this->assertFalse($reconcileApplied);
            $newOrderId = (int) $results['order']['result']['data']['id'];
            $this->assertSame($shift1, (int) DB::table('orders')->where('id', $newOrderId)->value('shift_id'));
        } else {
            $this->assertTrue($reconcileApplied, json_encode($results));
            $this->assertNotNull($results['order']['errors']['shiftId'][0] ?? null, json_encode($results));
            $this->assertSame(0, DB::table('orders')->where('tenant_id', $tenant)->count());
        }
    }

    /** @return array{0: int, 1: int, 2: int, 3: int, 4: int, 5: int} tenant, branch, ownerId, drawer, shift1, shift2 */
    private function overlappingScope(): array
    {
        $this->assertStringContainsString('testing', (string) config('database.connections.pgsql_migrations.database'));
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'A2 Race Reconcile', 'slug' => 'a2-race-reconcile-'.uniqid(), 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $branch = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Race Reconcile Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch);
        $owner = User::query()->create(['tenant_id' => $tenant, 'name' => 'Race Reconcile Owner', 'email' => 'a2-race-reconcile-'.uniqid().'@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true]);

        $drawer = (int) DB::table('branches')->where('id', $branch)->value('pos_cash_financial_location_id');
        $now = now();
        $shift1 = (int) DB::table('shifts')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'user_id' => $owner->id, 'financial_location_id' => $drawer,
            'shift_number' => 'SH-RACE-001', 'opening_cash' => '0.00', 'status' => 'open', 'opened_at' => $now->copy()->subHour(),
            'created_at' => $now, 'updated_at' => $now,
        ]);
        // Historical overlap: the unique partial index only ever permitted this
        // in production before it existed; reconciliation exists precisely to
        // clean these up, so the test recreates that same historical shape.
        DB::statement('DROP INDEX IF EXISTS shifts_one_open_per_location');
        $shift2 = (int) DB::table('shifts')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'user_id' => $owner->id, 'financial_location_id' => $drawer,
            'shift_number' => 'SH-RACE-002', 'opening_cash' => '0.00', 'status' => 'open', 'opened_at' => $now,
            'created_at' => $now, 'updated_at' => $now,
        ]);

        // A product for the order-creation scenario, requiring no menu setup.
        DB::table('products')->insertOrIgnore([
            'tenant_id' => $tenant, 'name' => 'Race Product', 'price' => '20.00', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now,
        ]);

        return [$tenant, $branch, (int) $owner->id, $drawer, $shift1, $shift2];
    }

    /**
     * Releases both named workers through one PostgreSQL advisory-lock
     * barrier at (as close to) the same instant, as real separate
     * processes/connections, then returns each worker's result keyed by name.
     *
     * @param  array<string, array<string, mixed>>  $payloadsByName
     * @return array<string, array<string, mixed>>
     */
    private function runConcurrently(array $payloadsByName): array
    {
        $names = array_keys($payloadsByName);
        $barrier = random_int(1, PHP_INT_MAX);
        DB::select('select pg_advisory_lock(?)', [$barrier]);
        $workers = [];
        try {
            foreach ($payloadsByName as $name => $payload) {
                $payload['barrier'] = $barrier;
                $mode = $payload['mode'];
                unset($payload['mode']);
                $pipes = [];
                $env = array_merge(getenv() ?: [], ['DB_DATABASE' => (string) config('database.connections.pgsql_migrations.database')]);
                $process = proc_open([PHP_BINARY, base_path('tests/Fixtures/ConcurrentFinancialWorker.php'), $mode, base64_encode(json_encode($payload, JSON_THROW_ON_ERROR))],
                    [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path(), $env);
                if (! is_resource($process)) {
                    throw new RuntimeException("Could not start concurrent worker [{$name}].");
                }
                $workers[$name] = compact('process', 'pipes');
            }
            $this->waitForBarrier(count($workers));
            DB::select('select pg_advisory_unlock(?)', [$barrier]);
            $barrier = null;

            $results = [];
            foreach ($workers as $name => $worker) {
                $stdout = stream_get_contents($worker['pipes'][1]);
                $stderr = stream_get_contents($worker['pipes'][2]);
                fclose($worker['pipes'][1]);
                fclose($worker['pipes'][2]);
                $exit = proc_close($worker['process']);
                $decoded = json_decode($stdout, true);
                if (! is_array($decoded)) {
                    throw new RuntimeException("Worker [{$name}] did not return JSON (exit {$exit}): {$stderr}");
                }
                $results[$name] = $decoded;
            }

            return $results;
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

    private function waitForBarrier(int $expected): void
    {
        $deadline = microtime(true) + 15;
        do {
            $waiting = (int) DB::table('pg_stat_activity')->where('datname', DB::raw('current_database()'))
                ->where('wait_event_type', 'Lock')->where('wait_event', 'advisory')
                ->whereRaw("query ilike '%pg_advisory_lock%'")->count();
            if ($waiting >= $expected) {
                return;
            }
            usleep(10_000);
        } while (microtime(true) < $deadline);

        throw new RuntimeException("Only {$waiting} of {$expected} workers reached the barrier.");
    }
}
