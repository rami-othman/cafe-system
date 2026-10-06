<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\DiscountEngineFixture;
use Tests\TestCase;

class DiscountEngineIntentRoundTripTest extends TestCase
{
    use DiscountEngineFixture, RefreshDatabase;

    public function test_configured_jsonb_round_trip_can_apply_quote_and_settle_but_changed_intent_is_stale(): void
    {
        foreach (['fixed' => '2.50', 'percentage' => '12.50'] as $type => $value) {
            $f = $this->fixture();
            config(['discount_engine.isolated_automatic' => false]);
            $policy = $this->policy($f, ['applicationMode' => 'manual', 'type' => $type, 'value' => $value]);
            $intent = ['source' => 'configured_manual', 'discountId' => $policy];
            $review = $this->preview($f, ['action' => 'apply', 'intent' => $intent]);
            $stored = json_decode(DB::table('discount_reviews')->where('identity', $review['reviewId'])->value('payload'), true, flags: JSON_THROW_ON_ERROR);
            $this->assertSame('configured_manual', $stored['intent']['source']);
            $this->assertSame($policy, $stored['intent']['discountId']);
            $saved = $this->applyReview($f, $review, 'jsonb-'.$type);
            $this->assertSame('2.50', $saved['totals']['discountTotal']);
            $this->assertSame('17.50', $saved['totals']['total']);
            $this->assertEquals($saved, $this->applyReview($f, $review, 'jsonb-'.$type));
            $quote = $this->quote($f, $f['cash']);
            $this->assertSame('17.50', $quote['totals']['total']);
            $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote, 'jsonb-payment-'.$type), $f['headers'])->assertOk()->assertJsonPath('data.payment.amount', 17.5);

            $other = $this->fixture();
            config(['discount_engine.isolated_automatic' => false]);
            $originalPolicy = $this->policy($other, ['applicationMode' => 'manual', 'type' => $type, 'value' => $value]);
            $replacement = $this->policy($other, ['applicationMode' => 'manual', 'type' => $type, 'value' => $type === 'fixed' ? '3.00' : '15.00']);
            $intent = ['source' => 'configured_manual', 'discountId' => $originalPolicy];
            $stale = $this->preview($other, ['action' => 'apply', 'intent' => $intent]);
            $payload = json_decode(DB::table('discount_reviews')->where('identity', $stale['reviewId'])->value('payload'), true, flags: JSON_THROW_ON_ERROR);
            $payload['intent']['discountId'] = $replacement;
            DB::table('discount_reviews')->where('identity', $stale['reviewId'])->update(['payload' => json_encode($payload, JSON_THROW_ON_ERROR)]);
            $this->postJson('/api/v1/orders/'.$other['order'].'/discounts/operations', ['reviewId' => $stale['reviewId'], 'operationId' => 'changed-'.$type], $other['headers'])->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_REVIEW_STALE');
            $this->assertDatabaseMissing('discount_operations', ['tenant_id' => $other['tenant'], 'identity' => 'changed-'.$type]);
            $this->assertSame('0.00', DB::table('orders')->where('id', $other['order'])->value('discount_total'));
        }
    }
}
