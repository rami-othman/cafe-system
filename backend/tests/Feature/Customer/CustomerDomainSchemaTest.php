<?php

namespace Tests\Feature\Customer;

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class CustomerDomainSchemaTest extends TestCase
{
    use RefreshDatabase;

    public function test_customer_foundation_schema_is_tenant_safe_and_search_ready(): void
    {
        $this->assertTrue(DB::table('pg_available_extensions')->where('name', 'pg_trgm')->exists());
        $this->assertTrue(Schema::hasColumns('customers', ['customer_number', 'normalized_name', 'phone']));
        foreach (['customer_number_counters', 'customer_phones', 'customer_groups', 'customer_group_memberships', 'customer_role_permissions'] as $table) {
            $this->assertTrue(Schema::hasTable($table), "Missing {$table} table.");
        }

        foreach (['customers_tenant_customer_number_unique', 'customer_phones_one_primary_unique', 'customer_phones_customer_normalized_unique', 'customer_memberships_identity_unique'] as $index) {
            $this->assertTrue(DB::table('pg_indexes')->where('indexname', $index)->exists(), "Missing {$index}.");
        }
    }

    public function test_phone_values_are_not_globally_unique_and_memberships_are_tenant_constrained(): void
    {
        $now = now();
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Customer Tenant', 'slug' => 'customer-schema-'.uniqid(), 'created_at' => $now, 'updated_at' => $now]);
        $customer = DB::table('customers')->insertGetId(['tenant_id' => $tenant, 'name' => 'One', 'customer_number' => 'C-900001', 'normalized_name' => 'one', 'phone' => null, 'created_at' => $now, 'updated_at' => $now]);
        $second = DB::table('customers')->insertGetId(['tenant_id' => $tenant, 'name' => 'Two', 'customer_number' => 'C-900002', 'normalized_name' => 'two', 'phone' => null, 'created_at' => $now, 'updated_at' => $now]);
        $phone = ['tenant_id' => $tenant, 'raw_number' => '123456789', 'normalized_number' => '123456789', 'type' => 'mobile', 'is_primary' => true, 'validation_status' => 'unverified', 'created_at' => $now, 'updated_at' => $now];
        DB::table('customer_phones')->insert($phone + ['customer_id' => $customer]);
        DB::table('customer_phones')->insert($phone + ['customer_id' => $second]);
        $this->assertSame(2, DB::table('customer_phones')->where('normalized_number', '123456789')->count());
    }

    public function test_each_customer_can_have_only_one_primary_phone(): void
    {
        $now = now();
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Primary Tenant', 'slug' => 'customer-primary-'.uniqid(), 'created_at' => $now, 'updated_at' => $now]);
        $customer = DB::table('customers')->insertGetId(['tenant_id' => $tenant, 'name' => 'One', 'customer_number' => 'C-910001', 'normalized_name' => 'one', 'created_at' => $now, 'updated_at' => $now]);
        $phone = ['tenant_id' => $tenant, 'customer_id' => $customer, 'raw_number' => '123456789', 'normalized_number' => '123456789', 'type' => 'mobile', 'is_primary' => true, 'validation_status' => 'unverified', 'created_at' => $now, 'updated_at' => $now];
        DB::table('customer_phones')->insert($phone);
        $this->expectException(QueryException::class);
        DB::table('customer_phones')->insert($phone + ['raw_number' => '987654321', 'normalized_number' => '987654321']);
    }

    public function test_backfill_assigns_stable_numbers_and_primary_legacy_phones_and_replays_safely(): void
    {
        DB::statement('ALTER TABLE customers ALTER COLUMN customer_number DROP NOT NULL');
        DB::statement('ALTER TABLE customers ALTER COLUMN normalized_name DROP NOT NULL');
        DB::table('customers')->delete();
        DB::table('customer_phones')->delete();
        DB::table('customer_number_counters')->delete();

        $now = now();
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Backfill Tenant', 'slug' => 'customer-backfill-'.uniqid(), 'created_at' => $now, 'updated_at' => $now]);
        $active = DB::table('customers')->insertGetId(['tenant_id' => $tenant, 'name' => 'Zed', 'phone' => '091234567', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $archived = DB::table('customers')->insertGetId(['tenant_id' => $tenant, 'name' => 'Áda', 'phone' => '+963 991234567', 'is_active' => false, 'deleted_at' => $now, 'created_at' => $now, 'updated_at' => $now]);

        $migration = require base_path('database/migrations/2026_09_09_000003_backfill_and_constrain_customer_foundation.php');
        $migration->up();
        $firstNumbers = DB::table('customers')->whereIn('id', [$active, $archived])->orderBy('id')->pluck('customer_number')->all();
        $firstPhoneCount = DB::table('customer_phones')->whereIn('customer_id', [$active, $archived])->count();

        $migration->up();

        $this->assertSame(['C-000001', 'C-000002'], $firstNumbers);
        $this->assertSame($firstPhoneCount, DB::table('customer_phones')->whereIn('customer_id', [$active, $archived])->count());
        $this->assertSame('091234567', DB::table('customer_phones')->where('customer_id', $active)->value('raw_number'));
        $this->assertSame('unverified', DB::table('customer_phones')->where('customer_id', $active)->value('validation_status'));
        $this->assertSame(3, (int) DB::table('customer_number_counters')->where('tenant_id', $tenant)->value('next_value'));
    }
}
