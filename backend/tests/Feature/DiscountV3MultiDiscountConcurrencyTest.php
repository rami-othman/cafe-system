<?php

namespace Tests\Feature;

use App\Services\DiscountResolutionService;
use App\Services\DiscountSettingsService;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\DiscountEngineFixture;
use Tests\Concerns\UsesIsolatedMigrationDatabase;
use Tests\TestCase;

/** Discount System V3 Phase 2: multi-discount races, with independent worker processes. */
class DiscountV3MultiDiscountConcurrencyTest extends TestCase
{
    use DatabaseMigrations, UsesIsolatedMigrationDatabase {
        UsesIsolatedMigrationDatabase::beforeRefreshingDatabase insteadof DatabaseMigrations;
    }
    use DiscountEngineFixture;

    protected function tearDown(): void
    {
        if (DB::selectOne('select current_database() as name')->name !== 'cafe_system_618_testing_migrations') {
            throw new \RuntimeException('Unexpected concurrency cleanup database.');
        }
        foreach (['discount_reviews', 'discount_operations', 'discount_payment_quotes', 'order_discount_intents', 'discount_usages', 'order_discounts'] as $table) {
            DB::table($table)->delete();
        }
        parent::tearDown();
    }

    private function manual(array $f, array $changes = []): int
    {
        return $this->policy($f, array_replace(['applicationMode' => 'manual'], $changes));
    }

    private function m(int $id): array
    {
        return ['source' => 'configured_manual', 'discountId' => $id];
    }

    private function anotherOrder(array $f): array
    {
        $row = (array) DB::table('orders')->find($f['order']);
        unset($row['id']);
        $row['order_number'] = uniqid('ENGINE-');
        $f['order'] = DB::table('orders')->insertGetId($row);
        $f['items'] = [];
        foreach ($f['products'] as $product) {
            $f['items'][] = DB::table('order_items')->insertGetId(['tenant_id' => $f['tenant'], 'order_id' => $f['order'], 'product_id' => $product, 'product_name' => 'Pinned', 'quantity' => 1, 'unit_price' => 10, 'total' => 10]);
        }

        return $f;
    }

    /** Two stacked discounts applied to the order; returns their ids. */
    private function stack(array $f, array $second = []): array
    {
        $first = $this->manual($f, ['value' => 10]);
        $other = $this->manual($f, $second + ['value' => 20]);
        $this->applyReview($f, $this->preview($f, ['action' => 'set', 'intents' => [$this->m($first), $this->m($other)]]), 'stack-'.$f['order']);

        return [$first, $other];
    }

    private function enableMulti(array $f): void
    {
        $this->settings($f, ['allowMultipleDiscounts' => true, 'maximumDiscountsPerOrder' => 3, 'stackingMode' => 'same_item_allowed']);
    }

    public function test_competing_orders_for_the_last_use_of_one_discount_settle_exactly_once(): void
    {
        $a = $this->fixture();
        $this->enableMulti($a);
        $b = $this->anotherOrder($a);
        $shared = $this->manual($a, ['value' => 10]);
        $limited = $this->manual($a, ['value' => 20, 'usageLimit' => 1]);
        $intents = ['action' => 'set', 'intents' => [$this->m($shared), $this->m($limited)]];
        $this->applyReview($a, $this->preview($a, $intents), 'a');
        $this->applyReview($b, $this->preview($b, $intents), 'b');
        $qa = $this->quote($a, $a['cash']);
        $qb = $this->quote($b, $b['cash']);

        $results = $this->race($a, [[$a, 'POST', '/pay', $this->payData($a, $qa, 'one')], [$b, 'POST', '/pay', $this->payData($b, $qb, 'two')]]);
        $statuses = array_column($results, 'status');
        sort($statuses);
        $this->assertSame([200, 422], $statuses, json_encode($results));
        $this->assertContains(collect($results)->firstWhere('status', 422)['body']['code'], ['ORDER_TOTAL_CHANGED', 'DISCOUNT_USAGE_LIMIT_REACHED']);
        // The loser leaves no partial usage behind, not even for the unlimited discount.
        $this->assertDatabaseCount('payments', 1);
        $this->assertSame(2, DB::table('discount_usages')->count());
        $this->assertSame(1, (int) DB::table('discounts')->find($shared)->used_count);
        $this->assertSame(1, (int) DB::table('discounts')->find($limited)->used_count);
        $this->assertSame(1, DB::table('orders')->where('payment_status', 'paid')->count());
    }

