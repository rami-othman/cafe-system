<?php

namespace Tests\Feature;

use Illuminate\Database\Schema\Blueprint;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\Feature\Concerns\DailyClosingFixtures;
use Tests\TestCase;

/**
 * Regression test for a staging incident: the backend queries
 * `sales_invoices` / `sales_invoice_lines` / `sales_credit_notes` /
 * `sales_credit_note_lines` unconditionally from the Finance Dashboard's
 * revenue calculation (SalesReportingQueryService::manualInvoiceComponents()
 * and creditNoteComponents()), but those tables had not been migrated on the
 * staging database. Every call to GET /api/v1/finance/dashboard (and its
 * /branches sibling) failed with a 500 from an uncaught
 * SQLSTATE[42P01]/Undefined table QueryException.
 *
 * This test drops those four tables after the normal test migrations have
 * run, to reproduce "code deployed ahead of its migrations" without needing
 * a real environment where they are missing, and asserts the endpoints
 * degrade to POS-only totals instead of failing.
 */
class FinanceDashboardMissingSalesInvoiceTablesTest extends TestCase
{
    use DailyClosingFixtures;
    use RefreshDatabase;

    private function dropSalesInvoiceTables(): void
    {
        Schema::dropIfExists('customer_payment_allocation_history');
        Schema::dropIfExists('customer_payment_allocations');
        Schema::dropIfExists('customer_receivables');
        Schema::dropIfExists('sales_invoice_postings');
        Schema::dropIfExists('customer_credit_ledger');
        Schema::table('customer_refunds', fn (Blueprint $table) => $table->dropConstrainedForeignId('sales_credit_note_id'));
        Schema::dropIfExists('sales_credit_note_postings');
        Schema::dropIfExists('sales_credit_note_costs');
        Schema::dropIfExists('sales_credit_note_lines');
        Schema::dropIfExists('sales_credit_notes');
        Schema::dropIfExists('sales_invoice_costs');
        Schema::dropIfExists('sales_invoice_line_material_overrides');
        Schema::dropIfExists('sales_invoice_lines');
        Schema::dropIfExists('sales_invoice_charges');
        Schema::table('customer_payments', fn (Blueprint $table) => $table->dropConstrainedForeignId('direct_sales_invoice_id'));
        Schema::dropIfExists('sales_invoices');
    }

    public function test_dashboard_degrades_to_pos_only_totals_instead_of_500_when_sales_invoice_tables_are_missing(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $branch = $this->branchId($tenant);
        $headers = $this->headers($tenant, 'owner', 'dash-missing-tables');
        $date = '2030-09-20';

        $order = $this->makeOrder($tenant, $branch, '100.00', $date.' 12:00:00');
        $this->makePayment($tenant, $branch, $order, '100.00', $date.' 12:00:00', 'cash');

        $this->dropSalesInvoiceTables();

        $response = $this->getJson("/api/v1/finance/dashboard?date_from=$date&date_to=$date&branch_id=$branch", $headers)
            ->assertOk();

        // POS revenue must still be reported correctly; the missing Manual
        // Sales Invoice / Credit Note tables should contribute zero rather
        // than fail the whole request.
        $this->assertSame('100.00', $response->json('data.kpis.netSales.current'));
    }

    public function test_branches_endpoint_does_not_500_when_sales_invoice_tables_are_missing(): void
    {
        $this->seed();
        $tenant = $this->tenantId();
        $headers = $this->headers($tenant, 'owner', 'dash-missing-tables-branches');

        $this->dropSalesInvoiceTables();

        $this->getJson('/api/v1/finance/dashboard/branches?date_from=2030-08-01&date_to=2030-08-31', $headers)
            ->assertOk();
    }
}
