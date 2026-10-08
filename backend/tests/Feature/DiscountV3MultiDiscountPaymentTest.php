<?php

namespace Tests\Feature;

use App\Services\DiscountEligibilityService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\DiscountEngineFixture;
use Tests\TestCase;

/**
 * Discount System V3 Phase 2: quote -> payment safety, usage accounting,
 * settlement, history and refunds for orders with several discounts.
 */
class DiscountV3MultiDiscountPaymentTest extends TestCase
{
    use DiscountEngineFixture;
    use RefreshDatabase;

    private function manual(array $f, array $changes = []): int
    {
        return $this->policy($f, array_replace(['applicationMode' => 'manual'], $changes));
    }

    private function m(int $id): array
    {
        return ['source' => 'configured_manual', 'discountId' => $id];
    }

    /** Multi-discount cafe with two stacked order-level discounts applied (10% then 20% = 5.60 of 20.00). */
    private function stacked(array $f, array $a = [], array $b = []): array
    {
        $this->settings($f, ['allowMultipleDiscounts' => true, 'maximumDiscountsPerOrder' => 3, 'stackingMode' => 'same_item_allowed']);
        $first = $this->manual($f, $a + ['value' => 10]);
        $second = $this->manual($f, $b + ['value' => 20]);
        $this->applyReview($f, $this->preview($f, ['action' => 'set', 'intents' => [$this->m($first), $this->m($second)]]), 'stack-'.uniqid());

        return [$first, $second];
    }

