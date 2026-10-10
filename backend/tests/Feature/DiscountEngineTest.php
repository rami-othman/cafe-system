<?php

namespace Tests\Feature;

use App\Domain\Discount\DiscountAccess;
use App\Models\User;
use App\Services\DiscountResolutionService;
use App\Services\PosPricingService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\Concerns\DiscountEngineFixture;
use Tests\TestCase;

class DiscountEngineTest extends TestCase
{
    use DiscountEngineFixture, RefreshDatabase;

    public function test_actual_saving_caps_priority_ties_and_zero_automatic(): void
    {
        $f = $this->fixture();
        $zero = $this->policy($f, ['value' => 0, 'priority' => 10]);
        $low = $this->policy($f, ['value' => 90, 'maximumDiscountAmount' => '1.00', 'priority' => 5]);
        $high = $this->policy($f, ['value' => 20, 'priority' => 5]);
        $this->assertSame($high, $this->resolution($f)['discounts'][0]['discountId']);
        $this->settings($f, ['selectionStrategy' => 'lowest_saving']);
        $this->assertSame($low, $this->resolution($f)['discounts'][0]['discountId']);
        $this->settings($f, ['selectionStrategy' => 'priority']);
        $this->assertSame($low, $this->resolution($f)['discounts'][0]['discountId']);
        $this->settings($f, ['maximumTotalDiscountPercent' => 2]);
        $result = $this->resolution($f);
        $this->assertSame($low, $result['discounts'][0]['discountId']);
        $this->assertSame('0.40', $result['totals']['discountTotal']);
        $this->assertNotSame($zero, $result['discounts'][0]['discountId']);
        $this->assertDatabaseCount('discount_usages', 0);
    }

    public function test_greedy_recalculation_per_order_fractional_units_and_positive_reservations(): void
    {
        $f = $this->fixture();
        $this->settings($f, ['combinationMode' => 'disjoint_items']);
        $a = $this->policy($f, ['scope' => 'product', 'type' => 'fixed', 'value' => 7, 'targetProductIds' => $f['products']]);
        $b = $this->policy($f, ['scope' => 'product', 'value' => 50, 'targetProductIds' => [$f['products'][0]]]);
        $result = $this->resolution($f);
        $this->assertSame([$a], array_column($result['discounts'], 'discountId'));
        $this->assertSame('7.00', $result['totals']['discountTotal']);
        $this->settings($f, ['selectionStrategy' => 'lowest_saving']);
        $result = $this->resolution($f);
        $this->assertSame([$b, $a], array_column($result['discounts'], 'discountId'));
        $this->assertSame('12.00', $result['totals']['discountTotal']);
        DB::table('discounts')->where('id', $a)->update(['fixed_amount_basis' => 'per_unit', 'value' => '2.01']);
        DB::table('discounts')->where('id', $b)->update(['is_active' => false]);
        DB::table('order_items')->where('id', $f['items'][0])->update(['quantity' => '1.500', 'total' => '15.00']);
        $this->assertSame('5.03', $this->resolution($f)['totals']['discountTotal']);
        // One cent is allocated to the lower item ID only. The other identity
        // remains available to a later policy rather than being reserved.
        DB::table('discounts')->where('id', $a)->update(['fixed_amount_basis' => 'per_order', 'value' => '0.01']);
        DB::table('discounts')->where('id', $b)->update(['is_active' => true]);
        $this->assertSame('0.01', $this->resolution($f)['discounts'][0]['amount']);
        $this->assertSame($f['items'][0], $this->resolution($f)['discounts'][0]['allocations'][0]['orderItemId']);
    }

    public function test_largest_remainder_is_exact_and_safe_for_large_products(): void
    {
        $engine = app(DiscountResolutionService::class);
        $this->assertSame([10 => 1], $engine->allocate(1, [11 => 1, 10 => 1]));
        $parts = $engine->allocate(999999999999, [5 => 500000000000, 3 => 500000000000]);
        $this->assertSame(999999999999, array_sum($parts));
        $this->assertSame(500000000000, $parts[3]);
    }

