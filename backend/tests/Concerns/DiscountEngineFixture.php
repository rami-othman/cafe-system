<?php

namespace Tests\Concerns;

use App\Services\DiscountResolutionService;
use App\Services\DiscountSettingsService;
use App\Services\FinancialSetupService;
use App\Support\SalePaymentMethodResolver;
use Illuminate\Support\Facades\DB;

trait DiscountEngineFixture
{
    private function fixture(): array
    {
        $this->assertContains(DB::selectOne('select current_database() as name')->name, ['cafe_system_618_testing', 'cafe_system_618_testing_migrations']);
        config(['discount_engine.isolated_automatic' => true]);
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Engine', 'slug' => uniqid('engine-')]);
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token, 'X-Discount-Contract' => '2'];
        $actor = (int) DB::table('users')->where('tenant_id', $tenant)->value('id');
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Engine branch', 'is_active' => true, 'timezone' => 'Asia/Damascus']);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branch, $actor);
        $drawer = DB::table('branches')->where('id', $branch)->value('pos_cash_financial_location_id');
        $shift = DB::table('shifts')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'user_id' => $actor, 'financial_location_id' => $drawer, 'status' => 'open', 'opening_cash' => 0, 'opened_at' => now()]);
        $cash = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('type', 'cash')->value('id');
        $card = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('type', 'card')->value('id');
        if (! $card) {
            $account = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
            $card = DB::table('payment_methods')->insertGetId(['tenant_id' => $tenant, 'name' => 'Card', 'code' => 'TEST-CARD', 'type' => 'card', 'financial_account_id' => $account, 'is_active' => true]);
        }
        $products = [];
        foreach (['A', 'B'] as $name) {
            $products[] = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => $name, 'price' => 10, 'is_active' => true, 'is_stock_tracked' => false]);
        }
        $order = DB::table('orders')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'shift_id' => $shift, 'order_number' => uniqid('ENGINE-'), 'type' => 'takeaway', 'status' => 'draft', 'payment_status' => 'unpaid', 'subtotal' => '20.00', 'total' => '20.00', 'tax_rate' => 0]);
        $items = [];
        foreach ($products as $product) {
            $items[] = DB::table('order_items')->insertGetId(['tenant_id' => $tenant, 'order_id' => $order, 'product_id' => $product, 'product_name' => 'Pinned', 'quantity' => 1, 'unit_price' => '10.00', 'total' => '10.00']);
        }

        return compact('tenant', 'token', 'headers', 'actor', 'branch', 'shift', 'cash', 'card', 'products', 'order', 'items');
    }

    private function policy(array $f, array $changes = []): int
    {
        return (int) $this->postJson('/api/v1/discounts', array_replace(['name' => 'Policy', 'applicationMode' => 'automatic', 'type' => 'percentage', 'scope' => 'order', 'value' => 10, 'isActive' => true, 'appliesToAllBranches' => true], $changes), $f['headers'])->assertCreated()->json('data.id');
    }

    private function settings(array $f, array $changes): void
    {
        $version = app(DiscountSettingsService::class)->read($f['tenant'])['version'];
        $current = app(DiscountSettingsService::class)->read($f['tenant']);
        unset($current['version'], $current['engineReady']);
        $this->putJson('/api/v1/cafe-configuration/discount-settings', array_replace($current, ['expectedVersion' => $version], $changes), $f['headers'])->assertOk();
    }

    private function resolution(array $f, ?array $intent = null, ?int $method = null): array
    {
        return DB::transaction(fn () => app(DiscountResolutionService::class)->resolve($f['tenant'], DB::table('orders')->find($f['order']), $intent, $method === null ? null : SalePaymentMethodResolver::resolveExplicit($f['tenant'], $method)));
    }

    private function preview(array $f, array $data): array
    {
        return $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/preview', $data, $f['headers'])->assertOk()->json('data');
    }

    private function applyReview(array $f, array $review, string $identity = 'engine-operation'): array
    {
        return $this->postJson('/api/v1/orders/'.$f['order'].'/discounts/operations', ['reviewId' => $review['reviewId'], 'operationId' => $identity], $f['headers'])->assertOk()->json('data');
    }

    private function quote(array $f, ?int $method = null): array
    {
        return $this->postJson('/api/v1/orders/'.$f['order'].'/payment-quote', ['paymentMethodId' => $method], $f['headers'])->assertOk()->json('data');
    }

    private function payData(array $f, array $quote, string $key = 'engine-payment'): array
    {
        return ['method' => $quote['method'], 'paymentMethodId' => $quote['paymentMethodId'], 'amount' => '100.00', 'quoteId' => $quote['quoteId'], 'idempotencyKey' => $key];
    }
}
