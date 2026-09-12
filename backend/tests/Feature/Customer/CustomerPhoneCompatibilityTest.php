<?php

namespace Tests\Feature\Customer;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CustomerPhoneCompatibilityTest extends TestCase
{
    use RefreshDatabase;

    public function test_multiple_phones_have_exactly_one_primary_and_mirror_raw_primary_phone(): void
    {
        [$tenant, $token] = $this->admin();
        $response = $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers', [
            'name' => 'Phones',
            'phones' => [
                ['rawNumber' => '+963 991234567', 'type' => 'mobile', 'isPrimary' => true],
                ['rawNumber' => '091234568', 'type' => 'home', 'isPrimary' => false],
            ],
        ])->assertCreated();
        $id = $response->json('data.id');
        $response->assertJsonCount(2, 'data.phones');
        $this->assertSame(1, collect($response->json('data.phones'))->where('isPrimary', true)->count());
        $this->assertDatabaseHas('customers', ['id' => $id, 'phone' => '+963 991234567']);

        $this->withToken($token)->putJson('/api/v1/admin/customer-management/customers/'.$id, ['phones' => [
            ['rawNumber' => '+963 991234567', 'type' => 'mobile', 'isPrimary' => false],
            ['rawNumber' => '091234568', 'type' => 'home', 'isPrimary' => true],
        ]])->assertOk();
        $updated = $this->withToken($token)->getJson('/api/v1/admin/customer-management/customers/'.$id)->json('data.phones');
        $this->assertSame('091234568', collect($updated)->firstWhere('isPrimary', true)['rawNumber']);
        $this->assertDatabaseHas('customers', ['id' => $id, 'phone' => '091234568']);

        $this->withToken($token)->putJson('/api/v1/admin/customer-management/customers/'.$id, ['phones' => []])->assertOk()->assertJsonCount(0, 'data.phones');
        $this->assertDatabaseHas('customers', ['id' => $id, 'phone' => null]);
    }

    public function test_duplicate_normalized_phone_in_one_collection_rolls_back_but_shared_phone_across_customers_is_allowed(): void
    {
        [$tenant, $token] = $this->admin();
        $first = $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers', ['name' => 'First', 'phones' => [['rawNumber' => '091234567', 'isPrimary' => true]]])->assertCreated();
        $id = $first->json('data.id');
        $this->withToken($token)->putJson('/api/v1/admin/customer-management/customers/'.$id, ['phones' => [
            ['rawNumber' => '091234567', 'isPrimary' => true],
            ['rawNumber' => '۰۹۱۲۳۴۵۶۷', 'isPrimary' => false],
        ]])->assertUnprocessable();
        $this->assertSame(1, DB::table('customer_phones')->where('customer_id', $id)->count());
        $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers', ['name' => 'Second', 'phones' => [['rawNumber' => '091234567', 'isPrimary' => true]]])->assertCreated();
        $this->assertSame(2, DB::table('customer_phones')->where('normalized_number', '091234567')->count());
    }

    public function test_phone_audit_projection_does_not_copy_raw_or_normalized_numbers(): void
    {
        [$tenant, $token] = $this->admin();
        $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers', ['name' => 'Audited', 'phones' => [['rawNumber' => '+963 991234567', 'isPrimary' => true]]])->assertCreated();
        $audit = DB::table('activity_logs')->where('tenant_id', $tenant)->where('entity_type', 'customer')->latest('id')->first();
        $this->assertStringNotContainsString('991234567', (string) $audit->after_state);
        $this->assertStringNotContainsString('963', (string) $audit->after_state);
    }

    private function admin(): array
    {
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => 'Phone Tenant', 'slug' => 'phone-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $owner = User::query()->create(['tenant_id' => $tenant, 'name' => 'Owner', 'email' => uniqid().'@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true, 'must_change_password' => false]);

        return [$tenant, $this->authenticateTenantUser($tenant, $owner)];
    }
}
