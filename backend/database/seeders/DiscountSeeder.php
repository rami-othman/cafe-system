<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DiscountSeeder extends Seeder
{
    public function run(): void
    {
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $now = now();

        foreach ([
            ['name' => 'Opening Discount', 'code' => 'OPEN10', 'type' => 'percentage', 'value' => 10, 'minimum_order_amount' => 20],
            ['name' => 'Morning Rush', 'code' => 'MORNING15', 'type' => 'percentage', 'value' => 15, 'maximum_discount_amount' => 8, 'ends_at' => $now->copy()->addDay()->setTime(11, 0)],
            ['name' => 'VIP Reward', 'code' => 'VIP5', 'type' => 'fixed', 'value' => 5, 'minimum_order_amount' => 10],
            ['name' => 'Pastry Special', 'code' => 'PASTRYBOGO', 'type' => 'bogo', 'value' => 1],
        ] as $discount) {
            $discountId = DB::table('discounts')->insertGetId([
                'tenant_id' => $tenantId,
                'name' => $discount['name'],
                'code' => $discount['code'],
                'type' => $discount['type'],
                'value' => $discount['value'],
                'scope' => 'order',
                'starts_at' => $discount['starts_at'] ?? null,
                'ends_at' => $discount['ends_at'] ?? null,
                'minimum_order_amount' => $discount['minimum_order_amount'] ?? 0,
                'maximum_discount_amount' => $discount['maximum_discount_amount'] ?? null,
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            if ($discount['code'] === 'PASTRYBOGO') {
                $productId = (int) DB::table('products')->where('tenant_id', $tenantId)->where('name', 'Almond Croissant')->value('id');
                DB::table('discount_targets')->insert([
                    'tenant_id' => $tenantId,
                    'discount_id' => $discountId,
                    'target_type' => 'product',
                    'target_id' => $productId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }
    }
}
