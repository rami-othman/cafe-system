<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DiscountSeeder extends Seeder
{
    public function run(): void
    {
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        if (! $tenantId) {
            return;
        }

        $now = now();
        $discounts = [
            ['Morning Rush 15%', 'MRNG15', 'percentage', 15, 'Min. $10 spent', 'Oct 1 - Oct 31', '7:00 AM - 10:00 AM', 'active', 128, 192],
            ['Student Discount', null, 'fixed', 2, 'Requires Student ID tag', 'Always Valid', null, 'active', 164, 328],
            ['Holiday Special', 'HOLIDAY24', 'percentage', 20, 'Any pastry + drink', 'Dec 15 - Dec 31', null, 'scheduled', 0, 0, 'Desserts'],
            ['Summer Coolers', 'SUMMER', 'bogo', 1, 'Iced beverages only', 'Jun 1 - Aug 31', null, 'expired', 94, 188, 'Cold Drinks'],
            ['Weekday Lunch', 'LUNCH10', 'percentage', 10, 'Between 12:00 PM - 3:00 PM', 'Always Valid', null, 'active', 46, 74],
            ['First Order', null, 'fixed', 3, 'New customers only', 'Always Valid', null, 'active', 28, 84],
            ['Pastry Pairing', 'PAIR5', 'percentage', 5, 'Coffee + pastry', 'Nov 1 - Nov 30', null, 'scheduled', 0, 0, 'Desserts'],
            ['Tea Time Treat', 'TEA15', 'percentage', 15, 'Selected teas', 'Mar 1 - Mar 31', null, 'expired', 31, 46.5, 'Tea'],
            ['Loyalty Thanks', null, 'fixed', 1.5, 'Gold members only', 'Always Valid', null, 'active', 36, 54],
            ['Friday Fizz', 'FIZZ', 'bogo', 1, 'Sparkling drinks', 'Every Friday', null, 'active', 20, 40, 'Cold Drinks'],
            ['Winter Warmer', 'WARM10', 'percentage', 10, 'Hot beverages', 'Jan 1 - Feb 28', null, 'inactive', 0, 0, 'Coffee'],
            ['Birthday Reward', null, 'fixed', 5, 'Birthday month', 'Always Valid', null, 'active', 15, 75],
            ['Office Catering', 'OFFICE', 'percentage', 12, 'Orders over $75', 'Sep 1 - Sep 30', null, 'scheduled', 0, 0],
            ['Weekend Brunch', 'BRUNCH', 'percentage', 10, 'Saturday and Sunday', 'Always Valid', null, 'active', 17, 34],
            ['Rainy Day Perk', 'RAINY', 'fixed', 1, 'Mobile orders', 'Apr 1 - Apr 30', null, 'expired', 12, 12],
            ['Bean Bag Bundle', 'BEANS', 'fixed', 4, 'Two coffee bags', 'Always Valid', null, 'active', 9, 36],
            ['Afternoon Pickup', 'PICKUP', 'percentage', 8, 'Order ahead pickup', '2:00 PM - 5:00 PM', null, 'active', 11, 17.6],
            ['New Menu Launch', 'NEWMENU', 'percentage', 20, 'Featured menu items', 'Oct 15 - Oct 22', null, 'scheduled', 0, 0],
            ['Family Pack', 'FAMILY', 'bogo', 1, 'Kids drinks', 'Aug 1 - Aug 31', null, 'expired', 8, 16],
            ['Late Night', 'NIGHT', 'percentage', 10, 'After 8:00 PM', 'Always Valid', null, 'inactive', 0, 0],
            ['Staff Friends', 'FRIENDS', 'fixed', 2.5, 'Staff referral', 'Always Valid', null, 'active', 6, 15],
            ['Festival Treat', 'FESTIVE', 'percentage', 15, 'Any seasonal drink', 'Dec 1 - Dec 14', null, 'scheduled', 0, 0],
            ['Monday Mug', 'MONDAY', 'fixed', 1, 'Reusable mug', 'Every Monday', null, 'active', 5, 5],
            ['Spring Sips', 'SPRING', 'percentage', 10, 'Cold brew drinks', 'Mar 1 - May 31', null, 'expired', 2, 4, 'Cold Drinks'],
        ];

        foreach ($discounts as $record) {
            [$name, $code, $type, $value, $conditions, $period, $secondary, $status, $usedCount, $saved, $category] = array_pad($record, 11, null);
            [$isActive, $startsAt, $endsAt] = match ($status) {
                'scheduled' => [true, $now->copy()->addDay(), null],
                'expired' => [true, null, $now->copy()->subDay()],
                'inactive' => [false, null, null],
                default => [true, null, null],
            };
            $scope = $category ? 'category' : 'order';
            DB::table('discounts')->updateOrInsert(
                ['tenant_id' => $tenantId, 'name' => $name],
                [
                    'code' => $code, 'description' => $conditions, 'application_mode' => $code ? 'code' : 'auto',
                    'type' => $type, 'value' => $value, 'scope' => $scope, 'conditions' => $conditions,
                    'starts_at' => $startsAt, 'ends_at' => $endsAt, 'minimum_order_amount' => $name === 'Morning Rush 15%' ? 10 : 0,
                    'maximum_discount_amount' => null, 'usage_limit' => null, 'used_count' => $usedCount,
                    'estimated_saved_value' => $saved, 'display_period_primary' => $period, 'display_period_secondary' => $secondary,
                    'is_active' => $isActive, 'updated_at' => $now, 'created_at' => $now,
                ],
            );
            $discountId = (int) DB::table('discounts')->where('tenant_id', $tenantId)->where('name', $name)->value('id');
            DB::table('discount_targets')->where('tenant_id', $tenantId)->where('discount_id', $discountId)->delete();
            if ($category && ($categoryId = DB::table('categories')->where('tenant_id', $tenantId)->where('name', $category)->value('id'))) {
                DB::table('discount_targets')->insert(['tenant_id' => $tenantId, 'discount_id' => $discountId, 'target_type' => 'category', 'target_id' => $categoryId, 'created_at' => $now, 'updated_at' => $now]);
            }
        }
    }
}
