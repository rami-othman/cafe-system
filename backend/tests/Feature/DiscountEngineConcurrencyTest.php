<?php

namespace Tests\Feature;

use App\Models\ProductVariant;
use App\Services\Catalog\RecipeConfigurationService;
use App\Services\DiscountResolutionService;
use App\Services\DiscountSettingsService;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\DiscountEngineFixture;
use Tests\Concerns\UsesIsolatedMigrationDatabase;
use Tests\TestCase;

class DiscountEngineConcurrencyTest extends TestCase
{
    use DatabaseMigrations, UsesIsolatedMigrationDatabase {
        UsesIsolatedMigrationDatabase::beforeRefreshingDatabase insteadof DatabaseMigrations;
    }
    use DiscountEngineFixture;

    protected function tearDown(): void
    {
        // This class owns a migrate:fresh isolated fixture database. Preserve
        // production roll-forward guards; remove only this test's protocol and
        // usage fixtures AFTER all settlement assertions, before trait rollback.
        if (DB::selectOne('select current_database() as name')->name !== 'cafe_system_618_testing_migrations') {
            throw new \RuntimeException('Unexpected concurrency cleanup database.');
        }
        foreach (['discount_reviews', 'discount_operations', 'discount_payment_quotes', 'order_discount_intents', 'discount_usages', 'order_discounts'] as $table) {
            DB::table($table)->delete();
        }
        parent::tearDown();
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

    public function test_final_policy_use_competing_orders_has_one_settlement_and_no_partial_loser(): void
    {
        $a = $this->fixture();
        $b = $this->anotherOrder($a);
        $policy = $this->policy($a, ['usageLimit' => 1]);
        $qa = $this->quote($a, $a['cash']);
        $qb = $this->quote($b, $b['cash']);
        $results = $this->race($a, [[$a, 'POST', '/pay', $this->payData($a, $qa, 'one')], [$b, 'POST', '/pay', $this->payData($b, $qb, 'two')]]);
        $statuses = array_column($results, 'status');
        sort($statuses);
        $this->assertSame([200, 422], $statuses, json_encode($results));
        $loser = collect($results)->firstWhere('status', 422);
        $this->assertSame('ORDER_TOTAL_CHANGED', $loser['body']['code']);
        $this->assertDatabaseCount('payments', 1);
        $this->assertDatabaseCount('discount_usages', 1);
        $this->assertDatabaseCount('order_discounts', 1);
        $this->assertDatabaseCount('order_discount_allocations', 2);
        $this->assertSame(1, (int) DB::table('discounts')->find($policy)->used_count);
        $this->settlements(1, '18.00');
    }

    public function test_overlapping_multi_policy_payments_lock_policies_once_and_settle_both(): void
    {
        $a = $this->fixture();
        $this->settings($a, ['combinationMode' => 'disjoint_items']);
        $b = $this->anotherOrder($a);
        $p = $this->policy($a, ['scope' => 'product', 'value' => 50, 'targetProductIds' => [$a['products'][0]]]);
        $q = $this->policy($a, ['scope' => 'product', 'value' => 20, 'targetProductIds' => [$a['products'][1]]]);
        $qa = $this->quote($a, $a['cash']);
        $qb = $this->quote($b, $b['cash']);
        $results = $this->race($a, [[$a, 'POST', '/pay', $this->payData($a, $qa, 'one')], [$b, 'POST', '/pay', $this->payData($b, $qb, 'two')]]);
        $this->assertSame([200, 200], array_column($results, 'status'), json_encode($results));
        $this->assertDatabaseCount('discount_usages', 4);
        $this->assertDatabaseCount('order_discount_allocations', 4);
        $this->assertSame(2, (int) DB::table('discounts')->find($p)->used_count);
        $this->assertSame(2, (int) DB::table('discounts')->find($q)->used_count);
        $this->settlements(2, '13.00');
    }

    public function test_different_policy_payments_through_same_shift_drawer_do_not_upgrade_shared_locks(): void
    {
        $a = $this->fixture();
        $b = $this->anotherOrder($a);
        $p = $this->policy($a, ['scope' => 'product', 'value' => 50, 'targetProductIds' => [$a['products'][0]]]);
        $q = $this->policy($a, ['scope' => 'product', 'value' => 50, 'targetProductIds' => [$a['products'][1]]]);
        DB::table('order_items')->where('id', $a['items'][1])->update(['deleted_at' => now()]);
        DB::table('order_items')->where('id', $b['items'][0])->update(['deleted_at' => now()]);
        $qa = $this->quote($a, $a['cash']);
        $qb = $this->quote($b, $b['cash']);
        $results = $this->race($a, [[$a, 'POST', '/pay', $this->payData($a, $qa, 'one')], [$b, 'POST', '/pay', $this->payData($b, $qb, 'two')]]);
        $this->assertSame([200, 200], array_column($results, 'status'), json_encode($results));
        $this->assertSame([$p, $q], DB::table('discount_usages')->orderBy('discount_id')->pluck('discount_id')->map(fn ($id) => (int) $id)->all());
        $this->assertDatabaseCount('order_discount_allocations', 2);
        $this->settlements(2, '5.00');
    }

    public function test_settings_first_creation_and_update_against_payment_include_fk_and_journal_locks(): void
    {
        foreach ([false, true] as $existing) {
            $f = $this->fixture();
            $this->policy($f);
            if ($existing) {
                $this->settings($f, []);
            }
            $quote = $this->quote($f, $f['cash']);
            $payload = array_replace(DiscountSettingsService::DEFAULTS, ['expectedVersion' => $existing ? 1 : 0, 'selectionStrategy' => 'priority']);
            $results = $this->race($f, [[$f, 'PUT', '/api/v1/cafe-configuration/discount-settings', $payload], [$f, 'POST', '/pay', $this->payData($f, $quote, 'settings-'.($existing ? 'update' : 'first'))]]);
            $this->assertSame(200, $results[0]['status'], json_encode($results));
            $this->assertContains($results[1]['status'], [200, 422], json_encode($results));
            if ($results[1]['status'] === 422) {
                $this->assertSame('ORDER_TOTAL_CHANGED', $results[1]['body']['code']);
            }
            $this->assertSame($existing ? 2 : 1, (int) DB::table('tenant_discount_settings')->where('tenant_id', $f['tenant'])->value('version'));
            $count = $results[1]['status'] === 200 ? 1 : 0;
            $this->assertSame($count, DB::table('payments')->where('order_id', $f['order'])->count());
            $this->assertSame($count, DB::table('discount_usages')->where('order_id', $f['order'])->count());
            $this->assertSame($count, DB::table('journal_entries')->where('tenant_id', $f['tenant'])->where('status', 'posted')->count());
        }
        $this->assertSame((string) DB::table('journal_entry_lines')->sum('debit'), (string) DB::table('journal_entry_lines')->sum('credit'));
    }

    public function test_policy_create_edit_against_payment_and_quote_observe_complete_candidate_set(): void
    {
        foreach ([false, true] as $edit) {
            $f = $this->fixture();
            $policy = $this->policy($f);
            $quote = $this->quote($f, $f['cash']);
            $payload = ['name' => 'New saving', 'applicationMode' => 'automatic', 'scope' => 'order', 'type' => 'percentage', 'value' => 50, 'isActive' => true, 'appliesToAllBranches' => true];
            $results = $this->race($f, [[$f, $edit ? 'PUT' : 'POST', '/api/v1/discounts'.($edit ? '/'.$policy : ''), $payload], [$f, 'POST', '/pay', $this->payData($f, $quote, $edit ? 'edit' : 'create')]]);
            $this->assertSame($edit ? 200 : 201, $results[0]['status'], json_encode($results));
            $this->assertContains($results[1]['status'], [200, 422], json_encode($results));
            if ($results[1]['status'] === 422) {
                $this->assertSame('ORDER_TOTAL_CHANGED', $results[1]['body']['code']);
            }
            $count = $results[1]['status'] === 200 ? 1 : 0;
            $this->assertSame($count, DB::table('payments')->where('order_id', $f['order'])->count());
            $this->assertSame($count, DB::table('discount_usages')->where('order_id', $f['order'])->count());
            if ($count) {
                $this->assertSame('18.00', DB::table('payments')->where('order_id', $f['order'])->value('amount'));
            }
            $this->assertSame($count, DB::table('journal_entries')->where('tenant_id', $f['tenant'])->where('status', 'posted')->count());
        }
    }

    public function test_concurrent_duplicate_operation_and_completed_payment_replay_are_durable(): void
    {
        $f = $this->fixture();
        $p = $this->policy($f, ['applicationMode' => 'manual']);
        $review = $this->preview($f, ['action' => 'apply', 'intent' => ['source' => 'configured_manual', 'discountId' => $p]]);
        $data = ['reviewId' => $review['reviewId'], 'operationId' => 'same-operation'];
        $results = $this->race($f, [[$f, 'POST', '/discounts/operations', $data], [$f, 'POST', '/discounts/operations', $data]]);
        $this->assertSame([200, 200], array_column($results, 'status'), json_encode($results));
        $this->assertSame($results[0]['body'], $results[1]['body']);
        $this->assertDatabaseCount('discount_operations', 1);
        $this->assertDatabaseCount('order_discounts', 1);
        $this->assertDatabaseCount('order_discount_allocations', 2);
        $quote = $this->quote($f, $f['cash']);
        $data = $this->payData($f, $quote, 'duplicate-pay');
        $results = $this->race($f, [[$f, 'POST', '/pay', $data], [$f, 'POST', '/pay', $data]]);
        $this->assertSame([200, 200], array_column($results, 'status'), json_encode($results));
        $this->assertSame($results[0]['body'], $results[1]['body']);
        $this->assertDatabaseCount('discount_usages', 1);
        $this->settlements(1, '18.00');
        $this->settings($f, ['selectionStrategy' => 'priority']);
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $data, $f['headers'])->assertOk()->assertJsonPath('data.payment.id', $results[0]['body']['data']['payment']['id']);
        $this->assertDatabaseCount('payments', 1);
    }

