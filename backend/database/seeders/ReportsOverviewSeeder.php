<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class ReportsOverviewSeeder extends Seeder
{
    public function run(): void
    {
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('email', 'manager@cafe618.local')->value('id');
        if (! $tenantId || ! $userId) {
            return;
        }

        $products = DB::table('products')->where('tenant_id', $tenantId)->whereNull('deleted_at')->orderBy('id')->take(3)->get();
        if ($products->count() < 3) {
            return;
        }

        $now = now();
        foreach (DB::table('branches')->where('tenant_id', $tenantId)->whereNull('deleted_at')->orderBy('id')->get() as $branchIndex => $branch) {
            for ($day = 0; $day < 14; $day++) {
                $closedAt = $now->copy()->startOfDay()->subDays($day)->addHours(9 + ($branchIndex % 4));
                $orderNumber = 'RPT-'.$closedAt->format('Ymd').'-'.str_pad((string) ($branchIndex + 1), 2, '0', STR_PAD_LEFT);
                $subtotal = 10 + ($branchIndex * 2) + ($day % 4) * 1.5;
                $orderId = (int) DB::table('orders')->where('tenant_id', $tenantId)->where('branch_id', $branch->id)->where('order_number', $orderNumber)->value('id');
                $orderValues = [
                    'tenant_id' => $tenantId,
                    'branch_id' => $branch->id,
                    'cashier_id' => $userId,
                    'order_number' => $orderNumber,
                    'type' => 'takeaway',
                    'status' => 'paid',
                    'payment_status' => 'paid',
                    'subtotal' => $subtotal,
                    'discount_total' => 0,
                    'tax_total' => 0,
                    'service_total' => 0,
                    'total' => $subtotal,
                    'cogs_total' => round($subtotal * 0.34, 2),
                    'gross_profit' => round($subtotal * 0.66, 2),
                    'gross_margin_percentage' => 66,
                    'opened_at' => $closedAt->copy()->subMinutes(8),
                    'closed_at' => $closedAt,
                    'updated_at' => $now,
                ];
                if ($orderId) {
                    DB::table('orders')->where('id', $orderId)->update($orderValues);
                } else {
                    $orderId = (int) DB::table('orders')->insertGetId($orderValues + ['created_at' => $now]);
                }
                $product = $products[($day + $branchIndex) % $products->count()];
                $item = [
                    'tenant_id' => $tenantId,
                    'order_id' => $orderId,
                    'product_id' => $product->id,
                    'product_name' => $product->name,
                    'quantity' => 1,
                    'unit_price' => $subtotal,
                    'discount_total' => 0,
                    'total' => $subtotal,
                    'status' => 'completed',
                    'cogs_unit' => round($subtotal * 0.34, 2),
                    'cogs_total' => round($subtotal * 0.34, 2),
                    'gross_profit' => round($subtotal * 0.66, 2),
                    'updated_at' => $now,
                ];
                $existingItem = DB::table('order_items')->where('tenant_id', $tenantId)->where('order_id', $orderId)->where('product_id', $product->id)->value('id');
                if ($existingItem) {
                    DB::table('order_items')->where('id', $existingItem)->update($item);
                } else {
                    DB::table('order_items')->insert($item + ['created_at' => $now]);
                }
            }
        }

        $branch = DB::table('branches')->where('tenant_id', $tenantId)->orderBy('id')->first();
        $rentAccount = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '6100')->value('id');
        $cashAccount = (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1010')->value('id');
        if ($branch && $rentAccount && $cashAccount) {
            $entryNumber = 'RPT-EXPENSE-'.now()->format('Ym');
            $entryId = (int) DB::table('journal_entries')->where('tenant_id', $tenantId)->where('entry_number', $entryNumber)->value('id');
            $entry = ['tenant_id' => $tenantId, 'branch_id' => $branch->id, 'entry_number' => $entryNumber, 'entry_date' => now()->toDateString(), 'source_type' => 'reports_demo_seed', 'description' => 'Reports overview demo operating expense.', 'status' => 'posted', 'created_by' => $userId, 'posted_by' => $userId, 'posted_at' => $now, 'updated_at' => $now];
            if ($entryId) {
                DB::table('journal_entries')->where('id', $entryId)->update($entry);
            } else {
                $entryId = (int) DB::table('journal_entries')->insertGetId($entry + ['created_at' => $now]);
            }
            foreach ([[$rentAccount, 180.00, 0.00], [$cashAccount, 0.00, 180.00]] as $index => $line) {
                DB::table('journal_entry_lines')->updateOrInsert(
                    ['journal_entry_id' => $entryId, 'line_number' => $index + 1],
                    ['tenant_id' => $tenantId, 'financial_account_id' => $line[0], 'debit' => $line[1], 'credit' => $line[2], 'created_by' => $userId, 'updated_at' => $now, 'created_at' => $now],
                );
            }
        }
    }
}