    public function test_tiny_global_budget_half_up_and_existing_tax_semantics(): void
    {
        $f = $this->fixture();
        $this->policy($f, ['value' => 100]);
        DB::table('orders')->where('id', $f['order'])->update(['tax_rate' => '0.15']);
        $this->settings($f, ['maximumTotalDiscountPercent' => '0.0250']);
        $result = $this->resolution($f);
        $this->assertSame(['subtotal' => '20.00', 'discountTotal' => '0.01', 'taxTotal' => '3.00', 'total' => '22.99'], $result['totals']);
        $this->assertSame([['orderItemId' => $f['items'][0], 'amount' => '0.01']], $result['discounts'][0]['allocations']);
        $this->settings($f, ['maximumTotalDiscountPercent' => '0.0001']);
        $result = $this->resolution($f);
        $this->assertSame([], $result['discounts']);
        $this->assertSame('0.00', $result['totals']['discountTotal']);
        $this->assertSame('23.00', $result['totals']['total']);
    }

    public function test_engine_snapshot_without_quote_still_prohibits_destructive_rollback(): void
    {
        $f = $this->fixture();
        $this->policy($f);
        DB::transaction(fn () => app(PosPricingService::class)->recalculateOrder($f['tenant'], $f['order']));
        $this->assertDatabaseCount('discount_payment_quotes', 0);
        $migration = require database_path('migrations/2026_10_03_000003_create_discount_engine_protocol.php');
        try {
            $migration->down();
            $this->fail('Engine snapshots must prevent rollback before any schema drop.');
        } catch (\RuntimeException $exception) {
            $this->assertSame('Engine snapshots exist; roll forward.', $exception->getMessage());
        }
        $this->assertDatabaseCount('order_discounts', 1);
        $this->assertDatabaseCount('order_discount_allocations', 2);
        $this->assertTrue(Schema::hasTable('discount_payment_quotes'));
        $this->assertTrue(Schema::hasColumn('discounts', 'priority'));
    }

    public function test_after_items_residual_original_minimum_and_group_order_comparison(): void
    {
        $f = $this->fixture();
        $this->settings($f, ['combinationMode' => 'disjoint_items']);
        $a = $this->policy($f, ['scope' => 'product', 'value' => 50, 'targetProductIds' => [$f['products'][0]]]);
        $b = $this->policy($f, ['scope' => 'product', 'value' => 50, 'targetProductIds' => [$f['products'][1]]]);
        $whole = $this->policy($f, ['value' => 50, 'minimumOrderAmount' => 20]);
        $this->assertSame([$whole], array_column($this->resolution($f)['discounts'], 'discountId'));
        $this->settings($f, ['combinationMode' => 'disjoint_items', 'orderDiscountBehavior' => 'after_items']);
        $result = $this->resolution($f);
        $this->assertSame([$a, $b, $whole], array_column($result['discounts'], 'discountId'));
        $this->assertSame('15.00', $result['totals']['discountTotal']);
        $this->assertSame('order', $result['discounts'][2]['stage']);
        $this->assertSame('2.50', $result['discounts'][2]['allocations'][0]['amount']);
        $this->settings($f, ['combinationMode' => 'disjoint_items', 'orderDiscountBehavior' => 'after_items', 'maximumTotalDiscountPercent' => 60]);
        $this->assertSame('12.00', $this->resolution($f)['totals']['discountTotal']);
    }

