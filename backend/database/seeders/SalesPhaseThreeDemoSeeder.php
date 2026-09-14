<?php

namespace Database\Seeders;

use App\Models\User;
use App\Services\CustomerManagementService;
use App\Services\CustomerPaymentService;
use App\Services\SalesInvoicePostingService;
use App\Services\SalesInvoiceService;
use App\Support\Money;
use Illuminate\Database\Seeder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Customer Payment / AR settlement demo data, created only through the real
 * CustomerPaymentService (never raw journal/allocation inserts) — mirrors
 * SalesPhaseTwoDemoSeeder for the payment side of the Phase 3 domain.
 *
 * Scenario A (docs §41): a posted invoice settled by a partial cash receipt
 * then a final bank receipt that exactly clears the remaining balance.
 * Scenario B: a second customer with two open invoices, one receipt
 * allocated across both — the first fully paid, the second left partial.
 *
 * Amounts are derived from each invoice's actual posted total (never
 * hard-coded), so the scenario reaches exactly "paid"/"partial" regardless
 * of the tenant's configured tax rate.
 */
final class SalesPhaseThreeDemoSeeder extends Seeder
{
    public function run(): void
    {
        $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branch = (int) DB::table('branches')->where('tenant_id', $tenant)->where('name', 'Downtown')->value('id');
        $owner = User::query()->where('tenant_id', $tenant)->where('role', 'owner')->first();
        if (! $tenant || ! $branch || ! $owner) {
            return;
        }
        $request = Request::create('/api/v1/finance/customer-payments', 'POST');
        $request->attributes->set('tenant_id', $tenant);
        $request->attributes->set('auth_user', $owner);

        $customers = app(CustomerManagementService::class);
        $invoices = app(SalesInvoiceService::class);
        $posting = app(SalesInvoicePostingService::class);
        $payments = app(CustomerPaymentService::class);

        $cashMethodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id');
        $cashLocationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        $bankLocationId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'BANK')->value('id');
        $bankAccountId = $bankLocationId ? (int) DB::table('financial_locations')->where('id', $bankLocationId)->value('financial_account_id') : null;
        if (! $cashMethodId || ! $cashLocationId || ! $bankLocationId) {
            return;
        }
        $bankMethodId = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'BANKTRF')->value('id');
        if (! $bankMethodId) {
            $bankMethodId = (int) DB::table('payment_methods')->insertGetId([
                'tenant_id' => $tenant, 'code' => 'BANKTRF', 'name' => 'Bank Transfer', 'type' => 'bank_transfer',
                'financial_account_id' => $bankAccountId, 'financial_location_id' => $bankLocationId, 'is_active' => true, 'sort_order' => 2,
                'created_by' => $owner->id, 'updated_by' => $owner->id, 'created_at' => now(), 'updated_at' => now(),
            ]);
        }

        $product = DB::table('products')->where('tenant_id', $tenant)->where('sku', 'DEMO-P3-SERVICE')->first();
        if (! $product) {
            $id = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => 'Catering Package', 'name_ar' => 'باقة تموين', 'sku' => 'DEMO-P3-SERVICE', 'price' => '300.00', 'is_active' => true, 'is_stock_tracked' => false, 'inventory_controlled' => false, 'created_at' => now(), 'updated_at' => now()]);
            $product = DB::table('products')->where('id', $id)->first();
        }

        $customer = DB::table('customers')->where('tenant_id', $tenant)->where('name', 'Damascus Tech Company')->whereNull('deleted_at')->first()
            ?: $customers->create($tenant, $owner->id, ['name' => 'Damascus Tech Company', 'defaultCreditTermsDays' => 30]);

        if (! DB::table('sales_invoices')->where('tenant_id', $tenant)->where('reference', 'DEMO-P3-A')->exists()) {
            $invoice = $invoices->create($tenant, $owner->id, ['branchId' => $branch, 'customerId' => $customer->id, 'invoiceDate' => now()->subDays(3)->toDateString(), 'reference' => 'DEMO-P3-A', 'notes' => 'Demo: partial cash then full bank settlement.', 'idempotencyKey' => 'sales-demo-p3-a', 'lines' => [['productId' => $product->id, 'quantity' => '1']]]);
            $posted = $posting->post($request, $tenant, $invoice->id, $owner->id, ['idempotencyKey' => 'sales-demo-p3-a-post']);
            $totalCents = Money::cents($posted->total);
            $firstCents = intdiv($totalCents * 4, 10); // ~40% partial, whatever the tenant's tax rate is.
            $payments->pay($request, $tenant, [
                'branchId' => $branch, 'customerId' => $customer->id, 'paymentDate' => now()->subDays(2)->toDateString(), 'amount' => Money::decimal($firstCents),
                'paymentMethodId' => $cashMethodId, 'financialLocationId' => $cashLocationId, 'reference' => 'Demo partial cash receipt', 'idempotencyKey' => 'sales-demo-p3-a-pay-1',
                'allocations' => [['invoiceId' => $invoice->id, 'amount' => Money::decimal($firstCents)]],
            ], $owner->id);
            $secondCents = $totalCents - $firstCents;
            $payments->pay($request, $tenant, [
                'branchId' => $branch, 'customerId' => $customer->id, 'paymentDate' => now()->toDateString(), 'amount' => Money::decimal($secondCents),
                'paymentMethodId' => $bankMethodId, 'financialLocationId' => $bankLocationId, 'reference' => 'Demo final bank receipt', 'idempotencyKey' => 'sales-demo-p3-a-pay-2',
                'allocations' => [['invoiceId' => $invoice->id, 'amount' => Money::decimal($secondCents)]],
            ], $owner->id);
        }

        $customer2 = DB::table('customers')->where('tenant_id', $tenant)->where('name', 'Aleppo Textiles Co')->whereNull('deleted_at')->first()
            ?: $customers->create($tenant, $owner->id, ['name' => 'Aleppo Textiles Co', 'defaultCreditTermsDays' => 30]);

        if (! DB::table('sales_invoices')->where('tenant_id', $tenant)->where('reference', 'DEMO-P3-B1')->exists()) {
            $invoiceB1 = $invoices->create($tenant, $owner->id, ['branchId' => $branch, 'customerId' => $customer2->id, 'invoiceDate' => now()->subDays(5)->toDateString(), 'reference' => 'DEMO-P3-B1', 'idempotencyKey' => 'sales-demo-p3-b1', 'lines' => [['productId' => $product->id, 'quantity' => '1']]]);
            $postedB1 = $posting->post($request, $tenant, $invoiceB1->id, $owner->id, ['idempotencyKey' => 'sales-demo-p3-b1-post']);
            $invoiceB2 = $invoices->create($tenant, $owner->id, ['branchId' => $branch, 'customerId' => $customer2->id, 'invoiceDate' => now()->subDays(1)->toDateString(), 'reference' => 'DEMO-P3-B2', 'idempotencyKey' => 'sales-demo-p3-b2', 'lines' => [['productId' => $product->id, 'quantity' => '0.5']]]);
            $postedB2 = $posting->post($request, $tenant, $invoiceB2->id, $owner->id, ['idempotencyKey' => 'sales-demo-p3-b2-post']);
            // One payment allocated across both open invoices (§9/§26): B1
            // fully settled, plus a partial amount toward B2, leaving it
            // documented as partial with a known remaining balance.
            $b1TotalCents = Money::cents($postedB1->total);
            $b2TotalCents = Money::cents($postedB2->total);
            $b2PartialCents = intdiv($b2TotalCents, 3);
            $payments->pay($request, $tenant, [
                'branchId' => $branch, 'customerId' => $customer2->id, 'paymentDate' => now()->toDateString(), 'amount' => Money::decimal($b1TotalCents + $b2PartialCents),
                'paymentMethodId' => $cashMethodId, 'financialLocationId' => $cashLocationId, 'reference' => 'Demo one receipt across two invoices', 'idempotencyKey' => 'sales-demo-p3-b-pay-1',
                'allocations' => [['invoiceId' => $invoiceB1->id, 'amount' => Money::decimal($b1TotalCents)], ['invoiceId' => $invoiceB2->id, 'amount' => Money::decimal($b2PartialCents)]],
            ], $owner->id);
        }
    }
}
