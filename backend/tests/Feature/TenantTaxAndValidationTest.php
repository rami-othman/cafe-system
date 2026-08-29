<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class TenantTaxAndValidationTest extends TestCase
{
    use RefreshDatabase;

    public function test_branch_returns_tenant_tax_and_orders_keep_an_immutable_tax_snapshot(): void
    {
        $tenant = $this->tenant('0.075000');
        $headers = ['X-Tenant-Id' => $tenant['tenantId']];

        $this->getJson('/api/v1/branches', $headers)
            ->assertOk()
            ->assertJsonPath('data.0.taxRate', 0.075);

        $order = $this->postJson('/api/v1/orders', $this->orderPayload($tenant), $headers)
            ->assertCreated()
            ->assertJsonPath('data.totals.taxRate', 0.075)
            ->assertJsonPath('data.totals.taxTotal', 0.75);

        DB::table('tenants')->where('id', $tenant['tenantId'])->update(['tax_rate' => '0.150000']);

        $this->postJson("/api/v1/orders/{$order->json('data.id')}/items", [
            'productId' => $tenant['productId'], 'quantity' => 1,
        ], $headers)->assertCreated()
            ->assertJsonPath('data.totals.taxRate', 0.075)
            ->assertJsonPath('data.totals.taxTotal', 1.5);

        $this->putJson("/api/v1/orders/{$order->json('data.id')}/discount", [
            'type' => 'fixed', 'value' => 5,
        ], $headers)->assertOk()
            ->assertJsonPath('data.totals.taxTotal', 1.13);

        $this->getJson("/api/v1/orders/{$order->json('data.id')}/receipt", $headers)
            ->assertOk()
            ->assertJsonPath('data.taxRate', 0.075);
    }

    public function test_cross_tenant_order_references_are_rejected_with_validation_errors(): void
    {
        $tenantA = $this->tenant('0.080000');
        $tenantB = $this->tenant('0.080000');
        $headers = ['X-Tenant-Id' => $tenantA['tenantId']];

        foreach (['branchId', 'shiftId', 'tableId', 'customerId'] as $field) {
            $payload = $this->orderPayload($tenantA);
            $payload[$field] = $tenantB[$field];
            $this->postJson('/api/v1/orders', $payload, $headers)
                ->assertUnprocessable()
                ->assertJsonValidationErrors($field);
        }

        $payload = $this->orderPayload($tenantA);
        $payload['items'][0]['productId'] = $tenantB['productId'];
        $this->postJson('/api/v1/orders', $payload, $headers)
            ->assertUnprocessable()
            ->assertJsonValidationErrors('items.0.productId');

        $this->postJson('/api/v1/orders', $this->orderPayload($tenantA), $headers)
            ->assertCreated()
            ->assertJsonPath('data.totals.taxRate', 0.08)
            ->assertJsonPath('data.totals.taxTotal', 0.8);
    }

    private function tenant(string $taxRate): array
    {
        $now = now();
        $tenantId = DB::table('tenants')->insertGetId([
            'name' => 'Tenant '.Str::random(8), 'slug' => Str::random(16), 'tax_rate' => $taxRate,
            'created_at' => $now, 'updated_at' => $now,
        ]);
        $branchId = DB::table('branches')->insertGetId([
            'tenant_id' => $tenantId, 'name' => 'Main', 'created_at' => $now, 'updated_at' => $now,
        ]);
        $userId = DB::table('users')->insertGetId([
            'tenant_id' => $tenantId, 'name' => 'Cashier', 'email' => Str::random(12).'@test.local',
            'password' => 'secret', 'created_at' => $now, 'updated_at' => $now,
        ]);
        $categoryId = DB::table('categories')->insertGetId([
            'tenant_id' => $tenantId, 'name' => 'Drinks', 'created_at' => $now, 'updated_at' => $now,
        ]);
        $productId = DB::table('products')->insertGetId([
            'tenant_id' => $tenantId, 'category_id' => $categoryId, 'name' => 'Coffee', 'price' => 10,
            'created_at' => $now, 'updated_at' => $now,
        ]);
        $tableId = DB::table('cafe_tables')->insertGetId([
            'tenant_id' => $tenantId, 'branch_id' => $branchId, 'name' => 'Table 1', 'created_at' => $now, 'updated_at' => $now,
        ]);
        $customerId = DB::table('customers')->insertGetId([
            'tenant_id' => $tenantId, 'name' => 'Customer', 'created_at' => $now, 'updated_at' => $now,
        ]);
        $shiftId = DB::table('shifts')->insertGetId([
            'tenant_id' => $tenantId, 'branch_id' => $branchId, 'user_id' => $userId, 'status' => 'open',
            'opened_at' => $now, 'created_at' => $now, 'updated_at' => $now,
        ]);

        return compact('tenantId', 'branchId', 'shiftId', 'tableId', 'customerId', 'productId');
    }

    private function orderPayload(array $tenant): array
    {
        return [
            'branchId' => $tenant['branchId'], 'shiftId' => $tenant['shiftId'], 'tableId' => $tenant['tableId'],
            'customerId' => $tenant['customerId'], 'orderType' => 'dine_in',
            'items' => [['productId' => $tenant['productId'], 'quantity' => 1]],
        ];
    }
}