    public function test_explicit_zero_coupon_is_preserved_and_removal_discovers_automatic(): void
    {
        $f = $this->fixture();
        $auto = $this->policy($f, ['value' => 50]);
        $code = $this->policy($f, ['applicationMode' => 'code', 'code' => 'PRIVATE-SECRET', 'value' => 0]);
        $review = $this->preview($f, ['action' => 'apply', 'intent' => ['source' => 'code', 'code' => 'private-secret']]);
        $this->assertSame('0.00', $review['totals']['discountTotal']);
        $this->assertSame($code, $review['discounts'][0]['discountId']);
        $this->assertStringNotContainsString('PRIVATE-SECRET', json_encode($review));
        $this->applyReview($f, $review);
        foreach (['discount_reviews', 'discount_operations', 'order_discount_intents', 'order_discounts', 'activity_logs'] as $table) {
            $this->assertStringNotContainsString('PRIVATE-SECRET', json_encode(DB::table($table)->get()));
        }
        $removed = $this->applyReview($f, $this->preview($f, ['action' => 'remove']), 'remove-explicit');
        $this->assertSame($auto, $removed['discounts'][0]['discountId']);
        $this->getJson('/api/v1/discounts/available?orderId='.$f['order'], $f['headers'])->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_invalid_explicit_intent_is_not_silently_replaced_during_cart_recalculation(): void
    {
        $f = $this->fixture();
        $auto = $this->policy($f, ['value' => 50]);
        $manual = $this->policy($f, ['applicationMode' => 'manual']);
        $this->applyReview($f, $this->preview($f, ['action' => 'apply', 'intent' => ['source' => 'configured_manual', 'discountId' => $manual]]));
        DB::table('discounts')->where('id', $manual)->update(['is_active' => false]);
        DB::transaction(fn () => app(PosPricingService::class)->recalculateOrder($f['tenant'], $f['order']));
        $this->assertDatabaseCount('order_discounts', 0);
        $this->assertSame('0.00', DB::table('orders')->find($f['order'])->discount_total);
        $this->assertSame($manual, app(DiscountResolutionService::class)->intent($f['tenant'], $f['order'])['discountId']);
        $this->getJson('/api/v1/orders/'.$f['order'].'/discount-state', $f['headers'])->assertOk()->assertJsonPath('data.explicitIntent.discountId', $manual)->assertJsonCount(0, 'data.discounts');
        $this->postJson('/api/v1/orders/'.$f['order'].'/payment-quote', ['paymentMethodId' => $f['cash']], $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_INACTIVE');
        $removed = $this->applyReview($f, $this->preview($f, ['action' => 'remove']), 'remove-invalid');
        $this->assertSame($auto, $removed['discounts'][0]['discountId']);
        $this->assertSame('10.00', $removed['totals']['discountTotal']);
        $this->assertDatabaseCount('discount_usages', 0);
    }

    public function test_explicit_item_reservation_and_saved_legacy_ad_hoc_after_items(): void
    {
        $f = $this->fixture();
        $this->settings($f, ['combinationMode' => 'disjoint_items', 'manualBehavior' => 'follow_combination_rules']);
        $manual = $this->policy($f, ['applicationMode' => 'manual', 'scope' => 'product', 'value' => 10, 'targetProductIds' => [$f['products'][0]]]);
        $auto = $this->policy($f, ['scope' => 'product', 'value' => 50, 'targetProductIds' => [$f['products'][1]]]);
        $this->policy($f, ['value' => 90]);
        $result = $this->resolution($f, ['source' => 'configured_manual', 'discountId' => $manual]);
        $this->assertSame([$manual, $auto], array_column($result['discounts'], 'discountId'));
        $this->settings($f, ['combinationMode' => 'disjoint_items', 'orderDiscountBehavior' => 'after_items', 'manualBehavior' => 'follow_combination_rules']);
        $result = $this->resolution($f, ['source' => 'ad_hoc', 'type' => 'percentage', 'value' => '50.00']);
        $this->assertSame('12.50', $result['totals']['discountTotal']);
        $this->assertSame('ad_hoc', $result['discounts'][1]['source']);
    }

    public function test_review_stale_replay_recovery_and_identity_conflict(): void
    {
        $f = $this->fixture();
        $manual = $this->policy($f, ['applicationMode' => 'manual']);
        $input = ['action' => 'apply', 'intent' => ['source' => 'configured_manual', 'discountId' => $manual]];
        $review = $this->preview($f, $input);
        DB::table('order_items')->where('id', $f['items'][0])->update(['total' => '11.00']);
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/operations', ['reviewId' => $review['reviewId'], 'operationId' => 'stale'], $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_REVIEW_STALE');
        $review = $this->preview($f, $input);
        $applied = $this->applyReview($f, $review, 'same');
        $this->assertSame($applied, $this->applyReview($f, $review, 'same'));
        $this->assertDatabaseCount('order_discounts', 1);
        $this->assertSame(1, DB::table('activity_logs')->where('action', 'discount.engine.apply')->count());
        $this->getJson('/api/v1/orders/'.$f['order'].'/discount-operations/same', $f['headers'])->assertOk()->assertJsonPath('data.completed', true)->assertJsonPath('data.result', $applied);
        $other = $this->preview($f, ['action' => 'remove']);
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/operations', ['reviewId' => $other['reviewId'], 'operationId' => 'same'], $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_OPERATION_CONFLICT');
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', ['action' => 'apply', 'intent' => ['source' => 'ad_hoc', 'type' => 'fixed', 'value' => '99999999999999']], $f['headers'])->assertUnprocessable()->assertJsonValidationErrors('intent.value');
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', ['action' => 'apply', 'intent' => ['source' => 'ad_hoc', 'type' => 'fixed', 'value' => '1.00', 'reason' => str_repeat('r', 256)]], $f['headers'])->assertUnprocessable()->assertJsonValidationErrors('intent.reason');
    }

