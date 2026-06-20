<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class PosDemoSeeder extends Seeder
{
    public function run(): void
    {
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->where('name', 'Downtown')->value('id');
        $cashierId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('email', 'cashier@cafe618.local')->value('id');
        $customerId = (int) DB::table('customers')->where('tenant_id', $tenantId)->where('name', 'Eleanor Shellstrop')->value('id');
        $tableId = (int) DB::table('cafe_tables')->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('name', 'Table 1')->value('id');
        $now = now();

        $shiftId = DB::table('shifts')->insertGetId([
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'user_id' => $cashierId,
            'opening_cash' => 125,
            'closing_cash' => 125,
            'expected_cash' => 125,
            'cash_difference' => 0,
            'status' => 'closed',
            'opened_at' => $now->copy()->subHours(8),
            'closed_at' => $now->copy()->subHours(1),
            'notes' => 'Demo closed shift',
            'created_at' => $now->copy()->subHours(8),
            'updated_at' => $now->copy()->subHours(1),
        ]);

        $orderId = DB::table('orders')->insertGetId([
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'shift_id' => $shiftId,
            'table_id' => $tableId,
            'customer_id' => $customerId,
            'cashier_id' => $cashierId,
            'order_number' => $now->format('Ymd').'-0001',
            'type' => 'dine_in',
            'status' => 'paid',
            'payment_status' => 'partially_refunded',
            'subtotal' => 22.75,
            'discount_total' => 2.00,
            'tax_total' => 1.66,
            'service_total' => 0,
            'total' => 22.41,
            'notes' => 'Demo paid order with refund history.',
            'opened_at' => $now->copy()->subHours(3),
            'closed_at' => $now->copy()->subHours(2),
            'created_at' => $now->copy()->subHours(3),
            'updated_at' => $now->copy()->subHour(),
        ]);

        $this->insertItem($tenantId, $orderId, 'Iced Caramel Macchiato', 1, 6.75, ['Iced', 'Medium (12oz)', 'Oat Milk', 'Caramel Drizzle']);
        $this->insertItem($tenantId, $orderId, 'Butter Croissant', 2, 3.50);
        $this->insertItem($tenantId, $orderId, 'Avocado Toast', 1, 9.00, [], 'Extra chili flakes');

        $discountId = (int) DB::table('discounts')->where('tenant_id', $tenantId)->where('code', 'VIP5')->value('id');
        DB::table('order_discounts')->insert([
            'tenant_id' => $tenantId,
            'order_id' => $orderId,
            'discount_id' => $discountId,
            'discount_name' => 'VIP Reward',
            'discount_type' => 'fixed',
            'discount_value' => 5,
            'discount_amount' => 2,
            'created_at' => $now->copy()->subHours(2),
            'updated_at' => $now->copy()->subHours(2),
        ]);

        $paymentId = DB::table('payments')->insertGetId([
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'order_id' => $orderId,
            'shift_id' => $shiftId,
            'cashier_id' => $cashierId,
            'method' => 'card',
            'amount' => 22.41,
            'currency' => 'SYP',
            'status' => 'completed',
            'reference_number' => 'AUTH-098765',
            'paid_at' => $now->copy()->subHours(2),
            'notes' => 'Demo card payment ending in 4242',
            'created_at' => $now->copy()->subHours(2),
            'updated_at' => $now->copy()->subHours(2),
        ]);

        DB::table('payment_refunds')->insert([
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'order_id' => $orderId,
            'payment_id' => $paymentId,
            'refund_number' => 'RF-'.$now->format('Ymd').'-0001',
            'type' => 'partial',
            'amount' => 5,
            'reason' => 'Customer Request',
            'manager_notes' => 'Demo refund approved by manager.',
            'status' => 'completed',
            'refunded_at' => $now->copy()->subHour(),
            'created_at' => $now->copy()->subHour(),
            'updated_at' => $now->copy()->subHour(),
        ]);

        DB::table('print_jobs')->insert([
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'order_id' => $orderId,
            'type' => 'receipt',
            'printer_id' => 'front-counter',
            'channel' => 'local',
            'status' => 'completed',
            'queued_at' => $now->copy()->subHours(2),
            'completed_at' => $now->copy()->subHours(2)->addMinute(),
            'created_at' => $now->copy()->subHours(2),
            'updated_at' => $now->copy()->subHours(2)->addMinute(),
        ]);

        foreach ([
            ['action' => 'order.created', 'description' => 'Demo order created.', 'at' => $now->copy()->subHours(3)],
            ['action' => 'payment.completed', 'description' => 'Card payment completed.', 'at' => $now->copy()->subHours(2)],
            ['action' => 'order.refunded', 'description' => 'Partial refund completed.', 'at' => $now->copy()->subHour()],
        ] as $event) {
            DB::table('activity_logs')->insert([
                'tenant_id' => $tenantId,
                'branch_id' => $branchId,
                'user_id' => $cashierId,
                'action' => $event['action'],
                'entity_type' => 'order',
                'entity_id' => $orderId,
                'description' => $event['description'],
                'created_at' => $event['at'],
                'updated_at' => $event['at'],
            ]);
        }
    }

    private function insertItem(int $tenantId, int $orderId, string $productName, float $quantity, float $unitPrice, array $modifierNames = [], ?string $note = null): void
    {
        $product = DB::table('products')->where('tenant_id', $tenantId)->where('name', $productName)->first();
        $itemId = DB::table('order_items')->insertGetId([
            'tenant_id' => $tenantId,
            'order_id' => $orderId,
            'product_id' => $product->id,
            'product_name' => $product->name,
            'quantity' => $quantity,
            'unit_price' => $unitPrice,
            'total' => round($quantity * $unitPrice, 2),
            'notes' => $note,
            'status' => 'completed',
            'created_at' => now()->subHours(3),
            'updated_at' => now()->subHours(2),
        ]);

        foreach ($modifierNames as $modifierName) {
            $option = DB::table('modifier_options')
                ->join('modifier_groups', 'modifier_groups.id', '=', 'modifier_options.modifier_group_id')
                ->where('modifier_options.tenant_id', $tenantId)
                ->where('modifier_options.name', $modifierName)
                ->select([
                    'modifier_options.id',
                    'modifier_options.modifier_group_id',
                    'modifier_options.name',
                    'modifier_options.price_delta',
                    'modifier_groups.name as group_name',
                ])
                ->first();

            if (! $option) {
                continue;
            }

            DB::table('order_item_modifiers')->insert([
                'tenant_id' => $tenantId,
                'order_item_id' => $itemId,
                'modifier_group_id' => $option->modifier_group_id,
                'modifier_option_id' => $option->id,
                'group_name' => $option->group_name,
                'option_name' => $option->name,
                'price_delta' => $option->price_delta,
                'created_at' => now()->subHours(3),
                'updated_at' => now()->subHours(2),
            ]);
        }
    }
}
