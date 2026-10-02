<?php

namespace Tests\Feature\Customer;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** The owner sets, per customer, how far the wallet may go below zero; nobody else can. */
class CustomerWalletLimitTest extends TestCase
{
    use RefreshDatabase;

    public function test_only_the_owner_sets_the_wallet_limit_and_it_is_shown_on_the_customer(): void
    {
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Wallet Tenant', 'slug' => 'wallet-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $owner = User::query()->create(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => uniqid().'@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true, 'must_change_password' => false]);
        $token = $this->authenticateTenantUser($tenant, $owner);
        $id = $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers', ['name' => 'عميل المحفظة', 'phones' => [['rawNumber' => '091234567', 'isPrimary' => true]]])->assertCreated()->json('data.id');

        $this->withToken($token)->getJson("/api/v1/admin/customer-management/customers/{$id}")->assertOk()
            ->assertJsonPath('data.walletCreditLimit', '0.00')->assertJsonPath('data.walletBalance', '0.00');
        $this->withToken($token)->putJson("/api/v1/admin/customer-management/customers/{$id}/wallet-limit", ['walletCreditLimit' => '250.50'])->assertOk()
            ->assertJsonPath('data.walletCreditLimit', '250.50')->assertJsonPath('data.walletAvailable', '250.50');
        $this->withToken($token)->putJson("/api/v1/admin/customer-management/customers/{$id}/wallet-limit", ['walletCreditLimit' => '-5'])->assertUnprocessable();
        $this->assertSame(1, DB::table('activity_logs')->where('tenant_id', $tenant)->where('action', 'sales.customer.wallet_limit_changed')->count());
    }
}
