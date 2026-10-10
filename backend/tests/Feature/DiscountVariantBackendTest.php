<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\DiscountEligibilityService;
use App\Services\FinancialSetupService;
use App\Services\PosPricingService;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class DiscountVariantBackendTest extends TestCase
{
    use RefreshDatabase;

    private function fixture(): array
    {
        $this->assertSame('cafe_system_618_testing', DB::selectOne('select current_database() as name')->name);
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Variants', 'slug' => uniqid('variants-')]);
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Branch', 'is_active' => true, 'timezone' => 'Asia/Damascus']);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee', 'price' => 999, 'is_active' => true]);
        $variant = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Small', 'name_ar' => 'صغير', 'base_price' => 999, 'is_active' => true]);
        $sibling = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Large', 'is_active' => true]);
        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant)];
        $payload = ['name' => 'Variant policy', 'applicationMode' => 'manual', 'type' => 'percentage', 'scope' => 'product', 'value' => '50.00', 'isActive' => true, 'appliesToAllBranches' => true, 'targetProductIds' => [$product], 'productVariantSelections' => [['productId' => $product, 'variantMode' => 'selected', 'variantIds' => [$variant]]]];

        return compact('tenant', 'branch', 'product', 'variant', 'sibling', 'headers', 'payload');
    }

    public function test_round_trip_legacy_omission_and_explicit_clear(): void
    {
        $f = $this->fixture();
        $payload = $f['payload'] + ['description' => 'Preserved', 'conditions' => 'Contract', 'maximumDiscountAmount' => '15.00', 'minimumOrderAmount' => '1.00', 'usageLimit' => 10, 'usageLimitPerCustomer' => 2, 'perCustomerDailyUsageLimit' => 1, 'activeDays' => ['Mon'], 'startTime' => '22:00', 'endTime' => '02:00', 'startDate' => '2026-01-01', 'endDate' => '2027-01-01', 'channelKeys' => ['pos']];
        $created = $this->postJson('/api/v1/discounts', $payload, $f['headers'])->assertCreated();
        $id = $created->json('data.id');
        $detail = $this->getJson("/api/v1/discounts/$id", $f['headers'])->assertOk();
        $this->assertSame($created->json('data'), $detail->json('data'));
        $detail->assertJsonPath('data.productVariantSelections.0.variantIds', [$f['variant']]);
        unset($payload['productVariantSelections']);
        $this->putJson("/api/v1/discounts/$id", $payload, $f['headers'])->assertOk()->assertJsonPath('data.productVariantSelections.0.variantMode', 'selected')->assertJsonPath('data.description', 'Preserved')->assertJsonPath('data.endTime', '02:00:00');
        $payload['productVariantSelections'] = [['productId' => $f['product'], 'variantMode' => 'all', 'variantIds' => []]];
        $payload['description'] = null;
        $this->putJson("/api/v1/discounts/$id", $payload, $f['headers'])->assertOk()->assertJsonPath('data.productVariantSelections.0.variantMode', 'all')->assertJsonPath('data.description', null);
        $this->assertDatabaseCount('discount_product_target_variants', 0);
    }

    public function test_rejected_writes_do_not_replace_targets(): void
    {
        $f = $this->fixture();
        $id = $this->postJson('/api/v1/discounts', $f['payload'], $f['headers'])->assertCreated()->json('data.id');
        $bad = [null, 'bad', [], [['productId' => $f['product'], 'variantMode' => 'selected', 'variantIds' => []]], [['productId' => $f['product'], 'variantMode' => 'all', 'variantIds' => [$f['variant']]]], [['productId' => $f['product'], 'variantMode' => 'selected', 'variantIds' => [$f['variant'], $f['variant']]]], [$f['payload']['productVariantSelections'][0], $f['payload']['productVariantSelections'][0]], [['productId' => $f['product'], 'variantMode' => 'other', 'variantIds' => []]], [['productId' => 999999, 'variantMode' => 'selected', 'variantIds' => [$f['variant']]]]];
        foreach ($bad as $selection) {
            $payload = $f['payload'];
            $payload['productVariantSelections'] = $selection;
            $this->putJson("/api/v1/discounts/$id", $payload, $f['headers'])->assertUnprocessable();
            $this->getJson("/api/v1/discounts/$id", $f['headers'])->assertOk()->assertJsonPath('data.productVariantSelections.0.variantIds', [$f['variant']]);
        }
        DB::table('product_variants')->where('id', $f['variant'])->update(['is_active' => false, 'deleted_at' => now()]);
        $this->putJson("/api/v1/discounts/$id", $f['payload'], $f['headers'])->assertUnprocessable();
        $this->getJson("/api/v1/discounts/$id", $f['headers'])->assertOk()->assertJsonPath('data.productVariantSelections.0.variants.0.isActive', false);
    }

    public function test_shared_matcher_uses_persisted_identity_prices_and_fractional_quantities(): void
    {
        $f = $this->fixture();
        $id = $this->postJson('/api/v1/discounts', $f['payload'], $f['headers'])->assertCreated()->json('data.id');
        $order = DB::table('orders')->insertGetId(['tenant_id' => $f['tenant'], 'branch_id' => $f['branch'], 'order_number' => 'V1', 'type' => 'takeaway', 'status' => 'held', 'payment_status' => 'unpaid', 'subtotal' => '5.03', 'total' => '5.03', 'tax_rate' => '0.080000']);
        foreach ([[$f['variant'], '0.500', '0.01'], [$f['variant'], '0.500', '0.02'], [$f['sibling'], '1.000', '2.00'], [null, '1.000', '3.00']] as [$variant, $quantity, $total]) {
            DB::table('order_items')->insert(['tenant_id' => $f['tenant'], 'order_id' => $order, 'product_id' => $f['product'], 'product_variant_id' => $variant, 'product_name' => 'Pinned coffee + modifier', 'quantity' => $quantity, 'unit_price' => '0.02', 'total' => $total]);
        }
        $calculate = fn () => app(DiscountEligibilityService::class)->assertApplicable($f['tenant'], DB::table('discounts')->find($id), DB::table('orders')->find($order));
        $this->assertSame('0.02', $calculate()['amount']); // 50% of 0.03, HALF_UP.
        DB::table('discounts')->where('id', $id)->update(['type' => 'fixed', 'value' => '0.01', 'fixed_amount_basis' => 'per_unit']);
        $this->assertSame('0.01', $calculate()['amount']); // Sum two half-cent products BEFORE rounding.
        DB::table('discounts')->where('id', $id)->update(['value' => '0.04']);
        $this->assertSame('0.03', $calculate()['amount']); // Each line is capped.
        DB::table('discounts')->where('id', $id)->update(['maximum_discount_amount' => '0.02']);
        $this->assertSame('0.02', $calculate()['amount']);
        DB::table('discounts')->where('id', $id)->update(['fixed_amount_basis' => 'per_order', 'value' => '0.01']);
        $this->assertSame('0.01', $calculate()['amount']);
        DB::table('order_discounts')->insert(['tenant_id' => $f['tenant'], 'order_id' => $order, 'discount_id' => $id, 'discount_name' => 'Pinned', 'discount_type' => 'fixed', 'discount_value' => '0.01', 'discount_amount' => '0.01']);
        $priced = app(PosPricingService::class)->recalculateOrder($f['tenant'], $order);
        $this->assertSame('0.40', $priced->tax_total);
        DB::table('discount_product_target_variants')->where('discount_id', $id)->delete();
        DB::table('discounts')->where('id', $id)->update(['type' => 'percentage', 'value' => '100', 'maximum_discount_amount' => null]);
        $this->assertSame('5.03', $calculate()['amount']); // all includes null-variant legacy lines.
    }

    public function test_references_paginate_beyond_100_and_omit_costs(): void
    {
        $f = $this->fixture();
        for ($i = 0; $i < 105; $i++) {
            DB::table('products')->insert(['tenant_id' => $f['tenant'], 'name' => 'Search coffee '.$i, 'is_active' => true]);
        }
        $this->getJson('/api/v1/discounts/references/products?search=Search&perPage=100&page=2', $f['headers'])->assertOk()->assertJsonCount(5, 'data')->assertJsonPath('meta.total', 105);
        $response = $this->getJson("/api/v1/discounts/references/products/{$f['product']}/variants", $f['headers'])->assertOk()->assertJsonCount(2, 'data');
        $this->assertArrayNotHasKey('costPrice', $response->json('data.0'));
    }

    public function test_mixed_products_and_legacy_added_removed_and_archived_selections(): void
    {
        $f = $this->fixture();
        $second = DB::table('products')->insertGetId(['tenant_id' => $f['tenant'], 'name' => 'Tea', 'is_active' => true]);
        $payload = $f['payload'];
        $payload['targetProductIds'][] = $second;
        $payload['productVariantSelections'][] = ['productId' => $second, 'variantMode' => 'all', 'variantIds' => []];
        $id = $this->postJson('/api/v1/discounts', $payload, $f['headers'])->assertCreated()->json('data.id');
        DB::table('product_variants')->where('id', $f['variant'])->update(['deleted_at' => now()]);
        unset($payload['productVariantSelections']);
        $this->putJson("/api/v1/discounts/$id", $payload, $f['headers'])->assertOk()->assertJsonPath('data.productVariantSelections.0.variantIds', [$f['variant']])->assertJsonPath('data.productVariantSelections.1.variantMode', 'all');
        $payload['targetProductIds'] = [$second];
        $this->putJson("/api/v1/discounts/$id", $payload, $f['headers'])->assertOk()->assertJsonCount(1, 'data.productVariantSelections');
        $this->assertDatabaseCount('discount_product_target_variants', 0);
        $payload['targetProductIds'][] = $f['product'];
        $this->putJson("/api/v1/discounts/$id", $payload, $f['headers'])->assertOk()->assertJsonPath('data.productVariantSelections.1.variantMode', 'all');
        $this->postJson('/api/v1/discounts', $payload, $f['headers'])->assertCreated()->assertJsonPath('data.productVariantSelections.0.variantMode', 'all');
    }

    public function test_wrong_parent_foreign_inactive_archived_and_non_product_selections_are_rejected(): void
    {
        $f = $this->fixture();
        $second = DB::table('products')->insertGetId(['tenant_id' => $f['tenant'], 'name' => 'Other', 'is_active' => true]);
        $foreign = DB::table('tenants')->insertGetId(['name' => 'Foreign', 'slug' => uniqid('foreign-')]);
        $foreignProduct = DB::table('products')->insertGetId(['tenant_id' => $foreign, 'name' => 'Foreign', 'is_active' => true]);
        $variants = [];
        foreach ([[$f['tenant'], $second, true, null], [$foreign, $foreignProduct, true, null], [$f['tenant'], $f['product'], false, null], [$f['tenant'], $f['product'], true, now()]] as [$tenant, $product, $active, $deleted]) {
            $variants[] = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Invalid', 'is_active' => $active, 'deleted_at' => $deleted]);
        }
        foreach ($variants as $variant) {
            $payload = $f['payload'];
            $payload['productVariantSelections'][0]['variantIds'] = [$variant];
            $this->postJson('/api/v1/discounts', $payload, $f['headers'])->assertUnprocessable()->assertJsonValidationErrors('productVariantSelections');
        }
        foreach ([['is_active' => false], ['is_active' => true, 'deleted_at' => now()]] as $change) {
            DB::table('products')->where('id', $f['product'])->update($change);
            $this->postJson('/api/v1/discounts', $f['payload'], $f['headers'])->assertUnprocessable();
        }
        $payload = $f['payload'];
        $payload['scope'] = 'order';
        $payload['targetProductIds'] = [];
        $payload['productVariantSelections'] = [];
        $this->postJson('/api/v1/discounts', $payload, $f['headers'])->assertUnprocessable();
        $this->assertDatabaseCount('discounts', 0);
    }

    public function test_references_require_discount_manage_without_menu_access_and_isolate_tenants(): void
    {
        $f = $this->fixture();
        $user = User::create(['tenant_id' => $f['tenant'], 'name' => 'Selector manager', 'email' => uniqid().'@test.example', 'password' => 'testing-password', 'role' => 'manager', 'is_active' => true]);
        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($f['tenant'], $user)];
        DB::table('discount_role_permissions')->where('tenant_id', $f['tenant'])->where('role', 'manager')->delete();
        $this->getJson('/api/v1/discounts/references/products', $headers)->assertForbidden();
        DB::table('discount_role_permissions')->insert(['tenant_id' => $f['tenant'], 'role' => 'manager', 'permission' => 'discounts.manage']);
        $this->getJson('/api/v1/discounts/references/products', $headers)->assertOk()->assertJsonCount(1, 'data');
        // Employees can no longer hold discounts.manage, so this selector is exercised with a Manager grant.
        $foreign = DB::table('tenants')->insertGetId(['name' => 'Foreign', 'slug' => uniqid('foreign-')]);
        $foreignProduct = DB::table('products')->insertGetId(['tenant_id' => $foreign, 'name' => 'Secret', 'is_active' => true]);
        $this->getJson("/api/v1/discounts/references/products/$foreignProduct/variants", $headers)->assertNotFound();
        $this->getJson('/api/v1/discounts/references/products?perPage=101', $headers)->assertUnprocessable();
    }

    public function test_manual_and_code_payment_revalidation_usage_and_paid_snapshot(): void
    {
        $f = $this->fixture();
        $actor = DB::table('users')->where('tenant_id', $f['tenant'])->value('id');
        app(FinancialSetupService::class)->ensureForTenant($f['tenant'], $f['branch'], $actor);
        $cashMethod = DB::table('payment_methods')->where('tenant_id', $f['tenant'])->where('type', 'cash')->value('id');
        $drawer = DB::table('branches')->where('id', $f['branch'])->value('pos_cash_financial_location_id');
        $shift = DB::table('shifts')->insertGetId(['tenant_id' => $f['tenant'], 'branch_id' => $f['branch'], 'user_id' => $actor, 'financial_location_id' => $drawer, 'status' => 'open', 'opening_cash' => 0, 'opened_at' => now()]);
        $order = DB::table('orders')->insertGetId(['tenant_id' => $f['tenant'], 'branch_id' => $f['branch'], 'shift_id' => $shift, 'order_number' => 'PAY-V1', 'type' => 'takeaway', 'status' => 'draft', 'payment_status' => 'unpaid', 'subtotal' => '10.00', 'total' => '10.00', 'tax_rate' => 0]);
        $item = DB::table('order_items')->insertGetId(['tenant_id' => $f['tenant'], 'order_id' => $order, 'product_id' => $f['product'], 'product_variant_id' => $f['variant'], 'product_name' => 'Pinned + modifier', 'quantity' => 1, 'unit_price' => '10.00', 'total' => '10.00']);
        $manual = $this->postJson('/api/v1/discounts', $f['payload'], $f['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/orders/$order/discounts/apply", ['discountId' => $manual], $f['headers'])->assertOk()->assertJsonPath('data.discount.amount', 5);
        $payload = $f['payload'];
        $payload['applicationMode'] = 'code';
        $payload['code'] = 'VARIANT-CODE';
        $code = $this->postJson('/api/v1/discounts', $payload, $f['headers'])->assertCreated()->json('data.id');
        $this->postJson("/api/v1/orders/$order/discounts/apply", ['code' => 'variant-code'], $f['headers'])->assertOk()->assertJsonPath('data.discount.amount', 5);
        $this->assertSame(1, DB::table('order_discounts')->where('order_id', $order)->count());
        DB::table('orders')->where('id', $order)->update(['status' => 'held']);
        DB::table('order_items')->where('id', $item)->update(['quantity' => '1.500', 'total' => '15.00']);
        $this->assertSame('7.50', app(PosPricingService::class)->recalculateOrder($f['tenant'], $order)->discount_total);
        // Payment rejects a policy edit that leaves only a sibling selected.
        $payload['productVariantSelections'][0]['variantIds'] = [$f['sibling']];
        $this->putJson("/api/v1/discounts/$code", $payload, $f['headers'])->assertOk();
        DB::table('orders')->where('id', $order)->update(['status' => 'draft']);
        $pay = ['method' => 'cash', 'paymentMethodId' => $cashMethod, 'amount' => '15.00', 'idempotencyKey' => 'variant-payment'];
        $this->postJson("/api/v1/orders/$order/pay", $pay, $f['headers'])->assertUnprocessable()->assertJsonPath('code', 'DISCOUNT_ITEMS_NOT_ELIGIBLE');
        $this->assertDatabaseCount('payments', 0);
        $this->assertDatabaseCount('discount_usages', 0);
        $payload['productVariantSelections'][0]['variantIds'] = [$f['variant']];
        $this->putJson("/api/v1/discounts/$code", $payload, $f['headers'])->assertOk();
        $paid = $this->postJson("/api/v1/orders/$order/pay", $pay, $f['headers'])->assertOk();
        $this->postJson("/api/v1/orders/$order/pay", $pay, $f['headers'])->assertOk()->assertJsonPath('data.payment.id', $paid->json('data.payment.id'));
        $this->assertDatabaseCount('discount_usages', 1);
        $snapshot = (array) DB::table('order_discounts')->where('order_id', $order)->first();
        $totals = (array) DB::table('orders')->find($order);
        $payload['value'] = 0;
        $payload['productVariantSelections'][0]['variantMode'] = 'all';
        $payload['productVariantSelections'][0]['variantIds'] = [];
        $this->putJson("/api/v1/discounts/$code", $payload, $f['headers'])->assertOk();
        DB::table('products')->where('id', $f['product'])->update(['price' => '700.00', 'deleted_at' => now()]);
        app(PosPricingService::class)->recalculateOrder($f['tenant'], $order);
        $this->assertSame($snapshot, (array) DB::table('order_discounts')->where('order_id', $order)->first());
        $this->assertSame($totals, (array) DB::table('orders')->find($order));
    }

    public function test_customer_and_cart_mutations_remove_ineligible_selected_discount(): void
    {
        $f = $this->fixture();
        $customer = DB::table('customers')->insertGetId(['tenant_id' => $f['tenant'], 'name' => 'Customer', 'customer_number' => 'V-C1', 'normalized_name' => 'customer', 'is_active' => true]);
        $payload = $f['payload'];
        $payload['customerEligibilityMode'] = 'selected_customers';
        $payload['customerIds'] = [$customer];
        $id = $this->postJson('/api/v1/discounts', $payload, $f['headers'])->assertCreated()->json('data.id');
        $order = DB::table('orders')->insertGetId(['tenant_id' => $f['tenant'], 'branch_id' => $f['branch'], 'customer_id' => $customer, 'order_number' => 'CUSTOMER-V1', 'type' => 'takeaway', 'status' => 'draft', 'payment_status' => 'unpaid', 'subtotal' => 10, 'total' => 10, 'tax_rate' => 0]);
        $item = DB::table('order_items')->insertGetId(['tenant_id' => $f['tenant'], 'order_id' => $order, 'product_id' => $f['product'], 'product_variant_id' => $f['variant'], 'product_name' => 'Pinned', 'quantity' => 1, 'unit_price' => 10, 'total' => 10]);
        $this->postJson("/api/v1/orders/$order/discounts/apply", ['discountId' => $id], $f['headers'])->assertOk();
        $this->patchJson("/api/v1/orders/$order", ['customerId' => null], $f['headers'])->assertOk();
        $this->assertSame(0, DB::table('order_discounts')->where('order_id', $order)->count());
        $this->patchJson("/api/v1/orders/$order", ['customerId' => $customer], $f['headers'])->assertOk();
        $this->postJson("/api/v1/orders/$order/discounts/apply", ['discountId' => $id], $f['headers'])->assertOk();
        DB::table('order_items')->where('id', $item)->update(['product_variant_id' => $f['sibling']]);
        app(PosPricingService::class)->recalculateOrder($f['tenant'], $order);
        $this->assertSame(0, DB::table('order_discounts')->where('order_id', $order)->count());
    }

    public function test_variant_zero_and_hundred_percent_policies_and_whole_order_minimum(): void
    {
        $f = $this->fixture();
        $payload = $f['payload'];
        $payload['minimumOrderAmount'] = '20.00';
        $id = $this->postJson('/api/v1/discounts', $payload, $f['headers'])->assertCreated()->json('data.id');
        $order = DB::table('orders')->insertGetId(['tenant_id' => $f['tenant'], 'branch_id' => $f['branch'], 'order_number' => 'ZERO-V1', 'type' => 'takeaway', 'status' => 'draft', 'payment_status' => 'unpaid', 'subtotal' => 30, 'total' => 30, 'tax_rate' => 0]);
        foreach ([[$f['variant'], 10], [$f['sibling'], 20]] as [$variant, $total]) {
            DB::table('order_items')->insert(['tenant_id' => $f['tenant'], 'order_id' => $order, 'product_id' => $f['product'], 'product_variant_id' => $variant, 'product_name' => 'Pinned', 'quantity' => 1, 'unit_price' => $total, 'total' => $total]);
        }
        foreach ([['percentage', 0, 0], ['fixed', 0, 0], ['percentage', 100, 10]] as [$type, $value, $amount]) {
            $payload['type'] = $type;
            $payload['value'] = $value;
            $this->putJson("/api/v1/discounts/$id", $payload, $f['headers'])->assertOk();
            $this->postJson("/api/v1/orders/$order/discounts/apply", ['discountId' => $id], $f['headers'])->assertOk()->assertJsonPath('data.discount.amount', $amount);
        }
    }

    public function test_storage_enforces_parent_identity_and_prevents_hard_delete_broadening(): void
    {
        $f = $this->fixture();
        $id = $this->postJson('/api/v1/discounts', $f['payload'], $f['headers'])->assertCreated()->json('data.id');
        $row = (array) DB::table('discount_product_target_variants')->where('discount_id', $id)->first();
        unset($row['id']);
        foreach ([fn () => DB::table('discount_product_target_variants')->insert($row),
            fn () => DB::table('discount_product_target_variants')->where('discount_id', $id)->update(['product_id' => 999999]),
            fn () => DB::table('product_variants')->where('id', $f['variant'])->delete()] as $write) {
            try {
                DB::transaction($write);
                $this->fail('The database must reject duplicate or invalid selected identities.');
            } catch (QueryException $exception) {
                $this->assertStringStartsWith('23', $exception->errorInfo[0]);
            }
        }
        $this->getJson("/api/v1/discounts/$id", $f['headers'])->assertOk()->assertJsonPath('data.productVariantSelections.0.variantIds', [$f['variant']]);
    }

    public function test_mixed_all_and_selected_matches_for_both_application_modes_and_all_calculations(): void
    {
        $f = $this->fixture();
        $otherProduct = DB::table('products')->insertGetId(['tenant_id' => $f['tenant'], 'name' => 'All tea', 'is_active' => true]);
        $order = DB::table('orders')->insertGetId(['tenant_id' => $f['tenant'], 'branch_id' => $f['branch'], 'order_number' => 'MIX-V1', 'type' => 'takeaway', 'status' => 'draft', 'payment_status' => 'unpaid', 'subtotal' => 34, 'total' => 34, 'tax_rate' => 0]);
        foreach ([[$f['product'], $f['variant'], '1.500', 10], [$f['product'], $f['sibling'], '1.000', 20], [$otherProduct, null, '2.000', 4]] as [$product, $variant, $quantity, $total]) {
            DB::table('order_items')->insert(['tenant_id' => $f['tenant'], 'order_id' => $order, 'product_id' => $product, 'product_variant_id' => $variant, 'product_name' => 'Selling snapshot', 'quantity' => $quantity, 'unit_price' => 2, 'total' => $total]);
        }
        foreach (['manual', 'code'] as $mode) {
            foreach ([['percentage', 'per_order', 50, 7], ['fixed', 'per_order', 2, 2], ['fixed', 'per_unit', 2, 7]] as [$type, $basis, $value, $expected]) {
                $payload = $f['payload'];
                $payload['applicationMode'] = $mode;
                $payload['code'] = $mode === 'code' ? strtoupper(uniqid('MIX-')) : null;
                $payload['type'] = $type;
                $payload['fixedAmountBasis'] = $basis;
                $payload['value'] = $value;
                $payload['targetProductIds'][] = $otherProduct;
                $payload['productVariantSelections'][] = ['productId' => $otherProduct, 'variantMode' => 'all', 'variantIds' => []];
                $id = $this->postJson('/api/v1/discounts', $payload, $f['headers'])->assertCreated()->json('data.id');
                $this->postJson("/api/v1/orders/$order/discounts/apply", $mode === 'manual' ? ['discountId' => $id] : ['code' => $payload['code']], $f['headers'])->assertOk()->assertJsonPath('data.discount.amount', $expected);
                $this->assertSame(1, DB::table('order_discounts')->where('order_id', $order)->count());
            }
        }
    }
}
