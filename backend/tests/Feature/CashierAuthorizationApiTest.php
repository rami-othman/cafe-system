<?php

namespace Tests\Feature;

use Database\Seeders\TenantAccessSeeder;
use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Proves the cashier (role = employee) authorization boundary end to end:
 * the POS/Orders/Customers/Discounts/own-shift surface stays open, the
 * cashier's own required bar check can be completed and posted, and every
 * administrative/finance/inventory surface returns 403 — including another
 * user's shift and another branch's bar check. Owner/manager behavior is
 * spot-checked to confirm it is unchanged by the InventoryAccess tightening.
 */
class CashierAuthorizationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_cashier_cannot_write_operational_documents_without_an_open_shift(): void
    {
        $tenant = $this->bootTenant();
        $branch = $this->branch($tenant);
        $cashier = $this->assignedUser($tenant, $branch, 'employee');
        $headers = $this->headers($tenant, $cashier);
        foreach (['orders', 'finance/vouchers', 'finance/sales-invoices', 'finance/supplier-invoices'] as $path) {
            $this->postJson('/api/v1/'.$path, ['branchId' => $branch], $headers)
                ->assertUnprocessable()->assertJsonPath('code', 'NO_OPEN_SHIFT');
        }
        $this->assertSame(0, DB::table('finance_documents')->where('tenant_id', $tenant)->count());
        $this->getJson('/api/v1/orders', $headers)->assertOk();
        $this->getJson("/api/v1/shifts/current?branchId=$branch", $headers)->assertOk();
    }

    public function test_cashier_documents_work_after_opening_and_stop_after_closing(): void
    {
        $tenant = $this->bootTenant();
        $branch = $this->branch($tenant);
        $cashier = $this->assignedUser($tenant, $branch, 'employee');
        $headers = $this->headers($tenant, $cashier);
        $shift = $this->openShift($tenant, $branch, $cashier);
        $account = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '4000')->value('id');
        $payload = ['branchId' => $branch, 'documentType' => 'receipt', 'documentDate' => now()->toDateString(),
            'amount' => '10.00', 'lines' => [['accountId' => $account, 'amount' => '10.00']]];
        $document = $this->postJson('/api/v1/finance/vouchers', $payload, $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/vouchers/$document/post", [], $headers)->assertOk();
        $this->postJson("/api/v1/shifts/$shift/close", ['closingCash' => '10.00'], $headers)->assertOk();
        $this->postJson('/api/v1/finance/vouchers', $payload, $headers)
            ->assertUnprocessable()->assertJsonPath('code', 'NO_OPEN_SHIFT');
        $this->patchJson('/api/v1/orders/999', [], $headers)
            ->assertUnprocessable()->assertJsonPath('code', 'NO_OPEN_SHIFT');
    }

    public function test_cashier_cannot_use_another_users_open_shift(): void
    {
        $tenant = $this->bootTenant();
        $branch = $this->branch($tenant);
        $other = $this->assignedUser($tenant, $branch, 'employee');
        $cashier = $this->assignedUser($tenant, $branch, 'employee');
        $this->openShift($tenant, $branch, $other);
        $this->postJson('/api/v1/finance/sales-invoices', ['branchId' => $branch], $this->headers($tenant, $cashier))
            ->assertUnprocessable()->assertJsonPath('code', 'NO_OPEN_SHIFT');
    }

    public function test_open_shift_in_another_branch_does_not_authorize_a_voucher(): void
    {
        $tenant = $this->bootTenant();
        $branch = $this->branch($tenant);
        $otherBranch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Second cafe',
            'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $cashier = $this->assignedUser($tenant, $branch, 'employee');
        DB::table('user_branches')->insert(['tenant_id' => $tenant, 'user_id' => $cashier, 'branch_id' => $otherBranch,
            'created_at' => now(), 'updated_at' => now()]);
        $this->openShift($tenant, $branch, $cashier);
        $headers = $this->headers($tenant, $cashier);
        $this->postJson('/api/v1/finance/vouchers', ['branchId' => $otherBranch], $headers)
            ->assertUnprocessable()->assertJsonPath('code', 'NO_OPEN_SHIFT');
        $drawer = app(FinancialSetupService::class)->ensureBranchCashDrawer($tenant, $otherBranch);
        $account = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '4000')->value('id');
        $document = $this->postJson('/api/v1/finance/vouchers', [
            'branchId' => $otherBranch, 'financialLocationId' => $drawer,
            'documentType' => 'receipt', 'documentDate' => now()->toDateString(),
            'amount' => '10.00', 'lines' => [['accountId' => $account, 'amount' => '10.00']],
        ], $this->headers($tenant, $this->owner($tenant)))->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/vouchers/$document/post", ['branchId' => $branch], $headers)
            ->assertUnprocessable()->assertJsonPath('code', 'NO_OPEN_SHIFT');
        $this->assertSame('draft', DB::table('finance_documents')->where('id', $document)->value('status'));
    }

    public function test_cashier_order_requires_the_actual_open_shift_even_on_legacy_order_api(): void
    {
        $tenant = $this->bootTenant();
        $branch = $this->branch($tenant);
        $cashier = $this->assignedUser($tenant, $branch, 'employee');
        $shift = $this->openShift($tenant, $branch, $cashier);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => 'Shift test coffee',
            'price' => '10.00', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $variant = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product,
            'name' => 'Regular', 'base_price' => '10.00', 'is_default' => true, 'is_active' => true,
            'created_at' => now(), 'updated_at' => now()]);
        $payload = ['branchId' => $branch, 'orderType' => 'takeaway',
            'items' => [['productId' => $product, 'variantId' => $variant, 'quantity' => 1]]];
        $headers = $this->headers($tenant, $cashier);
        $this->postJson('/api/v1/orders', $payload, $headers)->assertUnprocessable()->assertJsonValidationErrors('shiftId');
        $this->assertSame(0, DB::table('orders')->where('tenant_id', $tenant)->count());
        $this->postJson('/api/v1/orders', $payload + ['shiftId' => $shift], $headers)
            ->assertCreated()->assertJsonPath('data.shiftId', $shift);
    }

    public function test_cashier_can_access_pos_orders_customers_and_discounts(): void
    {
        $tenant = $this->bootTenant();
        $branch = $this->branch($tenant);
        $cashier = $this->assignedUser($tenant, $branch, 'employee');

        $this->getJson("/api/v1/pos/state?branchId=$branch", $this->headers($tenant, $cashier))->assertOk();
        $this->getJson('/api/v1/orders', $this->headers($tenant, $cashier))->assertOk();
        $this->getJson('/api/v1/customers', $this->headers($tenant, $cashier))->assertOk();
        $this->getJson('/api/v1/discounts', $this->headers($tenant, $cashier))->assertOk();
    }

    public function test_cashier_can_fetch_and_close_own_shift(): void
    {
        $tenant = $this->bootTenant();
        $branch = $this->branch($tenant);
        $cashier = $this->assignedUser($tenant, $branch, 'employee');
        $shift = $this->openShift($tenant, $branch, $cashier);

        $this->getJson("/api/v1/shifts/current?branchId=$branch", $this->headers($tenant, $cashier))
            ->assertOk()
            ->assertJsonPath('data.id', $shift);

        $this->postJson("/api/v1/shifts/$shift/close", ['closingCash' => '0.00'], $this->headers($tenant, $cashier))
            ->assertOk()
            ->assertJsonPath('data.status', 'closed');
    }

    public function test_cashier_can_complete_and_post_own_required_bar_check_then_close_shift(): void
    {
        $tenant = $this->bootTenant();
        $branch = $this->branch($tenant);
        $owner = $this->owner($tenant);
        $cashier = $this->assignedUser($tenant, $branch, 'employee');
        [$warehouse, $item] = $this->barWarehouseWithItem($tenant, $branch);

        $this->postJson('/api/v1/inventory/bar-check-templates', [
            'branchId' => $branch,
            'warehouseId' => $warehouse,
            'requiredForShiftClose' => true,
            'lines' => [['itemId' => $item, 'countUnit' => 'kilogram', 'required' => true, 'toleranceType' => 'quantity', 'tolerance' => '5.000']],
        ], $this->headers($tenant, $owner))->assertCreated();

        $shift = $this->openShift($tenant, $branch, $cashier);

        // Closing before the required bar check is posted must still be blocked.
        $this->postJson("/api/v1/shifts/$shift/close", ['closingCash' => '0.00'], $this->headers($tenant, $cashier))
            ->assertUnprocessable();

        $check = (int) $this->postJson('/api/v1/inventory/bar-checks', ['shiftId' => $shift, 'warehouseId' => $warehouse], $this->headers($tenant, $cashier))
            ->assertCreated()
            ->json('data.stockCountId');

        $this->putJson("/api/v1/inventory/counts/$check/lines", ['itemId' => $item, 'countedQuantity' => '0.000', 'unit' => 'kilogram'], $this->headers($tenant, $cashier))
            ->assertOk();
        $this->postJson("/api/v1/inventory/counts/$check/submit", [], $this->headers($tenant, $cashier))->assertOk();
        $this->postJson("/api/v1/inventory/counts/$check/approve", [], $this->headers($tenant, $cashier))->assertOk();
        $this->postJson("/api/v1/inventory/counts/$check/post", [], $this->headers($tenant, $cashier))
            ->assertOk()
            ->assertJsonPath('data.status', 'posted');

        $this->postJson("/api/v1/shifts/$shift/close", ['closingCash' => '0.00'], $this->headers($tenant, $cashier))
            ->assertOk()
            ->assertJsonPath('data.status', 'closed');
    }

    public function test_cashier_cannot_access_finance_reports_settings_or_full_inventory(): void
    {
        $tenant = $this->bootTenant();
        $branch = $this->branch($tenant);
        $cashier = $this->assignedUser($tenant, $branch, 'employee');
        $headers = $this->headers($tenant, $cashier);

        $this->getJson('/api/v1/finance/dashboard', $headers)->assertForbidden();
        $this->getJson('/api/v1/reports/daily', $headers)->assertForbidden();
        $this->getJson('/api/v1/cafe-configuration/branches', $headers)->assertForbidden();
        $this->getJson('/api/v1/employees', $headers)->assertForbidden();

        $this->getJson('/api/v1/inventory/items', $headers)->assertForbidden();
        $this->getJson('/api/v1/inventory/balances', $headers)->assertForbidden();
        $this->getJson('/api/v1/inventory/movements', $headers)->assertForbidden();
        $this->getJson('/api/v1/warehouses', $headers)->assertForbidden();
        $this->getJson('/api/v1/inventory/transfers', $headers)->assertForbidden();
        $this->getJson('/api/v1/inventory/counts', $headers)->assertForbidden();
        $this->postJson('/api/v1/inventory/counts', ['warehouseId' => 1, 'countDate' => now()->toDateString()], $headers)->assertForbidden();

        [$warehouse, $item] = $this->barWarehouseWithItem($tenant, $branch);
        $this->postJson('/api/v1/inventory/movements', [
            'warehouseId' => $warehouse, 'itemId' => $item, 'type' => 'stock_in', 'quantity' => '1.000', 'unitCost' => '1.0000',
        ], $headers)->assertForbidden();
    }

    public function test_cashier_cannot_touch_another_users_shift(): void
    {
        $tenant = $this->bootTenant();
        $branch = $this->branch($tenant);
        $cashierA = $this->assignedUser($tenant, $branch, 'employee');
        $cashierB = $this->assignedUser($tenant, $branch, 'employee');
        $shiftB = $this->openShift($tenant, $branch, $cashierB);

        $this->postJson("/api/v1/shifts/$shiftB/close", ['closingCash' => '0.00'], $this->headers($tenant, $cashierA))
            ->assertForbidden();

        [$warehouse] = $this->barWarehouseWithItem($tenant, $branch);
        $this->postJson('/api/v1/inventory/bar-checks', ['shiftId' => $shiftB, 'warehouseId' => $warehouse], $this->headers($tenant, $cashierA))
            ->assertForbidden();
    }

    public function test_cashier_cannot_access_another_branch_bar_check(): void
    {
        $tenant = $this->bootTenant();
        $branchA = $this->branch($tenant);
        $branchB = (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Branch B', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $cashierA = $this->assignedUser($tenant, $branchA, 'employee');
        $cashierB = $this->assignedUser($tenant, $branchB, 'employee');
        [$warehouseB, $itemB] = $this->barWarehouseWithItem($tenant, $branchB);
        $shiftB = $this->openShift($tenant, $branchB, $cashierB);
        $owner = $this->owner($tenant);
        $this->postJson('/api/v1/inventory/bar-check-templates', [
            'branchId' => $branchB, 'warehouseId' => $warehouseB, 'requiredForShiftClose' => false,
            'lines' => [['itemId' => $itemB, 'countUnit' => 'kilogram', 'required' => true]],
        ], $this->headers($tenant, $owner))->assertCreated();
        $check = (int) $this->postJson('/api/v1/inventory/bar-checks', ['shiftId' => $shiftB, 'warehouseId' => $warehouseB], $this->headers($tenant, $cashierB))
            ->assertCreated()->json('data.stockCountId');

        $this->getJson("/api/v1/inventory/counts/$check", $this->headers($tenant, $cashierA))->assertForbidden();
        $this->putJson("/api/v1/inventory/counts/$check/lines", ['itemId' => $itemB, 'countedQuantity' => '0.000', 'unit' => 'kilogram'], $this->headers($tenant, $cashierA))->assertForbidden();
    }

    public function test_cashier_cannot_administer_bar_check_templates_or_review_lines(): void
    {
        $tenant = $this->bootTenant();
        $branch = $this->branch($tenant);
        $owner = $this->owner($tenant);
        $cashier = $this->assignedUser($tenant, $branch, 'employee');
        [$warehouse, $item] = $this->barWarehouseWithItem($tenant, $branch);

        $this->postJson('/api/v1/inventory/bar-check-templates', [
            'branchId' => $branch, 'warehouseId' => $warehouse, 'requiredForShiftClose' => false,
            'lines' => [['itemId' => $item, 'countUnit' => 'kilogram', 'required' => true]],
        ], $this->headers($tenant, $cashier))->assertForbidden();

        $template = (int) $this->postJson('/api/v1/inventory/bar-check-templates', [
            'branchId' => $branch, 'warehouseId' => $warehouse, 'requiredForShiftClose' => true,
            'lines' => [['itemId' => $item, 'countUnit' => 'kilogram', 'required' => true, 'toleranceType' => 'quantity', 'tolerance' => '0.000', 'managerReviewThreshold' => '0.000', 'requiresReviewWhenExceeded' => true]],
        ], $this->headers($tenant, $owner))->assertCreated()->json('data.id');

        $shift = $this->openShift($tenant, $branch, $cashier);
        $check = (int) $this->postJson('/api/v1/inventory/bar-checks', ['shiftId' => $shift, 'warehouseId' => $warehouse], $this->headers($tenant, $cashier))
            ->assertCreated()->json('data.stockCountId');
        $this->putJson("/api/v1/inventory/counts/$check/lines", ['itemId' => $item, 'countedQuantity' => '9.000', 'unit' => 'kilogram', 'reason' => 'Large variance'], $this->headers($tenant, $cashier))->assertOk();

        $this->postJson("/api/v1/inventory/counts/$check/lines/$item/review", ['decision' => 'approved'], $this->headers($tenant, $cashier))
            ->assertForbidden();

        // The cashier still cannot approve/post while a manager review is pending.
        $this->postJson("/api/v1/inventory/counts/$check/submit", [], $this->headers($tenant, $cashier))->assertOk();
        $this->postJson("/api/v1/inventory/counts/$check/approve", [], $this->headers($tenant, $cashier))->assertUnprocessable();
    }

    public function test_owner_and_manager_retain_full_inventory_and_bar_check_administration(): void
    {
        $tenant = $this->bootTenant();
        $branch = $this->branch($tenant);
        $owner = $this->owner($tenant);
        $manager = $this->assignedUser($tenant, $branch, 'manager');
        [$warehouse, $item] = $this->barWarehouseWithItem($tenant, $branch);

        $this->getJson('/api/v1/inventory/items', $this->headers($tenant, $owner))->assertOk();
        $this->getJson('/api/v1/inventory/items', $this->headers($tenant, $manager))->assertOk();
        $this->getJson('/api/v1/inventory/transfers', $this->headers($tenant, $manager))->assertOk();

        $template = (int) $this->postJson('/api/v1/inventory/bar-check-templates', [
            'branchId' => $branch, 'warehouseId' => $warehouse, 'requiredForShiftClose' => false,
            'lines' => [['itemId' => $item, 'countUnit' => 'kilogram', 'required' => true]],
        ], $this->headers($tenant, $owner))->assertCreated()->json('data.id');
        $this->patchJson("/api/v1/inventory/bar-check-templates/$template", ['name' => 'Updated'], $this->headers($tenant, $manager))
            ->assertOk()
            ->assertJsonPath('data.name', 'Updated');
    }

    private function bootTenant(): int
    {
        $this->seed(TenantAccessSeeder::class);
        $tenant = $this->tenant('cafe-618');
        app(FinancialSetupService::class)->ensureForTenant($tenant);

        return $tenant;
    }

    private function tenant(string $slug): int
    {
        return (int) DB::table('tenants')->where('slug', $slug)->value('id');
    }

    private function owner(int $tenant): int
    {
        return (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
    }

    private function branch(int $tenant): int
    {
        return (int) DB::table('branches')->where('tenant_id', $tenant)->orderBy('id')->value('id');
    }

    private function assignedUser(int $tenant, int $branch, string $role): int
    {
        $userId = (int) DB::table('users')->insertGetId([
            'tenant_id' => $tenant,
            'name' => ucfirst($role).'-'.uniqid(),
            'email' => strtolower($role).'-'.uniqid().'@example.test',
            'password' => bcrypt('password'),
            'role' => $role,
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('user_branches')->insert(['tenant_id' => $tenant, 'user_id' => $userId, 'branch_id' => $branch, 'created_at' => now(), 'updated_at' => now()]);

        return $userId;
    }

    private function openShift(int $tenant, int $branch, int $user): int
    {
        app(FinancialSetupService::class)->ensureBranchCashDrawer($tenant, $branch);
        $safe = DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        DB::table('branches')->where('tenant_id', $tenant)->where('id', $branch)
            ->update(['shift_close_destination_financial_location_id' => $safe]);
        return (int) $this->postJson('/api/v1/shifts/current', ['branchId' => $branch, 'openingCash' => '0.00'], $this->headers($tenant, $user))
            ->assertCreated()
            ->json('data.id');
    }

    /** @return array{0:int,1:int} [warehouseId, inventoryItemId] */
    private function barWarehouseWithItem(int $tenant, int $branch): array
    {
        $owner = $this->owner($tenant);
        $warehouse = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('branch_id', $branch)->where('code', 'not like', 'LEGACY-%')->value('id');
        if (! $warehouse) {
            $warehouse = (int) DB::table('warehouses')->insertGetId(['tenant_id' => $tenant, 'branch_id' => $branch, 'name' => 'Bar', 'code' => 'BAR-'.$branch, 'type' => 'other', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        }
        $item = (int) $this->postJson('/api/v1/inventory/items', [
            'nameAr' => 'صنف اختبار', 'nameEn' => 'Test item', 'sku' => 'CASHIER-TEST-'.uniqid(),
            'itemType' => 'raw_material', 'unit' => 'kilogram', 'minimumStock' => '0.000', 'reorderLevel' => '0.000',
            'latestUnitCost' => '1.0000', 'warehouseIds' => [$warehouse], 'isActive' => true,
        ], $this->headers($tenant, $owner))->assertCreated()->json('data.id');

        return [$warehouse, $item];
    }

    private function headers(int $tenant, int $user): array
    {
        $plainToken = 'cashier-auth-test-'.$tenant.'-'.$user;
        DB::table('api_tokens')->updateOrInsert(
            ['tenant_id' => $tenant, 'user_id' => $user, 'name' => 'cashier-auth-test'],
            ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()],
        );

        return ['Authorization' => "Bearer $plainToken"];
    }
}