    public function test_duplicate_payment_requests_for_a_multi_discount_order_consume_usage_once(): void
    {
        $f = $this->fixture();
        $this->enableMulti($f);
        $this->stack($f);
        $quote = $this->quote($f, $f['cash']);
        $data = $this->payData($f, $quote, 'duplicate-multi');
        $results = $this->race($f, [[$f, 'POST', '/pay', $data], [$f, 'POST', '/pay', $data]]);
        $this->assertSame([200, 200], array_column($results, 'status'), json_encode($results));
        $this->assertSame($results[0]['body'], $results[1]['body']);
        $this->assertDatabaseCount('payments', 1);
        $this->assertDatabaseCount('discount_usages', 2);
        $this->assertDatabaseCount('order_discounts', 2);
        $this->assertSame('14.40', DB::table('payments')->value('amount'));
    }

    public function test_cafe_policy_change_racing_a_multi_discount_payment_is_serialized(): void
    {
        $f = $this->fixture();
        $this->enableMulti($f);
        $this->stack($f);
        $quote = $this->quote($f, $f['cash']);
        $version = (int) DB::table('tenant_discount_settings')->where('tenant_id', $f['tenant'])->value('version');
        $payload = array_replace(DiscountSettingsService::DEFAULTS, ['expectedVersion' => $version, 'allowMultipleDiscounts' => false]);
        $results = $this->race($f, [[$f, 'PUT', '/api/v1/cafe-configuration/discount-settings', $payload], [$f, 'POST', '/pay', $this->payData($f, $quote, 'policy-race')]]);
        $this->assertSame(200, $results[0]['status'], json_encode($results));
        $this->assertContains($results[1]['status'], [200, 422], json_encode($results));
        if ($results[1]['status'] === 422) {
            $this->assertSame('ORDER_TOTAL_CHANGED', $results[1]['body']['code']);
            $this->assertDatabaseCount('payments', 0);
            $this->assertDatabaseCount('discount_usages', 0);
        } else {
            // Payment won the lock: it settled under the policy it was quoted with, completely.
            $this->assertDatabaseCount('payments', 1);
            $this->assertDatabaseCount('discount_usages', 2);
            $this->assertSame('14.40', DB::table('payments')->value('amount'));
        }
    }

    public function test_discount_edit_racing_a_multi_discount_payment_never_settles_stale_math(): void
    {
        $f = $this->fixture();
        $this->enableMulti($f);
        [, $second] = $this->stack($f);
        $quote = $this->quote($f, $f['cash']);
        $payload = ['name' => 'Edited', 'applicationMode' => 'manual', 'scope' => 'order', 'type' => 'percentage', 'value' => 50, 'isActive' => true, 'appliesToAllBranches' => true];
        $results = $this->race($f, [[$f, 'PUT', '/api/v1/discounts/'.$second, $payload], [$f, 'POST', '/pay', $this->payData($f, $quote, 'edit-race')]]);
        $this->assertSame(200, $results[0]['status'], json_encode($results));
        $this->assertContains($results[1]['status'], [200, 422], json_encode($results));
        if ($results[1]['status'] === 422) {
            $this->assertSame('ORDER_TOTAL_CHANGED', $results[1]['body']['code']);
            $this->assertDatabaseCount('payments', 0);
            $this->assertDatabaseCount('discount_usages', 0);
        } else {
            $this->assertSame('14.40', DB::table('payments')->value('amount'));
            $this->assertDatabaseCount('discount_usages', 2);
        }
    }

