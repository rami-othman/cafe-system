<?php

namespace Tests\Feature;

use Database\Seeders\Cafe618FinanceOperationsDemoSeeder;
use Database\Seeders\FinancialInventoryFoundationSeeder;
use Database\Seeders\InventoryCenterSeeder;
use Database\Seeders\SuperAdminSeeder;
use Database\Seeders\TenantAccessSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class Cafe618FinanceOperationsDemoSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_seeds_service_backed_finance_activity_for_the_normal_demo_tenant_idempotently(): void
    {
        $this->travelTo('2026-09-06 12:00:00');
        try {
            $this->seed(SuperAdminSeeder::class);
            $this->seed(TenantAccessSeeder::class);
            $this->seed(FinancialInventoryFoundationSeeder::class);
            $this->seed(InventoryCenterSeeder::class);
            $this->seed(Cafe618FinanceOperationsDemoSeeder::class);

            $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
            $this->assertGreaterThan(0, $tenant);
            $this->assertGreaterThan(0, DB::table('expenses')->where('tenant_id', $tenant)->whereIn('status', ['paid', 'approved', 'pending_approval', 'rejected', 'draft'])->count());
            $this->assertGreaterThanOrEqual(4, DB::table('suppliers')->where('tenant_id', $tenant)->whereIn('email', [
                'orders@damascus-roasters.local',
                'accounts@levant-dairy.local',
                'billing@cedar-packaging.local',
                'service@barista-equipment.local',
            ])->count());
            $this->assertGreaterThanOrEqual(4, DB::table('supplier_invoices')->where('tenant_id', $tenant)->count());
            $this->assertGreaterThanOrEqual(2, DB::table('cash_transfers')->where('tenant_id', $tenant)->count());
            $this->assertGreaterThanOrEqual(2, DB::table('financial_reconciliations')->where('tenant_id', $tenant)->where('status', 'completed')->count());
            $this->assertGreaterThanOrEqual(2, DB::table('daily_closings')->where('tenant_id', $tenant)->where('status', 'closed')->count());
            $this->assertSame('locked', DB::table('accounting_periods')->where('tenant_id', $tenant)->where('name', 'Cafe 618 July 2026')->value('status'));
            $this->assertTrue(DB::table('accounting_periods')->where('tenant_id', $tenant)->where('status', 'open')->exists());

            $before = [
                'expenses' => DB::table('expenses')->where('tenant_id', $tenant)->count(),
                'invoices' => DB::table('supplier_invoices')->where('tenant_id', $tenant)->count(),
                'payments' => DB::table('supplier_payments')->where('tenant_id', $tenant)->count(),
                'transfers' => DB::table('cash_transfers')->where('tenant_id', $tenant)->count(),
                'journals' => DB::table('journal_entries')->where('tenant_id', $tenant)->count(),
                'reconciliations' => DB::table('financial_reconciliations')->where('tenant_id', $tenant)->count(),
                'closings' => DB::table('daily_closings')->where('tenant_id', $tenant)->count(),
                'periods' => DB::table('accounting_periods')->where('tenant_id', $tenant)->count(),
            ];

            $this->seed(Cafe618FinanceOperationsDemoSeeder::class);

            foreach ($before as $table => $count) {
                $actual = match ($table) {
                    'expenses' => DB::table('expenses')->where('tenant_id', $tenant)->count(),
                    'invoices' => DB::table('supplier_invoices')->where('tenant_id', $tenant)->count(),
                    'payments' => DB::table('supplier_payments')->where('tenant_id', $tenant)->count(),
                    'transfers' => DB::table('cash_transfers')->where('tenant_id', $tenant)->count(),
                    'journals' => DB::table('journal_entries')->where('tenant_id', $tenant)->count(),
                    'reconciliations' => DB::table('financial_reconciliations')->where('tenant_id', $tenant)->count(),
                    'closings' => DB::table('daily_closings')->where('tenant_id', $tenant)->count(),
                    'periods' => DB::table('accounting_periods')->where('tenant_id', $tenant)->count(),
                };
                $this->assertSame($count, $actual, $table.' must not duplicate on a same-day rerun.');
            }
        } finally {
            $this->travelBack();
        }
    }
}
