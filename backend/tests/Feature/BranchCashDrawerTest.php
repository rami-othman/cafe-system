<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\FinancialSetupService;
use App\Services\PurchaseCashSourceResolver;
use App\Services\FinancialAccountBalanceQuery;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Database\QueryException;
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
        $drawer = (int) DB::table('branches')->where('id', $branch)->value('pos_cash_financial_location_id');
        $this->postJson('/api/v1/finance/cash-transfers', [
            'fromFinancialLocationId' => $safe, 'toFinancialLocationId' => $drawer,
            'amount' => '100.00', 'transferDate' => now()->toDateString(),
            'idempotencyKey' => 'automatic-close-opening-float',
        ], $headers)->assertCreated();
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
        $journalCount = DB::table('journal_entries')->where('tenant_id', $tenant)->count();
        $next = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '20.00',
        ], $headers)->assertCreated()->json('data.id');
        $this->assertSame((int) $other, (int) DB::table('shifts')->where('id', $next)->value('close_destination_financial_location_id'));
        $this->assertSame($journalCount, DB::table('journal_entries')->where('tenant_id', $tenant)->count());
    }

    public function test_manual_close_transfers_counted_cash_above_float_once_and_keeps_balances(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $safe = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        $drawer = (int) DB::table('branches')->where('id', $branch)->value('pos_cash_financial_location_id');
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];
        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", [
            'shiftCloseDestinationFinancialLocationId' => $safe, 'shiftClosingFloatAmount' => '100.00',
        ], $headers)->assertOk();
        $this->fundDrawer($tenant, $branch, '500.00', $headers);
        $beforeOpen = DB::table('journal_entries')->where('tenant_id', $tenant)->count();
        $shift = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '500.00',
        ], $headers)->assertCreated()->json('data.id');
        $this->assertSame($beforeOpen, DB::table('journal_entries')->where('tenant_id', $tenant)->count());

        $payload = ['closingCash' => '500.00'];
        $first = $this->postJson("/api/v1/shifts/{$shift}/close", $payload, $headers)->assertOk();
        $this->postJson("/api/v1/shifts/{$shift}/close", $payload, $headers)->assertOk()
            ->assertJsonPath('data.closeTransferId', $first->json('data.closeTransferId'));
        $transferId = $first->json('data.closeTransferId');
        $transfer = DB::table('cash_transfers')->where('id', $transferId)->sole();
        $this->assertSame('400.00', $transfer->amount);
        $this->assertSame((int) $drawer, (int) $transfer->from_financial_location_id);
        $this->assertSame((int) $safe, (int) $transfer->to_financial_location_id);
        $this->assertSame('user', $transfer->actor_type);
        $this->assertSame(1, DB::table('cash_transfers')->where('shift_id', $shift)->count());
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $transfer->journal_entry_id)->get();
        $this->assertEquals($lines->sum('debit'), $lines->sum('credit'));
        $this->assertSame(2, $lines->whereNotNull('financial_location_id')->count());
        $balances = app(FinancialAccountBalanceQuery::class);
        $drawerAccount = (int) DB::table('financial_locations')->where('id', $drawer)->value('financial_account_id');
        $this->assertSame('100.00', $balances->summary($tenant, $drawerAccount, locationId: $drawer)['balance']);
        $this->postJson("/api/v1/finance/cash-transfers/{$transferId}/reverse", [], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('transfer');
        $this->postJson("/api/v1/finance/journal-entries/{$transfer->journal_entry_id}/reverse", [], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('entry');
        $this->assertSame('closed', DB::table('shifts')->where('id', $shift)->value('status'));
        $this->assertSame((int) $transferId, (int) DB::table('shifts')->where('id', $shift)->value('close_transfer_id'));
        $this->assertSame('posted', DB::table('cash_transfers')->where('id', $transferId)->value('status'));
        $this->assertSame('100.00', $balances->summary($tenant, $drawerAccount, locationId: $drawer)['balance']);
    }

    public function test_manual_close_rejects_count_below_float_without_partial_effects(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $safe = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];
        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", [
            'shiftCloseDestinationFinancialLocationId' => $safe, 'shiftClosingFloatAmount' => '100.00',
        ], $headers)->assertOk();
        $this->fundDrawer($tenant, $branch, '80.00', $headers);
        $shift = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '80.00',
        ], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '80.00'], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('closingCash');
        $this->assertSame('open', DB::table('shifts')->where('id', $shift)->value('status'));
        $this->assertSame(0, DB::table('cash_transfers')->where('shift_id', $shift)->count());
    }

    public function test_manual_close_blocks_when_operational_opening_cash_has_no_ledger_backing(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $safe = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];
        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", [
            'shiftCloseDestinationFinancialLocationId' => $safe, 'shiftClosingFloatAmount' => '100.00',
        ], $headers)->assertOk();
        $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '500.00',
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('openingCash');
        $this->assertSame(0, DB::table('shifts')->where('tenant_id', $tenant)->count());
        $this->assertSame(0, DB::table('journal_entries')->where('source_type', 'cash_transfer')->count());
    }

    public function test_manual_close_blocks_when_drawer_ledger_cannot_fund_counted_transfer(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $safe = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        $drawer = (int) DB::table('branches')->where('id', $branch)->value('pos_cash_financial_location_id');
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];
        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", [
            'shiftCloseDestinationFinancialLocationId' => $safe, 'shiftClosingFloatAmount' => '100.00',
        ], $headers)->assertOk();
        $this->postJson('/api/v1/finance/cash-transfers', [
            'fromFinancialLocationId' => $safe, 'toFinancialLocationId' => $drawer,
            'amount' => '300.00', 'transferDate' => now()->toDateString(),
            'idempotencyKey' => 'partial-opening-cash',
        ], $headers)->assertCreated();
        $shift = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '300.00',
        ], $headers)->assertCreated()->json('data.id');

        $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '500.00'], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('closingCash');
        $this->assertSame('open', DB::table('shifts')->where('id', $shift)->value('status'));
        $this->assertSame(0, DB::table('cash_transfers')->where('shift_id', $shift)->count());
        $account = (int) DB::table('financial_locations')->where('id', $drawer)->value('financial_account_id');
        $this->assertSame('300.00', app(FinancialAccountBalanceQuery::class)->summary($tenant, $account, locationId: $drawer)['balance']);
    }

    public function test_zero_transfer_requires_reconciled_drawer_then_closes_without_transfer(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $safe = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        $drawer = (int) DB::table('branches')->where('id', $branch)->value('pos_cash_financial_location_id');
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];
        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", [
            'shiftCloseDestinationFinancialLocationId' => $safe, 'shiftClosingFloatAmount' => '100.00',
        ], $headers)->assertOk();
        $this->fundDrawer($tenant, $branch, '100.00', $headers);
        $shift = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '100.00',
        ], $headers)->assertCreated()->json('data.id');
        $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '100.00'], $headers)
            ->assertOk()->assertJsonPath('data.closeTransferId', null);
        $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '100.00'], $headers)->assertOk();
        $this->assertSame(0, DB::table('cash_transfers')->where('shift_id', $shift)->count());
    }

    public function test_transfer_posting_failure_leaves_shift_open_without_close_effects(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $safe = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        $drawer = (int) DB::table('branches')->where('id', $branch)->value('pos_cash_financial_location_id');
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];
        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", [
            'shiftCloseDestinationFinancialLocationId' => $safe, 'shiftClosingFloatAmount' => '100.00',
        ], $headers)->assertOk();
        $this->postJson('/api/v1/finance/cash-transfers', [
            'fromFinancialLocationId' => $safe, 'toFinancialLocationId' => $drawer,
            'amount' => '500.00', 'transferDate' => now()->toDateString(),
            'idempotencyKey' => 'failed-close-opening-float',
        ], $headers)->assertCreated();
        $shift = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '500.00',
        ], $headers)->assertCreated()->json('data.id');

        $transfer = \Mockery::mock(\App\Services\CashTransferService::class);
        $transfer->shouldReceive('create')->once()->andThrow(
            ValidationException::withMessages(['transfer' => 'Injected posting failure.'])
        );
        $this->app->instance(\App\Services\CashTransferService::class, $transfer);
        $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '500.00'], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('transfer');
        $this->assertSame('open', DB::table('shifts')->where('id', $shift)->value('status'));
        $this->assertNull(DB::table('shifts')->where('id', $shift)->value('close_transfer_id'));
        $this->assertSame(0, DB::table('cash_transfers')->where('shift_id', $shift)->count());
        $account = (int) DB::table('financial_locations')->where('id', $drawer)->value('financial_account_id');
        $this->assertSame('500.00', app(FinancialAccountBalanceQuery::class)
            ->summary($tenant, $account, locationId: $drawer)['balance']);
    }

    public function test_manual_close_rejects_missing_destination_without_closing(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];
        $this->fundDrawer($tenant, $branch, '100.00', $headers);
        $shift = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '100.00',
        ], $headers)->assertCreated()->json('data.id');
        // A2: new shifts cannot open without a destination; simulate a pre-A2 legacy open shift.
        DB::table('shifts')->where('id', $shift)->update(['close_destination_financial_location_id' => null]);
        $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '100.00'], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('destination');
        $this->assertSame('open', DB::table('shifts')->where('id', $shift)->value('status'));
        $this->assertSame(0, DB::table('cash_transfers')->where('shift_id', $shift)->count());
    }

    public function test_automatic_close_rejects_expected_cash_below_float(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $safe = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        $token = $this->authenticateTenantUser($tenant);
        $headers = ['Authorization' => 'Bearer '.$token];
        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", [
            'shiftCloseDestinationFinancialLocationId' => $safe, 'shiftClosingFloatAmount' => '100.00',
        ], $headers)->assertOk();
        $this->fundDrawer($tenant, $branch, '80.00', $headers);
        $shift = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '80.00',
        ], $headers)->assertCreated()->json('data.id');
        try {
            app(\App\Services\AutomaticShiftCloseService::class)->close($tenant, $shift);
            $this->fail('An automatic close cannot silently consume part of the float.');
        } catch (ValidationException $exception) {
            $this->assertArrayHasKey('closingCash', $exception->errors());
        }
        $this->assertSame('open', DB::table('shifts')->where('id', $shift)->value('status'));
        $this->assertSame(0, DB::table('cash_transfers')->where('shift_id', $shift)->count());
    }

    public function test_missing_close_destination_blocks_without_closing_or_moving_cash(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $token = $this->authenticateTenantUser($tenant);
        $this->fundDrawer($tenant, $branch, '100.00', ['Authorization' => 'Bearer '.$token]);
        $shift = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '100.00',
        ], ['Authorization' => 'Bearer '.$token])->assertCreated()->json('data.id');
        // A2: new shifts cannot open without a destination; simulate a pre-A2 legacy open shift.
        DB::table('shifts')->where('id', $shift)->update(['close_destination_financial_location_id' => null]);
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
        $before = DB::table('branches')->where('id', $branch)->value('shift_close_destination_financial_location_id');
        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", [
            'shiftCloseDestinationFinancialLocationId' => $drawer,
        ], ['Authorization' => 'Bearer '.$token])->assertUnprocessable()
            ->assertJsonValidationErrors('shiftCloseDestinationFinancialLocationId');
        $this->assertSame($before, DB::table('branches')->where('id', $branch)->value('shift_close_destination_financial_location_id'));
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
            'branchId' => $a, 'openingCash' => '0.00',
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
        $this->fundDrawer($tenant, $branch, '100.00', ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant)]);
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

    public function test_two_users_cannot_open_overlapping_shifts_on_one_branch_drawer(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $ownerHeaders = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant)];
        $cashierHeaders = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant, $this->cashier($tenant, $branch))];
        $this->fundDrawer($tenant, $branch, '100.00', $ownerHeaders);

        $ownerShift = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '100.00',
        ], $ownerHeaders)->assertCreated()->json('data.id');
        $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '100.00',
        ], $cashierHeaders)->assertUnprocessable()->assertJsonValidationErrors('branchId');

        $open = DB::table('shifts')->where('tenant_id', $tenant)->where('branch_id', $branch)
            ->where('status', 'open')->orderBy('id')->get(['id', 'financial_location_id']);
        $this->assertCount(1, $open);
        foreach ([$ownerShift] as $shiftId) {
            $summary = app(\App\Services\ShiftCashSummaryService::class)
                ->summarize($tenant, DB::table('shifts')->where('id', $shiftId)->first());
            $this->assertSame('100.00', $summary['expectedCash']);
        }
        $drawer = (int) $open[0]->financial_location_id;
        $account = (int) DB::table('financial_locations')->where('id', $drawer)->value('financial_account_id');
        $this->assertSame('100.00', app(FinancialAccountBalanceQuery::class)
            ->summary($tenant, $account, locationId: $drawer)['balance']);
    }

    public function test_postgres_unique_index_rejects_a_second_live_shift_but_allows_historical_rows(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant)];
        $shiftId = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '0.00',
        ], $headers)->assertCreated()->json('data.id');
        $original = DB::table('shifts')->where('id', $shiftId)->first();
        $row = [
            'tenant_id' => $tenant, 'branch_id' => $branch, 'user_id' => $original->user_id,
            'financial_location_id' => $original->financial_location_id,
            'opening_cash' => '0.00', 'status' => 'open', 'opened_at' => now(),
            'created_at' => now(), 'updated_at' => now(),
        ];
        try {
            DB::transaction(fn () => DB::table('shifts')->insert($row));
            $this->fail('PostgreSQL must reject overlapping live shifts independently of the API lock.');
        } catch (QueryException $exception) {
            $this->assertSame('23505', $exception->getCode());
        }
        DB::table('shifts')->insert($row + ['deleted_at' => now()]);
        DB::table('shifts')->insert(array_replace($row, ['status' => 'closed', 'closed_at' => now()]));
        $this->assertSame(1, DB::table('shifts')->where('tenant_id', $tenant)
            ->where('financial_location_id', $original->financial_location_id)
            ->where('status', 'open')->whereNull('deleted_at')->count());
    }

    public function test_unallocated_transfer_touching_open_drawer_is_blocked(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant)];
        $shiftId = (int) $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '0.00',
        ], $headers)->assertCreated()->json('data.id');
        $drawer = (int) DB::table('shifts')->where('id', $shiftId)->value('financial_location_id');
        $safe = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        $this->postJson('/api/v1/finance/cash-transfers', [
            'fromFinancialLocationId' => $safe, 'toFinancialLocationId' => $drawer,
            'amount' => '10.00', 'transferDate' => now()->toDateString(),
            'idempotencyKey' => 'unallocated-open-shift-transfer',
        ], $headers)->assertUnprocessable()->assertJsonValidationErrors('transfer');
        $this->assertSame(0, DB::table('cash_transfers')->where('tenant_id', $tenant)->count());
    }

    public function test_funding_transfer_cannot_be_reversed_while_its_drawer_shift_is_open(): void
    {
        [$tenant, $branch] = $this->tenantWithBranches();
        app(FinancialSetupService::class)->ensureForTenant($tenant);
        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant)];
        $this->fundDrawer($tenant, $branch, '25.00', $headers);
        $transfer = DB::table('cash_transfers')->where('tenant_id', $tenant)->sole();
        $this->postJson('/api/v1/shifts/current', [
            'branchId' => $branch, 'openingCash' => '25.00',
        ], $headers)->assertCreated();
        $this->postJson("/api/v1/finance/cash-transfers/{$transfer->id}/reverse", [], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('transfer');
        $this->assertSame('posted', DB::table('cash_transfers')->where('id', $transfer->id)->value('status'));
    }

    private function fundDrawer(int $tenant, int $branch, string $amount, array $headers): void
    {
        $safe = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        $drawer = (int) DB::table('branches')->where('id', $branch)->value('pos_cash_financial_location_id');
        $this->postJson('/api/v1/finance/cash-transfers', [
            'fromFinancialLocationId' => $safe, 'toFinancialLocationId' => $drawer,
            'amount' => $amount, 'transferDate' => now()->toDateString(),
            'idempotencyKey' => 'opening-float-'.$tenant.'-'.$branch.'-'.$amount,
        ], $headers)->assertCreated();
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
