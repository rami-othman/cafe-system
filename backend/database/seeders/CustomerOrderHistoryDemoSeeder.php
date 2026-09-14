<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Explicit, idempotent local demo data for Customer Order History.
 *
 * This is deliberately not part of DatabaseSeeder: the base seed remains
 * deterministic for tests. Run this seeder explicitly after customer data is
 * present when manually reviewing screen 08.
 */
final class CustomerOrderHistoryDemoSeeder extends Seeder
{
    public function run(): void
    {
        if (! app()->environment(['local', 'development', 'testing'])) {
            throw new RuntimeException('CustomerOrderHistoryDemoSeeder is restricted to local, development, and testing environments.');
        }

        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $customerId = (int) DB::table('customers')
            ->where('tenant_id', $tenantId)
            ->where('name', 'Eleanor Shellstrop')
            ->whereNull('deleted_at')
            ->value('id');
        $branches = DB::table('branches')
            ->where('tenant_id', $tenantId)
            ->where('is_active', true)
            ->whereNull('deleted_at')
            ->orderBy('id')
            ->get(['id']);

        if (! $tenantId || ! $customerId || $branches->isEmpty()) {
            throw new RuntimeException('Run TenantAccessSeeder and CustomerAndTableSeeder before CustomerOrderHistoryDemoSeeder.');
        }

        $now = now();
        foreach ([
            ['number' => 'CM-ORD-0008', 'daysAgo' => 1, 'status' => 'paid', 'paymentStatus' => 'paid', 'total' => '51500.00'],
            ['number' => 'CM-ORD-0007', 'daysAgo' => 4, 'status' => 'paid', 'paymentStatus' => 'partially_refunded', 'total' => '51000.00'],
            ['number' => 'CM-ORD-0006', 'daysAgo' => 8, 'status' => 'paid', 'paymentStatus' => 'paid', 'total' => '50500.00'],
            ['number' => 'CM-ORD-0005', 'daysAgo' => 12, 'status' => 'held', 'paymentStatus' => 'unpaid', 'total' => '50000.00'],
            ['number' => 'CM-ORD-0004', 'daysAgo' => 17, 'status' => 'paid', 'paymentStatus' => 'paid', 'total' => '49500.00'],
            ['number' => 'CM-ORD-0003', 'daysAgo' => 21, 'status' => 'draft', 'paymentStatus' => 'unpaid', 'total' => '49000.00'],
            ['number' => 'CM-ORD-0002', 'daysAgo' => 26, 'status' => 'cancelled', 'paymentStatus' => 'unpaid', 'total' => '48500.00'],
            ['number' => 'CM-ORD-0001', 'daysAgo' => 30, 'status' => 'paid', 'paymentStatus' => 'refunded', 'total' => '48000.00'],
        ] as $index => $order) {
            $createdAt = Carbon::instance($now)->subDays($order['daysAgo'])->setTime(10 + ($index % 6), 15);
            $branchId = (int) $branches[$index % $branches->count()]->id;
            DB::table('orders')->updateOrInsert(
                ['tenant_id' => $tenantId, 'branch_id' => $branchId, 'order_number' => $order['number']],
                [
                    'customer_id' => $customerId,
                    'type' => 'takeaway',
                    'status' => $order['status'],
                    'payment_status' => $order['paymentStatus'],
                    'subtotal' => $order['total'],
                    'discount_total' => '0.00',
                    'tax_total' => '0.00',
                    'service_total' => '0.00',
                    'total' => $order['total'],
                    'opened_at' => $createdAt,
                    'closed_at' => $order['status'] === 'paid' ? $createdAt->copy()->addMinutes(20) : null,
                    'notes' => 'Customer Order History local demo seed',
                    'created_at' => $createdAt,
                    'updated_at' => $now,
                ],
            );
        }
    }
}