    public function test_policy_creation_and_quote_serialize_before_subsequent_payment(): void
    {
        $f = $this->fixture();
        $this->policy($f);
        $payload = ['name' => 'New saving', 'applicationMode' => 'automatic', 'scope' => 'order', 'type' => 'percentage', 'value' => 50, 'isActive' => true, 'appliesToAllBranches' => true];
        $results = $this->race($f, [[$f, 'POST', '/api/v1/discounts', $payload], [$f, 'POST', '/payment-quote', ['paymentMethodId' => $f['cash']]]]);
        $this->assertSame([201, 200], array_column($results, 'status'), json_encode($results));
        $quote = $results[1]['body']['data'];
        $payment = $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote, 'quote-race'), $f['headers']);
        if ($quote['totals']['total'] === '18.00') {
            $payment->assertUnprocessable()->assertJsonPath('code', 'ORDER_TOTAL_CHANGED');
            $this->settlements(0, '0.00');
            $this->assertDatabaseCount('discount_usages', 0);
            $this->assertDatabaseCount('order_discount_allocations', 0);
        } else {
            $this->assertSame('10.00', $quote['totals']['total']);
            $payment->assertOk();
            $this->settlements(1, '10.00');
            $this->assertDatabaseCount('discount_usages', 1);
            $this->assertDatabaseCount('order_discount_allocations', 2);
        }
    }

    public function test_concurrent_payment_identity_reuse_for_different_orders_is_a_stable_conflict(): void
    {
        $a = $this->fixture();
        $b = $this->anotherOrder($a);
        $this->policy($a);
        $qa = $this->quote($a, $a['cash']);
        $qb = $this->quote($b, $b['cash']);
        $results = $this->race($a, [[$a, 'POST', '/pay', $this->payData($a, $qa, 'tenant-key')], [$b, 'POST', '/pay', $this->payData($b, $qb, 'tenant-key')]]);
        $statuses = array_column($results, 'status');
        sort($statuses);
        $this->assertSame([200, 409], $statuses, json_encode($results));
        $this->assertSame('PAYMENT_IDEMPOTENCY_CONFLICT', collect($results)->firstWhere('status', 409)['body']['code']);
        $this->settlements(1, '18.00');
        $this->assertDatabaseCount('discount_usages', 1);
        $this->assertDatabaseCount('order_discounts', 1);
        $this->assertDatabaseCount('order_discount_allocations', 2);
    }

    public function test_apply_remove_suppression_and_cart_mutations_serialize_on_order_and_require_fresh_review(): void
    {
        $f = $this->fixture();
        $auto = $this->policy($f);
        $p = $this->policy($f, ['applicationMode' => 'manual']);
        $review = $this->preview($f, ['action' => 'apply', 'intent' => ['source' => 'configured_manual', 'discountId' => $p]]);
        $this->applyReview($f, $review, 'initial');
        foreach (['apply', 'remove', 'suppress', 'undo'] as $action) {
            $input = ['action' => $action, 'discountId' => $auto, 'reason' => 'Race reason', 'intent' => ['source' => 'configured_manual', 'discountId' => $p]];
            $review = $this->preview($f, $input);
            $results = $this->race($f, [[$f, 'POST', '/discounts/operations', ['reviewId' => $review['reviewId'], 'operationId' => 'race-'.$action]], [$f, 'PATCH', '/items/'.$f['items'][0], ['quantity' => 2]]]);
            $this->assertSame(200, $results[1]['status'], json_encode($results));
            $this->assertContains($results[0]['status'], [200, 422], json_encode($results));
            if ($results[0]['status'] === 422) {
                $this->assertSame('DISCOUNT_REVIEW_STALE', $results[0]['body']['code']);
            }
            $rows = DB::table('order_discounts')->where('order_id', $f['order'])->get();
            foreach ($rows as $row) {
                $this->assertSame((string) $row->discount_amount, (string) DB::table('order_discount_allocations')->where('order_discount_id', $row->id)->sum('amount'));
            }
            $expected = $this->resolution($f, app(DiscountResolutionService::class)->intent($f['tenant'], $f['order']));
            $this->assertSame($expected['totals']['discountTotal'], DB::table('orders')->find($f['order'])->discount_total);
            $this->assertDatabaseCount('discount_usages', 0);
        }
    }

    private function settlements(int $count, string $amount): void
    {
        $this->assertDatabaseCount('payments', $count);
        $this->assertSame($count, DB::table('orders')->where('payment_status', 'paid')->count());
        $this->assertSame($count, DB::table('journal_entries')->where('source_event', 'POS_ORDER_PAID')->where('status', 'posted')->count());
        foreach (DB::table('payments')->get() as $payment) {
            $this->assertSame($amount, $payment->amount);
        }
        $this->assertSame((string) DB::table('journal_entry_lines')->sum('debit'), (string) DB::table('journal_entry_lines')->sum('credit'));
    }

    public function test_bound_stock_payment_and_first_unbound_quote_have_no_warehouse_engine_wait_cycle(): void
    {
        $a = $this->stockFixture();
        $b = $this->anotherOrder($a);
        $this->policy($a);
        $qa = $this->quote($a, $a['cash']);
        $this->assertSame($a['warehouse'], (int) DB::table('orders')->find($a['order'])->warehouse_id);
        $this->assertNull(DB::table('orders')->find($b['order'])->warehouse_id);
        // anotherOrder copies sold item identities from the published fixture.
        $sold = DB::table('order_items')->find($a['items'][0]);
        DB::table('order_items')->where('id', $b['items'][0])->update(['product_variant_id' => $sold->product_variant_id, 'menu_item_placement_id' => $sold->menu_item_placement_id]);
        $workers = [];
        DB::select('select pg_advisory_lock(?, ?)', [20406, $a['tenant']]);
        try {
            $workers[] = $this->warehouseWorker($a, '/pay', $this->payData($a, $qa, 'warehouse-bound'), true);
            $paymentPid = $this->waitForWarehouseWorker($workers[0]['name'], (int) DB::selectOne('select pg_backend_pid() as pid')->pid);
            $workers[] = $this->warehouseWorker($b, '/payment-quote', ['paymentMethodId' => $b['cash']], false);
            $quotePid = $this->waitForWarehouseWorker($workers[1]['name'], $paymentPid);
            // Payment owns the engine gate; quote is physically waiting on it.
            // Before the correction, quote also owns warehouse FK KEY SHARE.
            DB::select('select pg_advisory_unlock(?, ?)', [20406, $a['tenant']]);
            $cycle = null;
            $exits = [];
            $deadline = microtime(true) + 25;
            do {
                DB::select('select pg_stat_clear_snapshot()');
                $graph = DB::selectOne('select ? = ANY(pg_blocking_pids(?)) as payment_waits_quote, ? = ANY(pg_blocking_pids(?)) as quote_waits_payment', [$quotePid, $paymentPid, $paymentPid, $quotePid]);
                if ($graph->payment_waits_quote && $graph->quote_waits_payment) {
                    $cycle = DB::select('select pid, application_name, wait_event_type, wait_event, query, pg_blocking_pids(pid) as blockers from pg_stat_activity where pid in (?, ?)', [$paymentPid, $quotePid]);
                    break;
                }
                foreach ($workers as $i => $worker) {
                    if (! array_key_exists($i, $exits)) {
                        $status = proc_get_status($worker['process']);
                        if (! $status['running']) {
                            $exits[$i] = $status['exitcode'];
                        }
                    }
                }
                if (count($exits) === count($workers)) {
                    break;
                }
            } while (microtime(true) < $deadline);
            // Capture the real wait cycle before PostgreSQL's deadlock timeout;
            // do not let framework retries turn a deadlock into a false pass.
            $this->assertNull($cycle, 'Actual warehouse/engine PostgreSQL wait cycle: '.json_encode($cycle));
            $this->assertCount(count($workers), $exits, 'Application workers must finish within the barrier deadline.');
            $results = [];
            foreach ($workers as $i => $worker) {
                $out = stream_get_contents($worker['pipes'][1]);
                $err = stream_get_contents($worker['pipes'][2]);
                $results[] = json_decode($out, true, flags: JSON_THROW_ON_ERROR);
                $this->assertSame('', $err);
                $this->assertSame(0, $exits[$i]);
            }
            $this->assertSame([200, 200], array_column($results, 'status'), json_encode($results));
            $this->assertSame($a['warehouse'], (int) DB::table('orders')->find($b['order'])->warehouse_id);
            $this->assertSame('18.00', $results[1]['body']['data']['totals']['total']);
            $this->postJson('/api/v1/orders/'.$b['order'].'/pay', $this->payData($b, $results[1]['body']['data'], 'warehouse-second'), $b['headers'])->assertOk();
            $this->settlements(2, '18.00');
            $this->assertDatabaseCount('discount_usages', 2);
            $this->assertDatabaseCount('sale_consumptions', 2);
            $this->assertSame(2, DB::table('stock_movements')->where('type', 'sale_consumption')->count());
            $this->assertSame('96.000', DB::table('stock_balances')->where('inventory_item_id', $a['material'])->value('quantity_on_hand'));
            foreach ([$a, $b] as $f) {
                $this->assertDatabaseHas('sale_consumptions', ['order_id' => $f['order'], 'warehouse_id' => $a['warehouse'], 'quantity_sold' => '1.000', 'cogs_total' => '4.00']);
                $this->assertDatabaseHas('orders', ['id' => $f['order'], 'cogs_total' => '4.00', 'gross_profit' => '14.00']);
            }
            // Rejection after entering the same actual inventory-capable path
            // must roll back payment, usage, snapshots, stock and journal work.
            $c = $this->anotherOrder($a);
            DB::table('orders')->where('id', $c['order'])->update(['status' => 'draft', 'payment_status' => 'unpaid', 'discount_total' => '0.00', 'total' => '20.00', 'cogs_total' => null, 'closed_at' => null]);
            DB::table('order_items')->where('id', $c['items'][0])->update(['product_variant_id' => $sold->product_variant_id, 'menu_item_placement_id' => $sold->menu_item_placement_id]);
            $qc = $this->quote($c, $c['cash']);
            $this->settings($c, ['maximumTotalDiscountPercent' => 1]);
            $this->postJson('/api/v1/orders/'.$c['order'].'/pay', $this->payData($c, $qc, 'warehouse-rejected'), $c['headers'])->assertUnprocessable()->assertJsonPath('code', 'ORDER_TOTAL_CHANGED');
            foreach (['payments', 'discount_usages', 'sale_consumptions', 'order_discounts'] as $table) {
                $this->assertSame(0, DB::table($table)->where('order_id', $c['order'])->count(), $table);
            }
            $this->assertSame(0, DB::table('journal_entries')->where('source_type', 'pos_order')->where('source_id', $c['order'])->count());
            $this->assertSame('96.000', DB::table('stock_balances')->where('inventory_item_id', $a['material'])->value('quantity_on_hand'));
            $this->assertSame(2, DB::table('stock_movements')->where('type', 'sale_consumption')->count());
            DB::table('tenant_settings')->updateOrInsert(['tenant_id' => $a['tenant']], ['settings' => json_encode(['allow_negative_stock_on_sale' => false])]);
            DB::table('stock_balances')->where('inventory_item_id', $a['material'])->update(['quantity_on_hand' => '0.000']);
            $fresh = $this->quote($c, $c['cash']);
            $this->postJson('/api/v1/orders/'.$c['order'].'/pay', $this->payData($c, $fresh, 'warehouse-stock-rejected'), $c['headers'])->assertUnprocessable();
            foreach (['payments', 'discount_usages', 'sale_consumptions', 'order_discounts', 'order_discount_allocations'] as $table) {
                $this->assertSame(0, DB::table($table)->where('order_id', $c['order'])->count(), $table);
            }
            $this->assertSame('unpaid', DB::table('orders')->find($c['order'])->payment_status);
            $this->assertSame('0.000', DB::table('stock_balances')->where('inventory_item_id', $a['material'])->value('quantity_on_hand'));
            $this->assertSame(2, DB::table('stock_movements')->where('type', 'sale_consumption')->count());
            $this->assertSame(0, DB::table('journal_entries')->where('source_type', 'pos_order')->where('source_id', $c['order'])->count());
        } finally {
            DB::select('select pg_advisory_unlock(?, ?)', [20406, $a['tenant']]);
            foreach ($workers as $worker) {
                proc_terminate($worker['process']);
                proc_close($worker['process']);
                foreach ($worker['pipes'] as $pipe) {
                    if (is_resource($pipe)) {
                        fclose($pipe);
                    }
                }
            }
        }
    }

    private function stockFixture(): array
    {
        $f = $this->fixture();
        $warehouse = (int) DB::table('branches')->find($f['branch'])->pos_inventory_warehouse_id;
        $material = DB::table('inventory_items')->insertGetId(['tenant_id' => $f['tenant'], 'name' => 'Race beans', 'sku' => 'RACE-BEANS', 'item_type' => 'raw_material', 'unit' => 'kg', 'is_active' => true]);
        DB::table('inventory_item_warehouses')->insert(['tenant_id' => $f['tenant'], 'inventory_item_id' => $material, 'warehouse_id' => $warehouse]);
        DB::table('stock_balances')->insert(['tenant_id' => $f['tenant'], 'inventory_item_id' => $material, 'warehouse_id' => $warehouse, 'quantity_on_hand' => '100.000', 'reserved_quantity' => 0, 'average_unit_cost' => '2.0000']);
        $category = DB::table('categories')->insertGetId(['tenant_id' => $f['tenant'], 'name' => 'Race coffee', 'is_active' => true]);
        DB::table('products')->where('id', $f['products'][0])->update(['is_stock_tracked' => true, 'category_id' => $category]);
        $variant = DB::table('product_variants')->insertGetId(['tenant_id' => $f['tenant'], 'product_id' => $f['products'][0], 'name' => 'Regular', 'base_price' => 10, 'is_default' => true, 'is_active' => true]);
        app(RecipeConfigurationService::class)->replaceRecipe(ProductVariant::findOrFail($variant), [['materialId' => $material, 'quantity' => '2.000', 'unitCode' => 'kg']]);
        $menu = DB::table('menus')->insertGetId(['tenant_id' => $f['tenant'], 'name' => 'Race menu', 'status' => 'draft']);
        $section = DB::table('menu_sections')->insertGetId(['tenant_id' => $f['tenant'], 'menu_id' => $menu, 'name' => 'Coffee', 'is_active' => true]);
        $placement = DB::table('menu_item_placements')->insertGetId(['tenant_id' => $f['tenant'], 'menu_section_id' => $section, 'product_id' => $f['products'][0], 'is_visible' => true]);
        DB::table('menu_assignments')->insert(['tenant_id' => $f['tenant'], 'menu_id' => $menu, 'branch_id' => $f['branch'], 'channel' => 'pos', 'is_active' => true]);
        $published = $this->postJson('/api/v1/admin/menu-management/publish', ['branchId' => $f['branch'], 'channel' => 'pos'], $f['headers']);
        $this->assertSame(200, $published->status(), (string) DB::table('menu_publications')->latest('id')->value('validation_result'));
        $version = $published->json('data.version.id');
        $snapshot = json_decode(DB::table('published_menu_versions')->find($version)->payload_json, true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame(3, $snapshot['context']['schemaVersion']);
        $this->assertSame($material, $snapshot['menus'][0]['sections'][0]['products'][0]['variants'][0]['baseRecipe'][0]['materialId']);
        DB::table('orders')->where('id', $f['order'])->update(['published_menu_version_id' => $version]);
        DB::table('order_items')->where('id', $f['items'][0])->update(['product_variant_id' => $variant, 'menu_item_placement_id' => $placement]);

        return $f + compact('warehouse', 'material');
    }

    private function warehouseWorker(array $f, string $suffix, array $data, bool $pause): array
    {
        $name = uniqid('warehouse-engine-');
        $payload = ['workerName' => $name, 'token' => $f['token'], 'path' => '/api/v1/orders/'.$f['order'].$suffix, 'method' => 'POST', 'data' => $data];
        if ($pause) {
            $payload['pauseAfterEngineLock'] = $f['tenant'];
        }
        $env = array_merge(getenv() ?: [], ['APP_ENV' => 'testing', 'DB_DATABASE' => 'cafe_system_618_testing_migrations', 'DB_URL' => '']);
        $process = proc_open([PHP_BINARY, base_path('tests/Fixtures/DiscountEngineWorker.php'), base64_encode(json_encode($payload))], [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path(), $env);
        $this->assertIsResource($process);

        return compact('name', 'process', 'pipes');
    }

    private function waitForWarehouseWorker(string $name, int $blocker): int
    {
        $deadline = microtime(true) + 20;
        do {
            DB::select('select pg_stat_clear_snapshot()');
            $state = DB::selectOne('select pid from pg_stat_activity where application_name = ? and ? = ANY(pg_blocking_pids(pid))', [$name, $blocker]);
            if ($state) {
                return (int) $state->pid;
            }
        } while (microtime(true) < $deadline);
        $this->fail('The independent application worker did not reach its observable PostgreSQL barrier: '.$name);
    }

    /** Physical PostgreSQL wait graph barrier, never sleep-based timing. */
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
