<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\DefaultTenantRoleService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Concerns\DiscountEngineFixture;
use Tests\TestCase;

class DiscountAdHocRemovalTest extends TestCase
{
    use DiscountEngineFixture, RefreshDatabase;

    public function test_all_tenant_roles_cannot_create_free_discounts_even_with_the_legacy_grant(): void
    {
        $f = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);
        $before = (array) DB::table('orders')->find($f['order']);
        $roles = app(DefaultTenantRoleService::class)->ensureForTenant($f['tenant']);
        foreach (['owner', 'manager', 'employee'] as $role) {
            $headers = $f['headers'];
            if ($role !== 'owner') {
                $actor = User::query()->create([
                    'tenant_id' => $f['tenant'], 'tenant_role_id' => $roles[$role]->id,
                    'name' => $role, 'email' => $role.'-'.Str::uuid().'@example.test',
                    'password' => 'testing-password', 'role' => $role === 'employee' ? 'cashier' : $role,
                    'is_active' => true, 'must_change_password' => false,
                ]);
                DB::table('user_branches')->insert(['tenant_id' => $f['tenant'], 'user_id' => $actor->id, 'branch_id' => $f['branch']]);
                $headers['Authorization'] = 'Bearer '.$this->authenticateTenantUser($f['tenant'], $actor);
            }
            foreach (['fixed' => '2.50', 'percentage' => '12.50'] as $type => $value) {
                $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', [
                    'action' => 'apply', 'intent' => ['source' => 'ad_hoc', 'type' => $type, 'value' => $value],
                ], $headers)->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_AD_HOC_DISABLED');
                $this->putJson('/api/v1/orders/'.$f['order'].'/discount', compact('type', 'value'), $headers)
                    ->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_AD_HOC_DISABLED');
            }
        }
        $this->assertSame($before, (array) DB::table('orders')->find($f['order']));
        foreach (['discount_reviews', 'discount_operations', 'order_discount_intents', 'order_discounts', 'discount_usages', 'payments', 'journal_entries'] as $table) {
            $this->assertDatabaseCount($table, 0);
        }
    }

    public function test_an_outstanding_free_discount_review_cannot_be_confirmed(): void
    {
        $f = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);
        $identity = (string) Str::uuid();
        DB::table('discount_reviews')->insert([
            'tenant_id' => $f['tenant'], 'order_id' => $f['order'], 'identity' => $identity,
            'fingerprint' => str_repeat('a', 64),
            'payload' => json_encode(['action' => 'apply', 'intent' => $this->legacyIntent(), 'paymentMethodId' => null]),
            'result' => '{}', 'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/operations', [
            'reviewId' => $identity, 'operationId' => 'pending-free-discount',
        ], $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_AD_HOC_DISABLED');
        $this->assertDatabaseCount('discount_operations', 0);
        $this->assertDatabaseCount('order_discounts', 0);
        $this->assertDatabaseCount('order_discount_intents', 0);
        $this->assertSame('20.00', DB::table('orders')->find($f['order'])->total);
    }

    public function test_saved_legacy_free_discount_can_still_quote_settle_and_read_its_receipt(): void
    {
        $f = $this->legacyOrder();
        $this->getJson('/api/v1/orders/'.$f['order'].'/discount-state', $f['headers'])
            ->assertOk()->assertJsonPath('data.discounts.0.source', 'ad_hoc')->assertJsonPath('data.discounts.0.amount', '2.50');
        $quote = $this->quote($f, $f['cash']);
        $this->assertSame('17.50', $quote['totals']['total']);
        $this->postJson('/api/v1/orders/'.$f['order'].'/pay', $this->payData($f, $quote, 'legacy-free-payment'), $f['headers'])
            ->assertOk()->assertJsonPath('data.payment.amount', 17.5);
        $paid = (array) DB::table('orders')->find($f['order']);
        $snapshots = DB::table('order_discounts')->where('order_id', $f['order'])->get()->toJson();
        $this->getJson('/api/v1/orders/'.$f['order'].'/receipt', $f['headers'])
            ->assertOk()->assertJsonPath('data.discounts.0.source', 'ad_hoc')->assertJsonPath('data.discounts.0.amount', '2.50');
        $this->assertSame($paid, (array) DB::table('orders')->find($f['order']));
        $this->assertSame($snapshots, DB::table('order_discounts')->where('order_id', $f['order'])->get()->toJson());
        $this->assertDatabaseCount('payments', 1);
        $this->assertDatabaseCount('discount_usages', 0);
    }

    public function test_saved_legacy_free_discount_can_be_explicitly_removed(): void
    {
        $f = $this->legacyOrder();
        $saved = $this->applyReview($f, $this->preview($f, ['action' => 'remove']), 'remove-legacy-free');
        $this->assertNull($saved['explicitIntent']);
        $this->assertSame([], $saved['discounts']);
        $this->assertSame('20.00', $saved['totals']['total']);
        $this->assertDatabaseCount('payments', 0);
    }

    public function test_completed_free_discount_operation_replays_without_creating_another_discount(): void
    {
        $f = $this->legacyOrder();
        $reviewId = (string) Str::uuid();
        $saved = $this->getJson('/api/v1/orders/'.$f['order'].'/discount-state', $f['headers'])->assertOk()->json('data');
        $saved['operationId'] = 'completed-free';
        DB::table('discount_operations')->insert([
            'tenant_id' => $f['tenant'], 'order_id' => $f['order'], 'identity' => 'completed-free',
            'fingerprint' => hash('sha256', json_encode(['orderId' => $f['order'], 'reviewId' => $reviewId], JSON_THROW_ON_ERROR)),
            'payload' => json_encode(['reviewId' => $reviewId]), 'result' => json_encode($saved),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        // Replay returns the persisted JSONB result, including its canonical key order.
        $storedResult = json_decode(DB::table('discount_operations')->where('identity', 'completed-free')->value('result'), true, flags: JSON_THROW_ON_ERROR);
        $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/operations', [
            'reviewId' => $reviewId, 'operationId' => 'completed-free',
        ], $f['headers'])->assertOk()->assertJsonPath('data', $storedResult);
        $this->assertDatabaseCount('discount_operations', 1);
        $this->assertDatabaseCount('order_discounts', 1);
        $this->assertSame('17.50', DB::table('orders')->find($f['order'])->total);
    }

    private function legacyIntent(): array
    {
        return ['source' => 'ad_hoc', 'type' => 'fixed', 'value' => '2.50', 'name' => 'Historical adjustment'];
    }

    private function legacyOrder(): array
    {
        $f = $this->fixture();
        config(['discount_engine.isolated_automatic' => false]);
        DB::table('orders')->where('id', $f['order'])->update(['discount_total' => '2.50', 'total' => '17.50']);
        DB::table('order_discounts')->insert([
            'tenant_id' => $f['tenant'], 'order_id' => $f['order'], 'source' => 'ad_hoc', 'stage' => 'order',
            'discount_name' => 'Historical adjustment', 'discount_type' => 'fixed',
            'discount_value' => '2.50', 'discount_amount' => '2.50', 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('order_discount_intents')->insert([
            'tenant_id' => $f['tenant'], 'order_id' => $f['order'], 'intent' => json_encode($this->legacyIntent()),
            'created_at' => now(), 'updated_at' => now(),
        ]);

        return $f;
    }
}
