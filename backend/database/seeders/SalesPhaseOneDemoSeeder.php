<?php

namespace Database\Seeders;

use App\Services\CustomerManagementService;
use App\Services\SalesInvoiceService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/** Financially inert Phase 1 examples. These use the real customer/invoice services and never invoke posting. */
class SalesPhaseOneDemoSeeder extends Seeder
{
    public function run(): void
    {
        $tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branch = (int) DB::table('branches')->where('tenant_id', $tenant)->where('name', 'Downtown')->value('id');
        $actor = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        if (! $tenant || ! $branch || ! $actor) return;

        $customers = app(CustomerManagementService::class);
        $invoices = app(SalesInvoiceService::class);
        $cappuccino = (int) DB::table('products')->where('tenant_id', $tenant)->where('name', 'Cappuccino')->where('is_active', true)->value('id');
        $espresso = (int) DB::table('products')->where('tenant_id', $tenant)->where('name', 'Espresso')->where('is_active', true)->value('id');
        if (! $cappuccino || ! $espresso) return;

        foreach ([
            ['name' => 'Damascus Tech Company', 'terms' => 30, 'key' => 'sales-demo-damascus-tech', 'product' => $cappuccino, 'quantity' => '10', 'reference' => 'DEMO-CAP-10'],
            ['name' => 'Al Noor Offices', 'terms' => 45, 'key' => 'sales-demo-al-noor', 'product' => $espresso, 'quantity' => '100', 'reference' => 'DEMO-ESP-100'],
        ] as $demo) {
            $customer = DB::table('customers')->where('tenant_id', $tenant)->where('name', $demo['name'])->whereNull('deleted_at')->first();
            if (! $customer) $customer = $customers->create($tenant, $actor, ['name' => $demo['name'], 'defaultCreditTermsDays' => $demo['terms']]);
            $invoices->create($tenant, $actor, ['branchId' => $branch, 'customerId' => $customer->id, 'invoiceDate' => '2026-09-12', 'reference' => $demo['reference'], 'notes' => 'Phase 1 demo draft: no journal, AR, COGS, inventory, POS order, or payment.', 'idempotencyKey' => $demo['key'], 'lines' => [['productId' => $demo['product'], 'quantity' => $demo['quantity']]]]);
        }
    }
}