    public function test_suppression_survives_cart_mutations_until_explicit_undo_and_does_not_transfer(): void
    {
        $f = $this->fixture();
        $auto = $this->policy($f);
        $review = $this->preview($f, ['action' => 'suppress', 'discountId' => $auto, 'reason' => 'Manager reason']);
        $this->applyReview($f, $review);
        DB::table('order_items')->where('id', $f['items'][0])->update(['quantity' => 2, 'total' => '20.00']);
        DB::transaction(fn () => app(PosPricingService::class)->recalculateOrder($f['tenant'], $f['order']));
        $this->assertSame('0.00', DB::table('orders')->find($f['order'])->discount_total);
        $this->assertDatabaseCount('order_discount_suppressions', 1);
        $other = (array) DB::table('orders')->find($f['order']);
        unset($other['id']);
        $other['order_number'] = uniqid('OTHER-');
        $otherId = DB::table('orders')->insertGetId($other);
        foreach (DB::table('order_items')->where('order_id', $f['order'])->get() as $item) {
            $copy = (array) $item;
            unset($copy['id']);
            $copy['order_id'] = $otherId;
            DB::table('order_items')->insert($copy);
        }
        $this->assertSame('3.00', $this->resolution(array_replace($f, ['order' => $otherId]))['totals']['discountTotal']);
        $this->assertDatabaseMissing('order_discount_suppressions', ['order_id' => $otherId]);
        $undo = $this->applyReview($f, $this->preview($f, ['action' => 'undo', 'discountId' => $auto]), 'undo');
        $this->assertSame('3.00', $undo['totals']['discountTotal']);
        $this->assertDatabaseCount('order_discount_suppressions', 0);
        DB::table('orders')->where('id', $f['order'])->update(['payment_status' => 'paid', 'status' => 'paid']);
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', ['action' => 'suppress', 'discountId' => $auto, 'reason' => 'Forbidden'], $f['headers'])->assertUnprocessable();
    }