    public function test_two_clients_changing_the_same_order_discounts_leave_one_consistent_set(): void
    {
        $f = $this->fixture();
        $this->enableMulti($f);
        $a = $this->manual($f, ['value' => 10]);
        $b = $this->manual($f, ['value' => 20]);
        $one = $this->preview($f, ['action' => 'set', 'intents' => [$this->m($a)]]);
        $two = $this->preview($f, ['action' => 'set', 'intents' => [$this->m($a), $this->m($b)]]);
        $results = $this->race($f, [
            [$f, 'POST', '/discounts/operations', ['reviewId' => $one['reviewId'], 'operationId' => 'client-one']],
            [$f, 'POST', '/discounts/operations', ['reviewId' => $two['reviewId'], 'operationId' => 'client-two']],
        ]);
        $statuses = array_column($results, 'status');
        $this->assertContains(200, $statuses, json_encode($results));
        foreach ($results as $result) {
            if ($result['status'] === 422) {
                $this->assertSame('DISCOUNT_REVIEW_STALE', $result['body']['code']);
            }
        }
        $rows = DB::table('order_discounts')->where('order_id', $f['order'])->orderBy('application_sequence')->get();
        $this->assertSame(range(1, $rows->count()), $rows->pluck('application_sequence')->map(fn ($v) => (int) $v)->all());
        $this->assertSame($rows->pluck('discount_id')->map(fn ($v) => (int) $v)->all(), array_column(json_decode(DB::table('order_discount_intents')->where('order_id', $f['order'])->value('intent'), true), 'discountId'));
        $this->assertSame((string) DB::table('order_discounts')->where('order_id', $f['order'])->sum('discount_amount'), DB::table('orders')->find($f['order'])->discount_total);
    }

    private function race(array $f, array $requests): array
    {
        $this->assertSame('cafe_system_618_testing_migrations', DB::selectOne('select current_database() as name')->name);
        $workers = [];
        DB::beginTransaction();
        app(DiscountResolutionService::class)->lock($f['tenant']);
        $parent = (int) DB::selectOne('select pg_backend_pid() as pid')->pid;
        try {
            foreach ($requests as [$scope, $method, $suffix, $data]) {
                $name = uniqid('engine-worker-');
                $path = str_starts_with($suffix, '/api/') ? $suffix : '/api/v1/orders/'.$scope['order'].$suffix;
                $payload = ['workerName' => $name, 'token' => $scope['token'], 'path' => $path, 'method' => $method, 'data' => $data];
                $env = array_merge(getenv() ?: [], ['APP_ENV' => 'testing', 'DB_DATABASE' => 'cafe_system_618_testing_migrations', 'DB_URL' => '']);
                $process = proc_open([PHP_BINARY, base_path('tests/Fixtures/DiscountEngineWorker.php'), base64_encode(json_encode($payload))], [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path(), $env);
                $this->assertIsResource($process);
                $workers[] = compact('name', 'process', 'pipes');
            }
            $deadline = microtime(true) + 20;
            do {
                DB::select('select pg_stat_clear_snapshot()');
                $blocked = 0;
                foreach ($workers as $worker) {
                    $state = DB::selectOne('WITH RECURSIVE waits(pid) AS (SELECT pid FROM pg_stat_activity WHERE application_name = ? UNION SELECT unnest(pg_blocking_pids(pid)) FROM waits) SELECT EXISTS(SELECT 1 FROM waits WHERE pid = ?) AS reaches_parent', [$worker['name'], $parent]);
                    if ($state->reaches_parent) {
                        $blocked++;
                    }
                }
                if ($blocked === count($workers)) {
                    break;
                }
            } while (microtime(true) < $deadline);
            $this->assertSame(count($workers), $blocked, 'Every independent worker must reach the physical lock barrier.');
            DB::commit();
            $results = [];
            foreach ($workers as $worker) {
                stream_set_blocking($worker['pipes'][1], false);
                stream_set_blocking($worker['pipes'][2], false);
                $out = $err = '';
                $deadline = microtime(true) + 30;
                do {
                    $out .= stream_get_contents($worker['pipes'][1]);
                    $err .= stream_get_contents($worker['pipes'][2]);
                    $status = proc_get_status($worker['process']);
                    if (! $status['running']) {
                        break;
                    }
                } while (microtime(true) < $deadline);
                $out .= stream_get_contents($worker['pipes'][1]);
                $err .= stream_get_contents($worker['pipes'][2]);
                $this->assertFalse($status['running'], 'Independent worker did not finish: '.$err);
                $this->assertSame(0, $status['exitcode'], $err.' '.$out);
                $results[] = json_decode($out, true, flags: JSON_THROW_ON_ERROR);
            }

            return $results;
        } finally {
            if (DB::transactionLevel()) {
                DB::rollBack();
            }
            foreach ($workers as $worker) {
                if (is_resource($worker['process'])) {
                    proc_terminate($worker['process']);
                    proc_close($worker['process']);
                }
                foreach ($worker['pipes'] as $pipe) {
                    if (is_resource($pipe)) {
                        fclose($pipe);
                    }
                }
            }
        }
    }
}
