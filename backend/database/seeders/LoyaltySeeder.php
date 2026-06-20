<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class LoyaltySeeder extends Seeder
{
    public function run(): void
    {
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $now = now();

        foreach (DB::table('customers')->where('tenant_id', $tenantId)->where('name', '!=', 'Walk-in Customer')->get() as $customer) {
            $points = (int) round((float) $customer->total_spent);
            $tier = match (true) {
                $points >= 1000 => 'vip',
                $points >= 250 => 'regular',
                default => 'new',
            };

            DB::table('loyalty_accounts')->insert([
                'tenant_id' => $tenantId,
                'customer_id' => $customer->id,
                'points_balance' => $points,
                'lifetime_points' => $points,
                'tier' => $tier,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            DB::table('loyalty_transactions')->insert([
                'tenant_id' => $tenantId,
                'customer_id' => $customer->id,
                'type' => 'earn',
                'points' => $points,
                'description' => 'Imported demo loyalty balance',
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }
}
