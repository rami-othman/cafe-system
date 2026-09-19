<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\FinancialSetupService;
use App\Services\PurchaseCashSourceResolver;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;
use Symfony\Component\HttpKernel\Exception\HttpException;

final class BranchCashDrawerTest extends TestCase
{
    use RefreshDatabase;

    public function test_setup_is_idempotent_and_cash_method_is_shared_without_replacing_legacy_location(): void
    {
        [$tenant, $a, $b] = $this->tenantWithBranches();
        $setup = app(FinancialSetupService::class);
        $setup->ensureForTenant($tenant);
        $drawers = $this->drawers($tenant);
        $this->assertCount(2, $drawers);
        $this->assertEqualsCanonicalizing([$a, $b], $drawers->pluck('branch_id')->map(fn ($id) => (int) $id)->all());
        $this->assertSame(1, $drawers->pluck('financial_account_id')->unique()->count());
        $ids = $drawers->pluck('id')->all();
        $legacyId = DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        $bankId = DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'BANK')->value('id');
        $transferId = DB::table('cash_transfers')->insertGetId([
            'tenant_id' => $tenant, 'from_financial_location_id' => $legacyId,
            'to_financial_location_id' => $bankId, 'amount' => '10.00',
            'transfer_date' => now()->toDateString(), 'status' => 'posted', 'created_at' => now(),
        ]);
        $setup->ensureForTenant($tenant);
        $this->assertSame($ids, $this->drawers($tenant)->pluck('id')->all());
        $this->assertNull(DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('financial_location_id'));
        $this->assertSame($legacyId, DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id'));
        $this->assertSame((int) $legacyId, (int) DB::table('cash_transfers')->where('id', $transferId)->value('from_financial_location_id'));
    }

    public function test_new_branch_api_creates_a_branch_drawer(): void
    {
        [$tenant] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $token = $this->authenticateTenantUser($tenant);
        $branchId = (int) $this->postJson('/api/v1/cafe-configuration/branches', [
            'name' => 'New Branch', 'timezone' => 'Asia/Damascus',
        ], ['Authorization' => 'Bearer '.$token])->assertCreated()->json('data.id');
        $this->assertSame(1, $this->drawers($tenant)->where('branch_id', $branchId)->count());
    }

    public function test_legacy_null_shift_binds_only_to_its_branch_drawer_and_shared_cash_method(): void
    {
        [$tenant, $a, $b] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashier = $this->cashier($tenant, $a);
        $shiftId = DB::table('shifts')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $a, 'user_id' => $cashier->id,
            'shift_number' => 'TEST-LEGACY-SHIFT', 'opening_cash' => '100.00',
            'status' => 'open', 'opened_at' => now(), 'financial_location_id' => null,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $resolved = app(PurchaseCashSourceResolver::class)->resolve($tenant, $cashier->id, $a, true);
        $this->assertSame($a, (int) $resolved->location->branch_id);
        $this->assertSame((int) $resolved->location->id, (int) DB::table('shifts')->where('id', $shiftId)->value('financial_location_id'));
        $this->assertNull($resolved->method->financial_location_id);
        $this->assertNotEquals(DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id'), $resolved->location->id);
        $this->assertNotEquals($b, (int) $resolved->location->branch_id);
    }

    public function test_duplicate_branch_drawers_are_not_guessed(): void
    {
        [$tenant, $a] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $accountId = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        DB::table('financial_locations')->insert([
            'tenant_id' => $tenant, 'branch_id' => $a, 'financial_account_id' => $accountId,
            'code' => 'DUPLICATE-DRAWER', 'name' => 'Duplicate', 'kind' => 'cash',
            'type' => 'cash_drawer', 'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
        $owner = User::query()->create([
            'tenant_id' => $tenant, 'name' => 'Owner', 'email' => 'drawer-owner@example.test',
            'password' => 'password', 'role' => 'owner', 'is_active' => true,
        ]);
        $this->expectException(ValidationException::class);
        app(PurchaseCashSourceResolver::class)->resolve($tenant, $owner->id, $a);
    }

    public function test_cashier_cannot_resolve_another_branch_drawer(): void
    {
        [$tenant, $a, $b] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashier = $this->cashier($tenant, $a);
        try {
            app(PurchaseCashSourceResolver::class)->resolve($tenant, $cashier->id, $b);
            $this->fail('A cashier must not resolve another branch drawer.');
        } catch (HttpException $exception) {
            $this->assertSame(403, $exception->getStatusCode());
        }
    }

    public function test_new_shift_records_its_branch_drawer_at_opening(): void
    {
        [$tenant, $a] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashier = $this->cashier($tenant, $a);
        $token = $this->authenticateTenantUser($tenant, $cashier);
        $shiftId = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $a, 'openingCash' => '100.00',
        ], ['Authorization' => 'Bearer '.$token])->assertCreated()->json('data.id');
        $this->assertSame(
            (int) $this->drawers($tenant)->where('branch_id', $a)->first()->id,
            (int) DB::table('shifts')->where('id', $shiftId)->value('financial_location_id'),
        );
    }

    public function test_financial_location_api_rejects_a_second_active_branch_drawer(): void
    {
        [$tenant, $a] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $token = $this->authenticateTenantUser($tenant);
        $accountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $this->postJson('/api/v1/finance/cash-accounts', [
            'branchId' => $a, 'financialAccountId' => $accountId,
            'code' => 'SECOND-DRAWER', 'name' => 'Second Drawer',
            'type' => 'cash_drawer', 'isActive' => true,
        ], ['Authorization' => 'Bearer '.$token])->assertUnprocessable()->assertJsonValidationErrors('branchId');
        $this->assertSame(1, $this->drawers($tenant)->where('branch_id', $a)->count());
    }

    public function test_voucher_options_offer_branch_drawers_without_legacy_global_drawer(): void
    {
        [$tenant, $a, $b] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $token = $this->authenticateTenantUser($tenant);
        $locations = $this->getJson('/api/v1/finance/cashier/voucher-options', [
            'Authorization' => 'Bearer '.$token,
        ])->assertOk()->json('data.locations');
        $codes = collect($locations)->pluck('code')->all();
        $this->assertContains('CASH-DRAWER-BR-'.$a, $codes);
        $this->assertContains('CASH-DRAWER-BR-'.$b, $codes);
        $this->assertNotContains('CASH-DRAWER', $codes);
    }

    private function tenantWithBranches(): array
    {
        $tenant = (int) DB::table('tenants')->insertGetId([
            'name' => 'Drawer Test', 'slug' => 'drawer-test', 'status' => 'active',
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $ids = [];
        foreach (['A', 'B'] as $name) {
            $ids[] = (int) DB::table('branches')->insertGetId([
                'tenant_id' => $tenant, 'name' => 'Branch '.$name,
                'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
            ]);
        }
        return [$tenant, ...$ids];
    }

    private function drawers(int $tenant)
    {
        return DB::table('financial_locations')->where('tenant_id', $tenant)->whereNotNull('branch_id')
            ->where('kind', 'cash')->where('type', 'cash_drawer')->where('is_active', true)
            ->orderBy('branch_id')->get();
    }

    private function cashier(int $tenant, int $branch): User
    {
        $cashier = User::query()->create([
            'tenant_id' => $tenant, 'name' => 'Cashier', 'email' => 'drawer-cashier@example.test',
            'password' => 'password', 'role' => 'cashier', 'is_active' => true,
        ]);
        DB::table('user_branches')->insert([
            'tenant_id' => $tenant, 'user_id' => $cashier->id, 'branch_id' => $branch,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        return $cashier;
    }
}
