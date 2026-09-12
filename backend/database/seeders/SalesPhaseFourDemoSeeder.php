<?php

namespace Database\Seeders;

use App\Models\User;
use App\Services\CustomerManagementService;
use App\Services\CustomerPaymentService;
use App\Services\CustomerRefundService;
use App\Services\SalesCreditNotePostingService;
use App\Services\SalesCreditNoteService;
use App\Services\SalesInvoicePostingService;
use App\Services\SalesInvoiceService;
use App\Support\Money;
use Illuminate\Database\Seeder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Sales Credit Note / Customer Refund demo data, created only through the
 * real domain services (never raw journal/allocation/movement inserts) —
 * mirrors SalesPhaseThreeDemoSeeder for the Phase 4 return/refund side.
 *
 * Example A (docs §40): a 10-Cappuccino invoice, 2 units returned and
 * restocked -> proportional Revenue/Tax/AR/COGS reversal, recipe materials
 * restored at the ORIGINAL sale cost.
 * Example B: a fully paid service invoice credited in full -> unapplied
 * customer credit -> settled by a bank Customer Refund.
 */
final class SalesPhaseFourDemoSeeder extends Seeder
{
    public function run(): void
    {
        $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branch = (int) DB::table('branches')->where('tenant_id', $tenant)->where('name', 'Downtown')->value('id');
        $owner = User::query()->where('tenant_id', $tenant)->where('role', 'owner')->first();
        if (! $tenant || ! $branch || ! $owner) {
            return;
        }
        $request = Request::create('/api/v1/finance/sales-credit-notes', 'POST');
        $request->attributes->set('tenant_id', $tenant);
        $request->attributes->set('auth_user', $owner);

        $customers = app(CustomerManagementService::class);
        $invoices = app(SalesInvoiceService::class);
        $posting = app(SalesInvoicePostingService::class);
        $payments = app(CustomerPaymentService::class);
        $creditNotes = app(SalesCreditNoteService::class);
        $creditPosting = app(SalesCreditNotePostingService::class);
        $refunds = app(CustomerRefundService::class);

        $cashMethodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $cashLocationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        if (! $cashMethodId || ! $cashLocationId) {
            return;
        }
        // §40 Example B asks for a bank refund; falls back to cash if the
        // Phase 3 demo seeder's bank payment method isn't present.
        $bankLocationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'BANK')->value('id');
        $bankMethodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'BANKTRF')->value('id');
        $refundMethodId = $bankMethodId ?: $cashMethodId;
        $refundLocationId = $bankLocationId ?: $cashLocationId;

        $customer = DB::table('customers')->where('tenant_id', $tenant)->where('name', 'Damascus Tech Company')->whereNull('deleted_at')->first()
            ?: $customers->create($tenant, $owner->id, ['name' => 'Damascus Tech Company', 'defaultCreditTermsDays' => 30]);

        // Example A: tracked product, partial return with restock.
        $tracked = DB::table('products')->where('tenant_id', $tenant)->where('sku', 'DEMO-LATTE')->where('is_active', true)->first();
        if ($tracked && ! DB::table('sales_invoices')->where('tenant_id', $tenant)->where('reference', 'DEMO-P4-A')->exists()) {
            $variantId = DB::table('product_variants')->where('tenant_id', $tenant)->where('product_id', $tracked->id)->where('is_default', true)->value('id');
            $invoice = $invoices->create($tenant, $owner->id, ['branchId' => $branch, 'customerId' => $customer->id, 'invoiceDate' => now()->subDays(4)->toDateString(), 'reference' => 'DEMO-P4-A', 'idempotencyKey' => 'sales-demo-p4-a', 'lines' => [['productId' => $tracked->id, 'variantId' => $variantId, 'quantity' => '10']]]);
            $postedInvoice = $posting->post($request, $tenant, $invoice->id, $owner->id, ['idempotencyKey' => 'sales-demo-p4-a-post']);
            $lineId = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoice->id)->value('id');
            $note = $creditNotes->create($tenant, $owner->id, ['originalSalesInvoiceId' => $invoice->id, 'reason' => 'Customer returned 2 units, unopened', 'idempotencyKey' => 'sales-demo-p4-a-cn', 'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => '2', 'restock' => true]]]);
            $creditPosting->post($request, $tenant, $note->id, $owner->id, ['idempotencyKey' => 'sales-demo-p4-a-cn-post']);
        }

        // Example B: fully paid service invoice, fully credited, settled by a bank refund.
        $service = DB::table('products')->where('tenant_id', $tenant)->where('sku', 'DEMO-MEETING-ROOM')->first();
        if ($service && ! DB::table('sales_invoices')->where('tenant_id', $tenant)->where('reference', 'DEMO-P4-B')->exists()) {
            $invoice = $invoices->create($tenant, $owner->id, ['branchId' => $branch, 'customerId' => $customer->id, 'invoiceDate' => now()->subDays(6)->toDateString(), 'reference' => 'DEMO-P4-B', 'notes' => 'Demo: paid invoice, full credit, then bank refund.', 'idempotencyKey' => 'sales-demo-p4-b', 'lines' => [['productId' => $service->id, 'quantity' => '1']]]);
            $postedInvoice = $posting->post($request, $tenant, $invoice->id, $owner->id, ['idempotencyKey' => 'sales-demo-p4-b-post']);
            $payments->pay($request, $tenant, [
                'branchId' => $branch, 'customerId' => $customer->id, 'paymentDate' => now()->subDays(5)->toDateString(), 'amount' => $postedInvoice->total,
                'paymentMethodId' => $cashMethodId, 'financialLocationId' => $cashLocationId, 'reference' => 'Demo full cash payment before cancellation', 'idempotencyKey' => 'sales-demo-p4-b-pay',
                'allocations' => [['invoiceId' => $invoice->id, 'amount' => $postedInvoice->total]],
            ], $owner->id);
            $lineId = DB::table('sales_invoice_lines')->where('sales_invoice_id', $invoice->id)->value('id');
            $lineQty = DB::table('sales_invoice_lines')->where('id', $lineId)->value('quantity');
            $note = $creditNotes->create($tenant, $owner->id, ['originalSalesInvoiceId' => $invoice->id, 'reason' => 'Service cancelled after payment', 'idempotencyKey' => 'sales-demo-p4-b-cn', 'lines' => [['originalSalesInvoiceLineId' => $lineId, 'quantity' => $lineQty, 'restock' => false]]]);
            $postedNote = $creditPosting->post($request, $tenant, $note->id, $owner->id, ['idempotencyKey' => 'sales-demo-p4-b-cn-post']);
            if (Money::cents($postedNote->customer_credit_amount) > 0) {
                $refunds->pay($request, $tenant, [
                    'branchId' => $branch, 'customerId' => $customer->id, 'refundDate' => now()->toDateString(), 'amount' => $postedNote->customer_credit_amount,
                    'paymentMethodId' => $refundMethodId, 'financialLocationId' => $refundLocationId, 'reference' => 'Demo refund of cancelled service', 'idempotencyKey' => 'sales-demo-p4-b-refund',
                ], $owner->id);
            }
        }
    }
}
