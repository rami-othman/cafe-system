<?php

namespace Tests\Feature;

use Database\Seeders\CustomerAndTableSeeder;
use Database\Seeders\CustomerOrderHistoryDemoSeeder;
use Database\Seeders\SuperAdminSeeder;
use Database\Seeders\TenantAccessSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CustomerOrderHistoryDemoSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_creates_idempotent_orders_for_the_customer_history_demo(): void
    {
        $this->seed(SuperAdminSeeder::class);
        $this->seed(TenantAccessSeeder::class);
        $this->seed(CustomerAndTableSeeder::class);
        $this->seed(CustomerOrderHistoryDemoSeeder::class);
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $customerId = (int) DB::table('customers')->where('tenant_id', $tenantId)->where('name', 'Eleanor Shellstrop')->value('id');

        $this->assertSame(8, DB::table('orders')->where('tenant_id', $tenantId)->where('customer_id', $customerId)->where('order_number', 'like', 'CM-ORD-%')->count());
        $this->assertSame('51500.00', DB::table('orders')->where('tenant_id', $tenantId)->where('order_number', 'CM-ORD-0008')->value('total'));
        $this->seed(CustomerOrderHistoryDemoSeeder::class);
        $this->assertSame(8, DB::table('orders')->where('tenant_id', $tenantId)->where('customer_id', $customerId)->where('order_number', 'like', 'CM-ORD-%')->count());
    }
}
