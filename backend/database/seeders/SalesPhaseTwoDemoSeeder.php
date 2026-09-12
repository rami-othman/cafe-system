<?php

namespace Database\Seeders;

use App\Models\User;
use App\Services\CustomerManagementService;
use App\Services\SalesInvoicePostingService;
use App\Services\SalesInvoiceService;
use Illuminate\Database\Seeder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** Posted, unpaid examples created only through the Sales Invoice domain services. */
final class SalesPhaseTwoDemoSeeder extends Seeder
{
    public function run(): void
    {
        $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branch = (int) DB::table('branches')->where('tenant_id', $tenant)->where('name', 'Downtown')->value('id');
        $owner = User::query()->where('tenant_id', $tenant)->where('role', 'owner')->first();
        if (! $tenant || ! $branch || ! $owner) return;
        $request = Request::create('/api/v1/finance/sales-invoices', 'POST'); $request->attributes->set('tenant_id', $tenant); $request->attributes->set('auth_user', $owner);
        $customers = app(CustomerManagementService::class); $invoices = app(SalesInvoiceService::class); $posting = app(SalesInvoicePostingService::class);
        $customer = DB::table('customers')->where('tenant_id', $tenant)->where('name', 'Damascus Tech Company')->whereNull('deleted_at')->first() ?: $customers->create($tenant, $owner->id, ['name' => 'Damascus Tech Company', 'defaultCreditTermsDays' => 30]);
        $tracked = DB::table('products')->where('tenant_id', $tenant)->where('sku', 'DEMO-LATTE')->where('is_active', true)->first();
        if ($tracked && ! DB::table('sales_invoices')->where('tenant_id', $tenant)->where('reference', 'DEMO-P2-TRACKED')->exists()) {
            $invoice = $invoices->create($tenant, $owner->id, ['branchId' => $branch, 'customerId' => $customer->id, 'invoiceDate' => now()->toDateString(), 'reference' => 'DEMO-P2-TRACKED', 'notes' => 'Posted unpaid demo using the real Sales Invoice posting service.', 'idempotencyKey' => 'sales-demo-p2-tracked', 'lines' => [['productId' => $tracked->id, 'variantId' => DB::table('product_variants')->where('tenant_id', $tenant)->where('product_id', $tracked->id)->where('is_default', true)->value('id'), 'quantity' => '3']]]);
            $posting->post($request, $tenant, $invoice->id, $owner->id, ['idempotencyKey' => 'sales-demo-p2-tracked-post']);
        }
        $service = DB::table('products')->where('tenant_id', $tenant)->where('sku', 'DEMO-MEETING-ROOM')->first();
        if (! $service) { $id = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => 'Meeting Room Package', 'name_ar' => 'باقة غرفة اجتماعات', 'sku' => 'DEMO-MEETING-ROOM', 'price' => '150.00', 'is_active' => true, 'is_stock_tracked' => false, 'inventory_controlled' => false, 'created_at' => now(), 'updated_at' => now()]); $service = DB::table('products')->where('id', $id)->first(); }
        if (! DB::table('sales_invoices')->where('tenant_id', $tenant)->where('reference', 'DEMO-P2-SERVICE')->exists()) {
            $invoice = $invoices->create($tenant, $owner->id, ['branchId' => $branch, 'customerId' => $customer->id, 'invoiceDate' => now()->toDateString(), 'reference' => 'DEMO-P2-SERVICE', 'notes' => 'Posted unpaid service demo: AR/revenue only, no stock movement or physical COGS.', 'idempotencyKey' => 'sales-demo-p2-service', 'lines' => [['productId' => $service->id, 'quantity' => '1']]]);
            $posting->post($request, $tenant, $invoice->id, $owner->id, ['idempotencyKey' => 'sales-demo-p2-service-post']);
        }
    }
}
