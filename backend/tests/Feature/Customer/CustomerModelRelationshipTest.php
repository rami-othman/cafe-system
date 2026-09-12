<?php

namespace Tests\Feature\Customer;

use App\Models\Customer;
use App\Models\CustomerGroup;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CustomerModelRelationshipTest extends TestCase
{
    use RefreshDatabase;

    public function test_models_are_tenant_scoped_and_archive_keeps_phone_and_membership_rows(): void
    {
        $now = now();
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Model Tenant', 'slug' => 'model-'.uniqid(), 'created_at' => $now, 'updated_at' => $now]);
        $customer = Customer::create(['tenant_id' => $tenant, 'name' => 'Customer', 'customer_number' => 'C-120001', 'normalized_name' => 'customer']);
        $group = CustomerGroup::create(['tenant_id' => $tenant, 'name' => 'Regulars', 'normalized_name' => 'regulars']);
        DB::table('customer_phones')->insert(['tenant_id' => $tenant, 'customer_id' => $customer->id, 'raw_number' => '091234567', 'normalized_number' => '091234567', 'type' => 'mobile', 'is_primary' => true, 'validation_status' => 'unverified', 'created_at' => $now, 'updated_at' => $now]);
        DB::table('customer_group_memberships')->insert(['tenant_id' => $tenant, 'customer_id' => $customer->id, 'customer_group_id' => $group->id, 'created_at' => $now, 'updated_at' => $now]);

        $customer->delete();

        $this->assertCount(1, DB::table('customer_phones')->where('customer_id', $customer->id)->get());
        $this->assertCount(1, DB::table('customer_group_memberships')->where('customer_id', $customer->id)->get());
        $this->assertSame('archived', Customer::withTrashed()->findOrFail($customer->id)->lifecycleState());
        $this->assertCount(0, Customer::forTenant($tenant)->get());
        $this->assertSame($tenant, Customer::withTrashed()->forTenant($tenant)->value('tenant_id'));
    }
}
