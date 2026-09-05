<?php

namespace Tests\Feature;

use App\Services\FinancialIntegrityService;
use Database\Seeders\FinanceOperationsDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class FinanceOperationsDemoSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_connected_finance_demo_is_idempotent_and_closes_its_operational_period(): void
    {
        $this->travelTo('2026-09-01 12:00:00');
        try {
            app(FinanceOperationsDemoSeeder::class)->run();
            $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618-finance-demo')->value('id');
            $this->assertGreaterThan(0, $tenant);

            $this->assertSame(2, DB::table('suppliers')->where('tenant_id', $tenant)->count());
            $this->assertSame(1, DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('invoice_number', 'DEMO-BEAN-2026-07')->where('status', 'partially_paid')->count());
            $this->assertSame(1, DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('invoice_number', 'DEMO-BEAN-UNPAID-2026-08')->where('status', 'posted')->count());
            $this->assertSame(1, DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('invoice_number', 'DEMO-DAIRY-PAID-2026-07')->where('status', 'paid')->count());
            $this->assertSame(1, DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('invoice_number', 'DEMO-DAIRY-OVERDUE-2026-07')->where('status', 'posted')->whereDate('due_date', '<', '2026-09-01')->count());
            $this->assertSame(1, DB::table('financial_reconciliations')->where('tenant_id', $tenant)->where('status', 'completed')->count());
            $this->assertSame(1, DB::table('daily_closings')->where('tenant_id', $tenant)->where('business_date', '2026-09-01')->where('status', 'closed')->count());
            $this->assertSame(1, DB::table('accounting_periods')->where('tenant_id', $tenant)->where('status', 'closed')->count());
            $this->assertSame('PASS', app(FinancialIntegrityService::class)->inspect($tenant)['status']);

            $counts = [
                'suppliers' => DB::table('suppliers')->where('tenant_id', $tenant)->count(),
                'invoices' => DB::table('supplier_invoices')->where('tenant_id', $tenant)->count(),
                'payments' => DB::table('supplier_payments')->where('tenant_id', $tenant)->count(),
                'allocations' => DB::table('payment_allocations')->where('tenant_id', $tenant)->count(),
                'reconciliations' => DB::table('financial_reconciliations')->where('tenant_id', $tenant)->count(),
                'closings' => DB::table('daily_closings')->where('tenant_id', $tenant)->count(),
                'periods' => DB::table('accounting_periods')->where('tenant_id', $tenant)->count(),
                'journals' => DB::table('journal_entries')->where('tenant_id', $tenant)->count(),
            ];

            app(FinanceOperationsDemoSeeder::class)->run();

            foreach ($counts as $table => $count) {
                $actual = match ($table) {
                    'suppliers' => DB::table('suppliers')->where('tenant_id', $tenant)->count(),
                    'invoices' => DB::table('supplier_invoices')->where('tenant_id', $tenant)->count(),
                    'payments' => DB::table('supplier_payments')->where('tenant_id', $tenant)->count(),
                    'allocations' => DB::table('payment_allocations')->where('tenant_id', $tenant)->count(),
                    'reconciliations' => DB::table('financial_reconciliations')->where('tenant_id', $tenant)->count(),
                    'closings' => DB::table('daily_closings')->where('tenant_id', $tenant)->count(),
                    'periods' => DB::table('accounting_periods')->where('tenant_id', $tenant)->count(),
                    'journals' => DB::table('journal_entries')->where('tenant_id', $tenant)->count(),
                };
                $this->assertSame($count, $actual, $table.' must remain idempotent.');
            }
        } finally {
            $this->travelBack();
        }
    }
}