    public function test_suppression_permission_setting_and_reason_boundaries(): void
    {
        $f = $this->fixture();
        $auto = $this->policy($f);
        $input = ['action' => 'suppress', 'discountId' => $auto, 'reason' => 'Reason'];
        $employee = User::create(['tenant_id' => $f['tenant'], 'role' => 'employee', 'name' => 'Employee', 'email' => uniqid().'@test.example', 'password' => 'testing-password', 'is_active' => true]);
        DB::table('user_branches')->insert(['tenant_id' => $f['tenant'], 'branch_id' => $f['branch'], 'user_id' => $employee->id]);
        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($f['tenant'], $employee), 'X-Discount-Contract' => '2'];
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', $input, $headers)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_SUPPRESSION_FORBIDDEN');
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', array_replace($input, ['reason' => '  ']), $f['headers'])->assertUnprocessable();
        $manager = User::create(['tenant_id' => $f['tenant'], 'role' => 'manager', 'name' => 'Manager', 'email' => uniqid().'@test.example', 'password' => 'testing-password', 'is_active' => true]);
        DB::table('user_branches')->insert(['tenant_id' => $f['tenant'], 'branch_id' => $f['branch'], 'user_id' => $manager->id]);
        $managerHeaders = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($f['tenant'], $manager), 'X-Discount-Contract' => '2'];
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', $input, $managerHeaders)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_SUPPRESSION_FORBIDDEN');
        $this->putJson('/api/v1/discounts/role-permissions/manager', ['permissions' => [...DiscountAccess::CATALOG, DiscountAccess::SUPPRESS_AUTOMATIC]], $f['headers'])->assertOk();
        $review = $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', $input, $managerHeaders)->assertOk()->json('data');
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/operations', ['operationId' => 'manager-suppression', 'reviewId' => $review['reviewId']], $managerHeaders)->assertOk();
        $this->assertDatabaseHas('order_discount_suppressions', ['order_id' => $f['order'], 'suppressed_by' => $manager->id, 'reason' => 'Reason']);
        $this->applyReview($f, $this->preview($f, ['action' => 'undo', 'discountId' => $auto]), 'owner-undo');
        $this->settings($f, ['allowAutomaticSuppression' => false]);
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', $input, $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_SUPPRESSION_DISABLED');
        $this->assertDatabaseCount('order_discount_suppressions', 0);
        $this->assertDatabaseMissing('discount_role_permissions', ['role' => 'employee', 'permission' => DiscountAccess::SUPPRESS_AUTOMATIC]);
    }

    public function test_policy_automatic_priority_clear_hydration_and_public_creation(): void
    {
        $f = $this->fixture();
        $code = $this->policy($f, ['applicationMode' => 'code', 'code' => 'SECRET', 'priority' => 4]);
        $payload = ['name' => 'Changed', 'applicationMode' => 'automatic', 'type' => 'fixed', 'scope' => 'order', 'value' => 2, 'isActive' => true, 'appliesToAllBranches' => true];
        $this->putJson('/api/v1/discounts/'.$code, $payload, $f['headers'])->assertUnprocessable()->assertJsonValidationErrors('code');
        $payload['code'] = null;
        $this->putJson('/api/v1/discounts/'.$code, $payload, $f['headers'])->assertOk()->assertJsonPath('data.priority', 4)->assertJsonPath('data.code', null);
        $this->getJson('/api/v1/discounts/'.$code, $f['headers'])->assertOk()->assertJsonPath('data.applicationMode', 'automatic');
        config(['discount_engine.isolated_automatic' => false]);
        // Public rollout: promotions can be created; each cafe still opts in.
        $this->postJson('/api/v1/discounts', $payload, $f['headers'])->assertCreated()->assertJsonPath('data.applicationMode', 'automatic');
        $this->getJson('/api/v1/discount-capabilities', $f['headers'])->assertOk()->assertJsonPath('data.engineReady', true)->assertJsonPath('data.automaticEnabled', false)->assertJsonPath('data.automaticPolicyCreationAvailable', true);
        $this->assertDatabaseHas('discounts', ['id' => $code, 'deleted_at' => null]);
    }

    public function test_quote_new_policy_and_settings_invalidate_even_lower_totals_and_no_partial_effects(): void
    {
        $f = $this->fixture();
        $this->policy($f, ['value' => 10]);
        $quote = $this->quote($f, $f['cash']);
        $this->policy($f, ['value' => 50]);
        $url = '/api/v1/orders/'.$f['order'].'/pay';
        $this->postJson($url, $this->payData($f, $quote), $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'ORDER_TOTAL_CHANGED');
        foreach (['payments', 'discount_usages', 'sale_consumptions', 'stock_movements', 'journal_entries', 'order_discounts'] as $table) {
            $this->assertSame(0, DB::table($table)->count(), $table);
        }
        $quote = $this->quote($f, $f['cash']);
        $this->settings($f, ['selectionStrategy' => 'lowest_saving']);
        $this->postJson($url, $this->payData($f, $quote), $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'ORDER_TOTAL_CHANGED');
        $this->assertDatabaseCount('payments', 0);
    }

    public function test_tender_provisional_changes_invalid_mappings_and_zero_balance(): void
    {
        $f = $this->fixture();
        $policy = $this->policy($f, ['value' => 100, 'paymentMethodIds' => [$f['cash']]]);
        $quote = $this->quote($f);
        $this->assertTrue($quote['provisional']);
        $this->assertSame('20.00', $quote['totals']['total']);
        $this->assertSame([], $quote['discounts']);
        $card = $this->quote($f, $f['card']);
        $this->assertSame('20.00', $card['totals']['total']);
        $cash = $this->quote($f, $f['cash']);
        $this->assertSame('0.00', $cash['totals']['total']);
        $changed = $this->payData($f, $cash);
        $changed['paymentMethodId'] = $f['card'];
        $changed['method'] = 'card';
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $changed, $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'ORDER_TOTAL_CHANGED');
        $this->postJson('/api/v1/orders/'.$f['order'].'/payment-quote', ['paymentMethodId' => 999999], $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'PAYMENT_METHOD_INVALID');
        $foreign = $this->fixture();
        $foreignAccount = DB::table('payment_methods')->where('id', $foreign['cash'])->value('financial_account_id');
        DB::table('payment_methods')->where('id', $f['card'])->update(['financial_account_id' => $foreignAccount]);
        $this->postJson('/api/v1/orders/'.$f['order'].'/payment-quote', ['paymentMethodId' => $f['card']], $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'PAYMENT_METHOD_INVALID');
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $cash), $f['headers'])->assertOk()->assertJsonPath('data.payment.method', 'zero_balance');
        $this->assertDatabaseHas('discount_usages', ['tenant_id' => $f['tenant'], 'order_id' => $f['order'], 'discount_id' => $policy]);
    }

    public function test_multiple_policy_settlement_usage_snapshots_metrics_refund_and_replay(): void
    {
        $f = $this->fixture();
        $this->settings($f, ['combinationMode' => 'disjoint_items']);
        $a = $this->policy($f, ['scope' => 'product', 'value' => 50, 'targetProductIds' => [$f['products'][0]]]);
        $b = $this->policy($f, ['scope' => 'product', 'value' => 20, 'targetProductIds' => [$f['products'][1]]]);
        $quote = $this->quote($f, $f['cash']);
        $data = $this->payData($f, $quote);
        $paid = $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $data, $f['headers'])->assertOk()->json('data');
        $this->assertDatabaseCount('payments', 1);
        $this->assertDatabaseCount('discount_usages', 2);
        $this->assertDatabaseCount('order_discount_allocations', 2);
        $this->assertSame('7.00', DB::table('orders')->find($f['order'])->discount_total);
        $snapshot = DB::table('order_discounts')->where('order_id', $f['order'])->get()->map(fn ($r) => (array) $r)->all();
        $this->settings($f, ['selectionStrategy' => 'priority']);
        DB::table('discounts')->whereIn('id', [$a, $b])->update(['value' => 0]);
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $data, $f['headers'])->assertOk()->assertJsonPath('data', $paid);
        $this->getJson('/api/v1/discounts/metrics', $f['headers'])->assertOk()->assertJsonPath('data.actualSavedValueThisMonth', 7);
        $this->getJson('/api/v1/orders/'.$f['order'], $f['headers'])->assertOk()->assertJsonPath('data.discount', null)->assertJsonCount(2, 'data.discounts')->assertJsonPath('data.requiresDiscountBreakdown', true);
        $this->postJson('/api/v1/orders/'.$f['order'].'/refunds', ['type' => 'partial', 'amount' => 1, 'reason' => 'Refund', 'idempotencyKey' => 'engine-refund'], $f['headers'])->assertCreated();
        $this->assertSame($snapshot, DB::table('order_discounts')->where('order_id', $f['order'])->get()->map(fn ($r) => (array) $r)->all());
        $this->assertDatabaseCount('discount_usages', 2);
        $this->assertSame(2, DB::table('journal_entries')->where('status', 'posted')->count());
        $this->assertSame((string) DB::table('journal_entry_lines')->sum('debit'), (string) DB::table('journal_entry_lines')->sum('credit'));
    }

    public function test_category_overlap_and_bundle_exclusivity_preserve_existing_bundle_amount(): void
    {
        $f = $this->fixture();
        $category = DB::table('categories')->insertGetId(['tenant_id' => $f['tenant'], 'name' => 'Category', 'is_active' => true]);
        DB::table('products')->whereIn('id', $f['products'])->update(['category_id' => $category]);
        $this->settings($f, ['combinationMode' => 'disjoint_items', 'orderDiscountBehavior' => 'after_items']);
        $categoryPolicy = $this->policy($f, ['scope' => 'category', 'value' => 50, 'targetCategoryIds' => [$category]]);
        $this->policy($f, ['scope' => 'product', 'value' => 40, 'targetProductIds' => [$f['products'][0]]]);
        $bundle = $this->policy($f, ['scope' => 'bundle', 'type' => 'fixed', 'value' => 12, 'bundleRequirements' => [['productId' => $f['products'][0], 'quantity' => 1], ['productId' => $f['products'][1], 'quantity' => 1]]]);
        $result = $this->resolution($f);
        $this->assertSame([$bundle], array_column($result['discounts'], 'discountId'));
        $this->assertSame('12.00', $result['totals']['discountTotal']);
        DB::table('discounts')->where('id', $bundle)->update(['is_active' => false]);
        $this->assertSame([$categoryPolicy], array_column($this->resolution($f)['discounts'], 'discountId'));
        $this->assertSame('10.00', $this->resolution($f)['totals']['discountTotal']);
    }

    public function test_discovery_uses_persisted_variants_branch_channel_customer_schedule_and_usage(): void
    {
        $f = $this->fixture();
        $variant = DB::table('product_variants')->insertGetId(['tenant_id' => $f['tenant'], 'product_id' => $f['products'][0], 'name' => 'Selected', 'is_active' => true]);
        DB::table('order_items')->where('id', $f['items'][0])->update(['product_variant_id' => $variant]);
        $p = $this->policy($f, ['scope' => 'product', 'value' => 50, 'targetProductIds' => [$f['products'][0]], 'productVariantSelections' => [['productId' => $f['products'][0], 'variantMode' => 'selected', 'variantIds' => [$variant]]], 'channelKeys' => ['pos'], 'appliesToAllBranches' => false, 'branchIds' => [$f['branch']]]);
        $this->assertSame($p, $this->resolution($f)['discounts'][0]['discountId']);
        DB::table('order_items')->where('id', $f['items'][0])->update(['product_variant_id' => null]);
        $this->assertSame([], $this->resolution($f)['discounts']);
        DB::table('order_items')->where('id', $f['items'][0])->update(['product_variant_id' => $variant]);
        DB::table('orders')->where('id', $f['order'])->update(['sales_channel' => 'delivery']);
        $this->assertSame([], $this->resolution($f)['discounts']);
        DB::table('orders')->where('id', $f['order'])->update(['sales_channel' => 'pos']);
        DB::table('discounts')->where('id', $p)->update(['customer_eligibility' => 'selected_customers']);
        $customer = DB::table('customers')->insertGetId(['tenant_id' => $f['tenant'], 'name' => 'Customer', 'customer_number' => uniqid('C-'), 'normalized_name' => uniqid('customer-'), 'is_active' => true]);
        DB::table('discount_targets')->insert(['tenant_id' => $f['tenant'], 'discount_id' => $p, 'target_type' => 'customer', 'target_id' => $customer]);
        $this->assertSame([], $this->resolution($f)['discounts']);
        DB::table('orders')->where('id', $f['order'])->update(['customer_id' => $customer]);
        $this->assertSame('5.00', $this->resolution($f)['totals']['discountTotal']);
        $this->travelTo(CarbonImmutable::parse('2026-10-03 23:30:00', 'Asia/Damascus'));
        DB::table('discounts')->where('id', $p)->update(['active_days' => json_encode(['Sat']), 'start_time' => '22:00', 'end_time' => '02:00', 'start_date' => '2026-10-03', 'end_date' => '2026-10-03']);
        $this->assertSame('5.00', $this->resolution($f)['totals']['discountTotal']);
        $this->travelTo(CarbonImmutable::parse('2026-10-04 00:30:00', 'Asia/Damascus'));
        $this->assertSame([], $this->resolution($f)['discounts']);
        $this->travelBack();
        DB::table('discounts')->where('id', $p)->update(['active_days' => null, 'start_time' => null, 'end_time' => null, 'start_date' => null, 'end_date' => null, 'usage_limit' => 1]);
        $quote = $this->quote($f, $f['cash']);
        DB::table('discount_usages')->insert(['tenant_id' => $f['tenant'], 'order_id' => $f['order'], 'discount_id' => $p, 'customer_id' => $customer]);
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote), $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'ORDER_TOTAL_CHANGED');
        $this->assertDatabaseCount('payments', 0);
        $this->assertDatabaseCount('journal_entries', 0);
    }

    public function test_automatic_expiry_and_explicit_pending_tender_zero_cannot_bypass_method(): void
    {
        $f = $this->fixture();
        $this->travelTo(CarbonImmutable::parse('2026-10-03 23:59:00', 'Asia/Damascus'));
        $auto = $this->policy($f, ['endDate' => '2026-10-03']);
        $quote = $this->quote($f, $f['cash']);
        $this->travelTo(CarbonImmutable::parse('2026-10-04 00:01:00', 'Asia/Damascus'));
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote), $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'ORDER_TOTAL_CHANGED');
        $this->travelBack();
        DB::table('discounts')->where('id', $auto)->update(['is_active' => false]);
        $manual = $this->policy($f, ['applicationMode' => 'manual', 'value' => 100, 'paymentMethodIds' => [$f['cash']]]);
        $this->applyReview($f, $this->preview($f, ['action' => 'apply', 'intent' => ['source' => 'configured_manual', 'discountId' => $manual]]));
        $quote = $this->quote($f);
        $this->assertTrue($quote['provisional']);
        $this->assertSame('0.00', $quote['totals']['total']);
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote), $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'PAYMENT_TENDER_REQUIRED');
        $this->assertDatabaseCount('payments', 0);
        $this->assertDatabaseCount('discount_usages', 0);
    }

    public function test_old_client_rejected_before_automatic_mutations_payment_and_summary_remains_read_only(): void
    {
        $f = $this->fixture();
        $this->policy($f);
        $old = ['Authorization' => $f['headers']['Authorization']];
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', ['method' => 'cash', 'amount' => 100, 'idempotencyKey' => 'old'], $old)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_CLIENT_UPDATE_REQUIRED');
        $this->putJson('/api/v1/orders/'.$f['order'].'/discount', ['type' => 'fixed', 'value' => 1], $old)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_AD_HOC_DISABLED');
        $before = (array) DB::table('orders')->find($f['order']);
        $this->getJson('/api/v1/orders/'.$f['order'].'/payment-summary', $old)->assertOk()->assertJsonPath('data.totalDue', 20);
        $this->assertSame($before, (array) DB::table('orders')->find($f['order']));
        $this->assertDatabaseCount('order_discounts', 0);
    }
}