    private function pay(array $f, array $quote, string $key = 'multi-payment')
    {
        return $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote, $key), $f['headers']);
    }

    private function otherOrder(array $f, ?int $customer = null): array
    {
        $row = (array) DB::table('orders')->find($f['order']);
        unset($row['id']);
        $row['order_number'] = uniqid('ENGINE-');
        $row['customer_id'] = $customer;
        $row = array_replace($row, ['status' => 'draft', 'payment_status' => 'unpaid', 'closed_at' => null, 'subtotal' => '20.00', 'discount_total' => '0.00', 'total' => '20.00']);
        $f['order'] = DB::table('orders')->insertGetId($row);
        foreach ($f['products'] as $product) {
            DB::table('order_items')->insert(['tenant_id' => $f['tenant'], 'order_id' => $f['order'], 'product_id' => $product, 'product_name' => 'Pinned', 'quantity' => 1, 'unit_price' => 10, 'total' => 10]);
        }

        return $f;
    }

    private function customer(array $f): int
    {
        return (int) DB::table('customers')->insertGetId(['tenant_id' => $f['tenant'], 'name' => 'Customer', 'customer_number' => 'C-'.uniqid(), 'normalized_name' => 'customer-'.uniqid(), 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }

    public function test_quote_to_payment_consumes_one_usage_per_discount_and_retry_is_idempotent(): void
    {
        $f = $this->fixture();
        [$a, $b] = $this->stacked($f);
        $quote = $this->quote($f, $f['cash']);
        $this->assertSame([$a, $b], array_column($quote['discounts'], 'discountId'));
        $this->assertSame(['subtotal' => '20.00', 'discountTotal' => '5.60', 'taxTotal' => '0.00', 'total' => '14.40'], $quote['totals']);
        $this->assertSame([], $quote['excluded']);
        $this->assertSame(300, $quote['expiresInSeconds']);

        $paid = $this->pay($f, $quote)->assertOk()->json('data');
        $this->assertDatabaseCount('payments', 1);
        $this->assertSame('14.40', DB::table('payments')->value('amount'));
        $this->assertSame([$a, $b], DB::table('discount_usages')->where('order_id', $f['order'])->orderBy('discount_id')->pluck('discount_id')->map(fn ($v) => (int) $v)->all());
        $this->assertSame([1, 1], DB::table('discounts')->whereIn('id', [$a, $b])->orderBy('id')->pluck('used_count')->map(fn ($v) => (int) $v)->all());
        $this->assertSame((string) DB::table('journal_entry_lines')->sum('debit'), (string) DB::table('journal_entry_lines')->sum('credit'));

        // Retrying payment replays; consuming again never adds a second usage for the same order+discount.
        $this->pay($f, $quote)->assertOk()->assertJsonPath('data', $paid);
        DB::transaction(fn () => app(DiscountEligibilityService::class)->consumeUsage($f['tenant'], DB::table('orders')->find($f['order']), (int) DB::table('payments')->value('id')));
        $this->assertDatabaseCount('discount_usages', 2);
        $this->assertDatabaseCount('order_discounts', 2);
        $this->assertSame([1, 1], DB::table('discounts')->whereIn('id', [$a, $b])->orderBy('id')->pluck('used_count')->map(fn ($v) => (int) $v)->all());
    }

    public function test_changed_order_discount_or_policy_makes_the_quote_stale(): void
    {
        $f = $this->fixture();
        [$a] = $this->stacked($f);

        $quote = $this->quote($f, $f['cash']);
        DB::table('order_items')->where('id', $f['items'][0])->update(['total' => '12.00', 'unit_price' => '12.00']);
        $this->pay($f, $quote, 'stale-order')->assertUnprocessable()->assertJsonPath('code', 'ORDER_TOTAL_CHANGED');
        DB::table('order_items')->where('id', $f['items'][0])->update(['total' => '10.00', 'unit_price' => '10.00']);

        $quote = $this->quote($f, $f['cash']);
        DB::table('discounts')->where('id', $a)->update(['value' => 15]);
        $this->pay($f, $quote, 'stale-discount')->assertUnprocessable()->assertJsonPath('code', 'ORDER_TOTAL_CHANGED');
        DB::table('discounts')->where('id', $a)->update(['value' => 10]);

        // Any policy change is part of runtime validity, even one that happens to leave the money identical.
        $quote = $this->quote($f, $f['cash']);
        $this->settings($f, ['maximumDiscountsPerOrder' => 4]);
        $this->pay($f, $quote, 'stale-policy-count')->assertUnprocessable()->assertJsonPath('code', 'ORDER_TOTAL_CHANGED');

        $quote = $this->quote($f, $f['cash']);
        $this->settings($f, ['allowMultipleDiscounts' => false]);
        $this->pay($f, $quote, 'stale-policy')->assertUnprocessable()->assertJsonPath('code', 'ORDER_TOTAL_CHANGED');
        foreach (['payments', 'discount_usages'] as $table) {
            $this->assertDatabaseCount($table, 0);
        }

        // The refreshed quote follows the new policy: one discount, the other reported as excluded.
        $fresh = $this->quote($f, $f['cash']);
        $this->assertCount(1, $fresh['discounts']);
        $this->assertSame('MULTIPLE_DISCOUNTS_DISABLED', $fresh['excluded'][0]['code']);
        $this->assertFalse($fresh['policy']['allowMultipleDiscounts']);
        $this->pay($f, $fresh, 'fresh')->assertOk();
        $this->assertDatabaseCount('discount_usages', 1);
        $this->assertDatabaseCount('order_discounts', 1);
    }

    public function test_payment_revalidates_every_discount_in_the_set(): void
    {
        $f = $this->fixture();
        [, $b] = $this->stacked($f);
        $quote = $this->quote($f, $f['cash']);
        DB::table('discounts')->where('id', $b)->update(['is_active' => false]);
        $this->pay($f, $quote, 'inactive')->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_INACTIVE');
        $this->assertDatabaseCount('payments', 0);
        $this->assertDatabaseCount('discount_usages', 0);
    }

    public function test_global_usage_limit_reached_before_payment_blocks_it_without_partial_effects(): void
    {
        $f = $this->fixture();
        [, $b] = $this->stacked($f, [], ['usageLimit' => 1]);
        $quote = $this->quote($f, $f['cash']);
        $other = $this->otherOrder($f);
        DB::table('discount_usages')->insert(['tenant_id' => $f['tenant'], 'discount_id' => $b, 'order_id' => $other['order'], 'business_date' => now()->toDateString(), 'created_at' => now(), 'updated_at' => now()]);
        $this->pay($f, $quote, 'limit')->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_USAGE_LIMIT_REACHED');
        $this->assertDatabaseCount('payments', 0);
        $this->assertSame(0, DB::table('discount_usages')->where('order_id', $f['order'])->count());
    }

    public function test_customer_lifetime_and_daily_limits_apply_per_discount(): void
    {
        $f = $this->fixture();
        $customer = $this->customer($f);
        DB::table('orders')->where('id', $f['order'])->update(['customer_id' => $customer]);
        [$lifetime, $daily] = $this->stacked($f, ['usageLimitPerCustomer' => 1], ['perCustomerDailyUsageLimit' => 1]);
        $this->pay($f, $this->quote($f, $f['cash']), 'first-order')->assertOk();
        $this->assertSame(2, DB::table('discount_usages')->where('customer_id', $customer)->count());

        $second = $this->otherOrder($f, $customer);
        $this->postJson('/api/v1/orders/'.$second['order'].'/discounts/preview', ['action' => 'set', 'intents' => [$this->m($lifetime)]], $f['headers'])
            ->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_USAGE_LIMIT_REACHED');
        $this->postJson('/api/v1/orders/'.$second['order'].'/discounts/preview', ['action' => 'set', 'intents' => [$this->m($daily)]], $f['headers'])
            ->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_DAILY_USAGE_LIMIT_REACHED');

        // A different customer is unaffected.
        $third = $this->otherOrder($f, $this->customer($f));
        $this->postJson('/api/v1/orders/'.$third['order'].'/discounts/preview', ['action' => 'set', 'intents' => [$this->m($lifetime), $this->m($daily)]], $f['headers'])->assertOk();
    }

    public function test_discounts_that_reduce_the_order_to_zero_settle_without_a_tender(): void
    {
        $f = $this->fixture();
        $this->settings($f, ['allowMultipleDiscounts' => true, 'maximumDiscountsPerOrder' => 3, 'stackingMode' => 'same_item_allowed']);
        $a = $this->manual($f, ['type' => 'fixed', 'value' => 12]);
        $b = $this->manual($f, ['type' => 'fixed', 'value' => 8]);
        $this->applyReview($f, $this->preview($f, ['action' => 'set', 'intents' => [$this->m($a), $this->m($b)]]), 'zero');
        $quote = $this->quote($f, $f['cash']);
        $this->assertSame('0.00', $quote['totals']['total']);
        $this->assertSame('20.00', $quote['totals']['discountTotal']);
        $this->pay($f, $quote, 'zero-pay')->assertOk()->assertJsonPath('data.payment.method', 'zero_balance');
        $this->assertSame(2, DB::table('discount_usages')->where('order_id', $f['order'])->count());
        $this->assertSame('paid', DB::table('orders')->find($f['order'])->payment_status);
        $this->assertSame((string) DB::table('journal_entry_lines')->sum('debit'), (string) DB::table('journal_entry_lines')->sum('credit'));
    }

    public function test_history_receipt_and_paid_orders_are_pinned_against_later_policy_changes(): void
    {
        $f = $this->fixture();
        [$a, $b] = $this->stacked($f);
        $this->pay($f, $this->quote($f, $f['cash']), 'history')->assertOk();
        $rows = DB::table('order_discounts')->where('order_id', $f['order'])->get()->map(fn ($r) => (array) $r)->all();
        $totals = (array) DB::table('orders')->find($f['order']);

        $order = $this->getJson('/api/v1/orders/'.$f['order'], $f['headers'])->assertOk()->assertJsonPath('data.discount', null)->assertJsonPath('data.requiresDiscountBreakdown', true)->assertJsonCount(2, 'data.discounts')->json('data');
        $this->assertSame([$a, $b], array_column($order['discounts'], 'discountId'));
        $this->assertSame([1, 2], array_column($order['discounts'], 'sequence'));
        $this->assertSame(['2.00', '3.60'], array_column($order['discounts'], 'amount'));
        $receipt = $this->getJson('/api/v1/orders/'.$f['order'].'/receipt', $f['headers'])->assertOk()->json('data');
        $this->assertCount(2, $receipt['discounts'] ?? $receipt['order']['discounts'] ?? []);

        $this->settings($f, ['allowMultipleDiscounts' => false, 'conflictResolution' => 'priority']);
        DB::table('discounts')->whereIn('id', [$a, $b])->update(['value' => 99, 'is_active' => false]);
        $this->assertSame($rows, DB::table('order_discounts')->where('order_id', $f['order'])->get()->map(fn ($r) => (array) $r)->all());
        $this->assertSame($totals, (array) DB::table('orders')->find($f['order']));
        $after = $this->getJson('/api/v1/orders/'.$f['order'], $f['headers'])->assertOk()->json('data');
        $this->assertSame($order['discounts'], $after['discounts']);
        $this->assertSame($order['totals'], $after['totals']);
    }

    public function test_refund_uses_the_paid_net_amount_and_leaves_discount_allocations_alone(): void
    {
        $f = $this->fixture();
        $this->stacked($f);
        $this->pay($f, $this->quote($f, $f['cash']), 'refund-pay')->assertOk();
        $snapshot = DB::table('order_discounts')->where('order_id', $f['order'])->get()->map(fn ($r) => (array) $r)->all();
        $allocations = DB::table('order_discount_allocations')->orderBy('id')->get()->map(fn ($r) => (array) $r)->all();

        $url = '/api/v1/orders/'.$f['order'].'/refunds';
        $this->postJson($url, ['type' => 'partial', 'amount' => 5, 'reason' => 'Partial', 'idempotencyKey' => 'r1'], $f['headers'])->assertCreated();
        $this->postJson($url, ['type' => 'partial', 'amount' => 10, 'reason' => 'Too much', 'idempotencyKey' => 'r2'], $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'REFUND_EXCEEDS_REMAINING');
        $this->settings($f, ['allowMultipleDiscounts' => false]);
        $full = $this->postJson($url, ['type' => 'full', 'reason' => 'Rest', 'idempotencyKey' => 'r3'], $f['headers'])->assertCreated()->json('data');
        $this->assertEquals(9.4, $full['amount']);
        $this->assertSame('refunded', DB::table('orders')->find($f['order'])->payment_status);
        $this->assertSame('14.40', (string) DB::table('payment_refunds')->sum('amount'));
        $this->assertSame($snapshot, DB::table('order_discounts')->where('order_id', $f['order'])->get()->map(fn ($r) => (array) $r)->all());
        $this->assertSame($allocations, DB::table('order_discount_allocations')->orderBy('id')->get()->map(fn ($r) => (array) $r)->all());
        $this->assertSame((string) DB::table('journal_entry_lines')->sum('debit'), (string) DB::table('journal_entry_lines')->sum('credit'));
    }

    public function test_legacy_single_discount_clients_keep_replace_semantics_and_cannot_edit_multi_orders(): void
    {
        $f = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);
        $legacy = ['Authorization' => 'Bearer '.$f['token']];
        $this->settings($f, ['allowMultipleDiscounts' => true, 'maximumDiscountsPerOrder' => 3, 'stackingMode' => 'same_item_allowed']);
        $a = $this->manual($f, ['value' => 10]);
        $b = $this->manual($f, ['value' => 20]);

        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/apply', ['discountId' => $a], $legacy)->assertOk();
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/apply', ['discountId' => $b], $legacy)->assertOk()->assertJsonPath('data.totals.discountTotal', 4);
        $this->assertSame([$b], DB::table('order_discounts')->pluck('discount_id')->map(fn ($v) => (int) $v)->all(), 'The legacy endpoint replaces; it is never additive.');
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', ['method' => 'cash', 'amount' => '100.00', 'idempotencyKey' => 'legacy-pay'], $legacy)->assertOk();
        $this->assertSame([$b], DB::table('discount_usages')->pluck('discount_id')->map(fn ($v) => (int) $v)->all());

        $second = $this->otherOrder($f);
        $this->applyReview($second, $this->preview($second, ['action' => 'set', 'intents' => [$this->m($a), $this->m($b)]]), 'multi-for-legacy');
        $this->postJson('/api/v1/orders/'.$second['order'].'/discounts/apply', ['discountId' => $a], $legacy)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_CLIENT_UPDATE_REQUIRED');
        $this->assertDatabaseCount('order_discounts', 3);
    }

    public function test_capabilities_and_payment_summary_describe_the_multi_discount_contract(): void
    {
        $f = $this->fixture();
        $this->stacked($f);
        $capabilities = $this->getJson('/api/v1/discount-capabilities', $f['headers'])->assertOk()->json('data');
        $this->assertTrue($capabilities['supportsMultipleDiscounts']);
        $this->assertSame(10, $capabilities['maximumRequestedDiscounts']);
        $this->assertSame(3, $capabilities['policy']['effectiveMaximumDiscounts']);
        $this->assertFalse($capabilities['automaticEnabled'] && ! config('discount_engine.isolated_automatic'), 'Automatic Discounts stay disabled.');
        $this->getJson('/api/v1/orders/'.$f['order'].'/payment-summary', $f['headers'])->assertOk()->assertJsonCount(2, 'data.discounts');
    }
}
