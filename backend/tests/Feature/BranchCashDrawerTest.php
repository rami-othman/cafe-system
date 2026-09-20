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

    public function test_automatic_close_uses_open_snapshot_and_posts_one_internal_transfer(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $account = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $safe = DB::table('financial_locations')->insertGetId([
            'tenant_id' => $tenant, 'financial_account_id' => $account, 'code' => 'TEST-SAFE',
            'name' => 'Safe', 'kind' => 'cash', 'type' => 'main_safe', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $other = DB::table('financial_locations')->insertGetId([
            'tenant_id' => $tenant, 'financial_account_id' => $account, 'code' => 'TEST-OTHER',
            'name' => 'Other', 'kind' => 'cash', 'type' => 'petty_cash', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $owner = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$owner];
        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", [
            'shiftCloseDestinationFinancialLocationId' => $safe, 'shiftClosingFloatAmount' => '20.00',
            'shiftCloseTime' => '23:00',
        ], $headers)->assertOk();
        $shift = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '100.00',
        ], $headers)->assertCreated()->json('data.id');
        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", [
            'shiftCloseDestinationFinancialLocationId' => $other,
        ], $headers)->assertOk();
        app(\App\Services\AutomaticShiftCloseService::class)->close($tenant, $shift);
        app(\App\Services\AutomaticShiftCloseService::class)->close($tenant, $shift);
        $closed = DB::table('shifts')->find($shift);
        $transfer = DB::table('cash_transfers')->where('shift_id', $shift)->first();
        $this->assertSame((int) $safe, (int) $closed->close_destination_financial_location_id);
        $this->assertSame('automatic', $closed->close_type);
        $this->assertNull($closed->closing_cash);
        $this->assertSame('100.00', $closed->expected_cash);
        $this->assertSame('80.00', $transfer->amount);
        $this->assertSame((int) $safe, (int) $transfer->to_financial_location_id);
        $this->assertSame('system', $transfer->actor_type);
        $this->assertSame(1, DB::table('cash_transfers')->where('shift_id', $shift)->count());
        $this->assertSame(1, DB::table('journal_entries')->where('source_type', 'cash_transfer')->where('source_id', $transfer->id)->count());
        $next = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '20.00',
        ], $headers)->assertCreated()->json('data.id');
        $this->assertSame((int) $other, (int) DB::table('shifts')->where('id', $next)->value('close_destination_financial_location_id'));
    }

    public function test_missing_close_destination_blocks_without_closing_or_moving_cash(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $token = $this->authenticateTenantUser($tenant);
        $shift = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '100.00',
        ], ['Authorization' => 'Bearer '.$token])->assertCreated()->json('data.id');
        try {
            app(\App\Services\AutomaticShiftCloseService::class)->close($tenant, $shift);
            $this->fail('Missing destination must block automatic close.');
        } catch (ValidationException $e) {
            $this->assertArrayHasKey('destination', $e->errors());
        }
        $this->assertSame('open', DB::table('shifts')->where('id', $shift)->value('status'));
        $this->assertSame(0, DB::table('cash_transfers')->where('shift_id', $shift)->count());
    }

    public function test_cashier_cannot_change_shift_close_destination(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashier = $this->cashier($tenant, $branch);
        $token = $this->authenticateTenantUser($tenant, $cashier);
        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", [
            'shiftClosingFloatAmount' => '10.00',
        ], ['Authorization' => 'Bearer '.$token])->assertForbidden();
        $this->assertEquals(0, DB::table('branches')->where('id', $branch)->value('shift_closing_float_amount'));
    }

    public function test_owner_cannot_choose_pos_drawer_as_close_destination(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $token = $this->authenticateTenantUser($tenant);
        $drawer = DB::table('branches')->where('id', $branch)->value('pos_cash_financial_location_id');
        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", [
            'shiftCloseDestinationFinancialLocationId' => $drawer,
        ], ['Authorization' => 'Bearer '.$token])->assertUnprocessable()
            ->assertJsonValidationErrors('shiftCloseDestinationFinancialLocationId');
        $this->assertNull(DB::table('branches')->where('id', $branch)->value('shift_close_destination_financial_location_id'));
    }

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

    public function test_null_open_shift_is_rejected_until_safe_repair_runs(): void
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
        try {
            app(PurchaseCashSourceResolver::class)->resolve($tenant, $cashier->id, $a, true);
            $this->fail('An unassigned shift must not silently acquire a drawer during posting.');
        } catch (ValidationException) {
            $this->assertNull(DB::table('shifts')->where('id', $shiftId)->value('financial_location_id'));
        }
    }

    public function test_multiple_branch_drawers_keep_an_explicit_default(): void
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
        $configured = (int) DB::table('branches')->where('id', $a)->value('pos_cash_financial_location_id');
        $second = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'DUPLICATE-DRAWER')->value('id');
        $resolved = app(PurchaseCashSourceResolver::class)->resolve($tenant, $owner->id, $a, selectedLocationId: $second);
        $this->assertSame($second, (int) $resolved->location->id);
        $this->assertSame($configured, (int) DB::table('branches')->where('id', $a)->value('pos_cash_financial_location_id'));
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

    public function test_shift_opening_rejects_missing_branch_pos_drawer(): void
    {
        [$tenant, $a] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        DB::table('branches')->where('id', $a)->update(['pos_cash_financial_location_id' => null]);
        $cashier = $this->cashier($tenant, $a);
        $token = $this->authenticateTenantUser($tenant, $cashier);
        $this->postJson('/api/v1/shifts/current', [
            'branchId' => $a, 'openingCash' => '100.00',
        ], ['Authorization' => 'Bearer '.$token])->assertUnprocessable()->assertJsonValidationErrors('cashSource');
        $this->assertSame(0, DB::table('shifts')->where('tenant_id', $tenant)->where('branch_id', $a)->count());
    }

    public function test_financial_location_api_allows_a_second_active_branch_drawer_without_changing_default(): void
    {
        [$tenant, $a] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $token = $this->authenticateTenantUser($tenant);
        $accountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $this->postJson('/api/v1/finance/cash-accounts', [
            'branchId' => $a, 'financialAccountId' => $accountId,
            'code' => 'SECOND-DRAWER', 'name' => 'Second Drawer',
            'type' => 'cash_drawer', 'isActive' => true,
        ], ['Authorization' => 'Bearer '.$token])->assertCreated();
        $this->assertSame(2, $this->drawers($tenant)->where('branch_id', $a)->count());
        $this->assertNotNull(DB::table('branches')->where('id', $a)->value('pos_cash_financial_location_id'));
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

    public function test_cashier_voucher_uses_shift_drawer_and_affects_expected_cash(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $cashier = $this->cashier($tenant, $branch);
        $token = $this->authenticateTenantUser($tenant, $cashier);
        $headers = ['Authorization' => 'Bearer '.$token];
        $shiftId = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '100.00',
        ], $headers)->assertCreated()->json('data.id');
        $account = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6190')->value('id');
        $voucherId = (int) $this->postJson('/api/v1/finance/vouchers', [
            'documentType' => 'payment', 'documentDate' => now()->toDateString(),
            'branchId' => $branch, 'amount' => '20.00',
            'lines' => [['accountId' => $account, 'amount' => '20.00']],
        ], $headers)->assertCreated()->json('data.id');
        $voucher = DB::table('finance_documents')->where('id', $voucherId)->first();
        $this->assertSame($shiftId, (int) $voucher->shift_id);
        $this->assertSame((int) DB::table('shifts')->where('id', $shiftId)->value('financial_location_id'), (int) $voucher->financial_location_id);
        $this->postJson("/api/v1/finance/vouchers/{$voucherId}/post", [], $headers)->assertOk();
        $summary = app(\App\Services\ShiftCashSummaryService::class)->summarize($tenant, DB::table('shifts')->where('id', $shiftId)->first());
        $this->assertSame('80.00', $summary['expectedCash']);
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
