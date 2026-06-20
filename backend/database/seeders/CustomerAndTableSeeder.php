<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class CustomerAndTableSeeder extends Seeder
{
    public function run(): void
    {
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->where('name', 'Downtown')->value('id');
        $now = now();

        foreach (range(1, 8) as $number) {
            DB::table('cafe_tables')->insert([
                'tenant_id' => $tenantId,
                'branch_id' => $branchId,
                'name' => "Table {$number}",
                'code' => "T{$number}",
                'seats' => $number <= 4 ? 2 : 4,
                'status' => $number === 8 ? 'reserved' : 'available',
                'sort_order' => $number,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        foreach ([
            ['name' => 'Walk-in Customer', 'phone' => null, 'email' => null, 'total_spent' => 0, 'visits_count' => 0],
            ['name' => 'Jane Doe', 'phone' => '+1 (555) 019-8234', 'email' => 'jane@example.com', 'total_spent' => 1450, 'visits_count' => 24],
            ['name' => 'Janet Smith', 'phone' => '+1 (555) 542-9901', 'email' => 'janet@example.com', 'total_spent' => 320, 'visits_count' => 8],
            ['name' => 'Jane Williams', 'phone' => '+1 (555) 781-2245', 'email' => 'jane.williams@example.com', 'total_spent' => 50, 'visits_count' => 2],
            ['name' => 'Eleanor Shellstrop', 'phone' => '+1 (555) 123-4567', 'email' => 'eleanor@example.com', 'total_spent' => 780, 'visits_count' => 15],
        ] as $customer) {
            DB::table('customers')->insert([
                'tenant_id' => $tenantId,
                'name' => $customer['name'],
                'phone' => $customer['phone'],
                'email' => $customer['email'],
                'total_spent' => $customer['total_spent'],
                'visits_count' => $customer['visits_count'],
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }
}
