<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\AutomaticShiftCloseService;
use App\Services\FinancialAccountBalanceQuery;
use App\Services\FinancialSetupService;
use App\Services\LegacyShiftCloseConfigurationAdoptionService;
use App\Services\ShiftDrawerReadinessService;
use App\Services\ShiftOverlapReconciliationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

/**
 * A2 — production-grade shift / cash drawer lifecycle.
 *
 * One physical drawer = one open shift; opening cash = posted drawer ledger;
 * canonical manual/automatic close; historical overlap reconciliation; legacy
 * close-configuration adoption; reporting of each close type.
 */
final class ShiftDrawerLifecycleTest extends TestCase
{
    use RefreshDatabase;

    private int $tenant;

    private int $branchA;

    private int $branchB;

    private User $owner;

    private array $headers;

    protected function setUp(): void
    {
        parent::setUp();
        $this->tenant = (int) DB::table('tenants')->insertGetId(['name' => 'A2 Tenant', 'slug' => 'a2-tenant', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $this->branchA = (int) DB::table('branches')->insertGetId(['tenant_id' => $this->tenant, 'name' => 'Branch A', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->branchB = (int) DB::table('branches')->insertGetId(['tenant_id' => $this->tenant, 'name' => 'Branch B', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($this->tenant, $this->branchA);
        $this->owner = User::query()->create(['tenant_id' => $this->tenant, 'name' => 'A2 Owner', 'email' => 'a2-owner@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true]);
        $this->headers = $this->bearer($this->tenant, $this->owner);
    }

    // ---- A2.1 one physical drawer = one open shift -------------------------

    public function test_01_first_open_on_a_drawer_succeeds_and_snapshots_configuration(): void
    {
        $this->configureClose($this->branchA, $this->safe(), '50.00');
        $this->fund($this->branchA, '200.00');

        $data = $this->open($this->branchA, '200.00')->assertCreated()->json('data');

        $row = DB::table('shifts')->find($data['id']);
        $this->assertSame($this->drawer($this->branchA), (int) $row->financial_location_id);
        $this->assertSame($this->safe(), (int) $row->close_destination_financial_location_id);
        $this->assertSame('50.00', $row->closing_float_amount);
        $this->assertSame('open', $row->status);
    }

    public function test_02_second_open_on_the_same_drawer_is_rejected(): void
    {
        $this->open($this->branchA, '0.00')->assertCreated();
        $cashier = $this->cashier($this->branchA);

        $this->open($this->branchA, '0.00', $this->bearer($this->tenant, $cashier))
            ->assertUnprocessable()->assertJsonValidationErrors('branchId');
        $this->assertSame(1, $this->openShiftCount($this->drawer($this->branchA)));
    }

    public function test_04_database_unique_violation_becomes_friendly_validation_error(): void
    {
        $this->open($this->branchA, '0.00')->assertCreated();
        // Simulate the race window: the application-level check does not see
        // the concurrent shift, so the partial unique index must catch it.
        $this->app->instance(ShiftDrawerReadinessService::class, new class(app(FinancialAccountBalanceQuery::class)) extends ShiftDrawerReadinessService
        {
            public function openShiftOnDrawer(int $tenantId, int $drawerId): ?object
            {
                return null;
            }
        });
        $cashier = $this->cashier($this->branchA);

        $response = $this->open($this->branchA, '0.00', $this->bearer($this->tenant, $cashier))
            ->assertUnprocessable()->assertJsonValidationErrors('branchId');

        $this->assertSame(__('shifts.drawer_has_open_shift', [], 'ar'), $response->json('errors.branchId.0'));
        $this->assertStringNotContainsString('SQLSTATE', $response->getContent());
        $this->assertStringNotContainsString('shifts_one_open_per_location', $response->getContent());
        $this->assertSame(1, $this->openShiftCount($this->drawer($this->branchA)));
    }

    public function test_05_two_different_physical_drawers_can_be_open_at_the_same_time(): void
    {
        $this->open($this->branchA, '0.00')->assertCreated();
        $this->open($this->branchB, '0.00', $this->bearer($this->tenant, $this->cashier($this->branchB)))->assertCreated();

        $this->assertSame(1, $this->openShiftCount($this->drawer($this->branchA)));
        $this->assertSame(1, $this->openShiftCount($this->drawer($this->branchB)));
    }

    public function test_06_opening_cash_must_equal_the_drawer_ledger_balance(): void
    {
        $this->fund($this->branchA, '120.00');

        $response = $this->open($this->branchA, '100.00')->assertUnprocessable()->assertJsonValidationErrors('openingCash');
        $this->assertStringContainsString('120.00', $response->json('errors.openingCash.0'));
        $this->assertSame(0, DB::table('shifts')->where('tenant_id', $this->tenant)->count());

        $this->open($this->branchA, '120.00')->assertCreated();
    }

    // ---- A2.2 readiness -----------------------------------------------------

    public function test_07_missing_close_destination_blocks_a_new_shift(): void
    {
        $this->putJson("/api/v1/cafe-configuration/branches/{$this->branchA}", ['shiftCloseDestinationFinancialLocationId' => null], $this->headers)->assertOk();

        $this->open($this->branchA, '0.00')->assertUnprocessable()
            ->assertJsonValidationErrors(ShiftDrawerReadinessService::FIELD_DESTINATION);
        $this->assertSame(0, DB::table('shifts')->where('tenant_id', $this->tenant)->count());

        $readiness = $this->getJson("/api/v1/shifts/readiness?branchId={$this->branchA}", $this->headers)->assertOk()->json('data');
        $this->assertFalse($readiness['canOpenShift']);
        $this->assertContains('CLOSE_DESTINATION_NOT_CONFIGURED', array_column($readiness['issues'], 'code'));
    }

    public function test_08_close_destination_equal_to_the_drawer_fails(): void
    {
        $drawer = $this->drawer($this->branchA);
        $this->putJson("/api/v1/cafe-configuration/branches/{$this->branchA}", ['shiftCloseDestinationFinancialLocationId' => $drawer], $this->headers)
            ->assertUnprocessable()->assertJsonValidationErrors(ShiftDrawerReadinessService::FIELD_DESTINATION);
        // Even if a bad value reached the row directly, opening refuses it.
        DB::table('branches')->where('id', $this->branchA)->update(['shift_close_destination_financial_location_id' => $drawer]);

        $this->open($this->branchA, '0.00')->assertUnprocessable()->assertJsonValidationErrors(ShiftDrawerReadinessService::FIELD_DESTINATION);
        $this->assertSame(0, DB::table('shifts')->where('tenant_id', $this->tenant)->count());
    }

    public function test_09_cross_tenant_close_destination_fails(): void
    {
        $other = (int) DB::table('tenants')->insertGetId(['name' => 'Other', 'slug' => 'a2-other', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($other);
        $foreignSafe = (int) DB::table('financial_locations')->where('tenant_id', $other)->where('code', 'MAIN-SAFE')->value('id');

        $this->putJson("/api/v1/cafe-configuration/branches/{$this->branchA}", ['shiftCloseDestinationFinancialLocationId' => $foreignSafe], $this->headers)
            ->assertUnprocessable()->assertJsonValidationErrors(ShiftDrawerReadinessService::FIELD_DESTINATION);
        DB::table('branches')->where('id', $this->branchA)->update(['shift_close_destination_financial_location_id' => $foreignSafe]);

        $this->open($this->branchA, '0.00')->assertUnprocessable()->assertJsonValidationErrors(ShiftDrawerReadinessService::FIELD_DESTINATION);
    }

    public function test_10_inactive_close_destination_fails(): void
    {
        DB::table('financial_locations')->where('id', $this->safe())->update(['is_active' => false]);

        $this->open($this->branchA, '0.00')->assertUnprocessable()->assertJsonValidationErrors(ShiftDrawerReadinessService::FIELD_DESTINATION);
        $issues = app(ShiftDrawerReadinessService::class)->assess($this->tenant, $this->branchA)['issues'];
        $this->assertSame(['CLOSE_DESTINATION_INVALID'], array_column($issues, 'code'));
        // The branch configuration payload reports the same canonical issue.
        $this->assertSame('CLOSE_DESTINATION_INVALID', $this->getJson("/api/v1/cafe-configuration/branches/{$this->branchA}", $this->headers)
            ->assertOk()->json('data.shiftDrawerReadiness.issues.0.code'));
    }

    public function test_10b_close_destination_that_is_another_cash_drawer_is_rejected(): void
    {
        $otherDrawer = (int) DB::table('financial_locations')->insertGetId([
            'tenant_id' => $this->tenant, 'branch_id' => $this->branchB,
            'financial_account_id' => DB::table('financial_accounts')->where('tenant_id', $this->tenant)->where('code', '1010')->value('id'),
            'code' => 'DRAWER-B', 'name' => 'Drawer B', 'kind' => 'cash', 'type' => 'cash_drawer', 'is_active' => true,
            'created_at' => now(), 'updated_at' => now(),
        ]);

        $this->putJson("/api/v1/cafe-configuration/branches/{$this->branchA}", ['shiftCloseDestinationFinancialLocationId' => $otherDrawer], $this->headers)
            ->assertUnprocessable()->assertJsonValidationErrors(ShiftDrawerReadinessService::FIELD_DESTINATION);
        $issues = app(ShiftDrawerReadinessService::class)->configurationIssues(
            $this->tenant, (object) DB::table('branches')->find($this->branchA), $this->drawer($this->branchA), $otherDrawer, '0.00', true,
        );
        $this->assertSame(['CLOSE_DESTINATION_IS_DRAWER'], array_column($issues, 'code'));

        DB::table('branches')->where('id', $this->branchA)->update(['shift_close_destination_financial_location_id' => $otherDrawer]);
        $this->open($this->branchA, '0.00')->assertUnprocessable()->assertJsonValidationErrors(ShiftDrawerReadinessService::FIELD_DESTINATION);
    }

    public function test_10c_close_destination_that_is_a_safe_non_drawer_cash_location_is_accepted(): void
    {
        $pettyCash = $this->cashLocation('PETTY-A', $this->branchA);

        $this->putJson("/api/v1/cafe-configuration/branches/{$this->branchA}", ['shiftCloseDestinationFinancialLocationId' => $pettyCash], $this->headers)
            ->assertOk();
        $this->assertSame($pettyCash, (int) DB::table('branches')->where('id', $this->branchA)->value('shift_close_destination_financial_location_id'));
    }

    // ---- A2.4 canonical manual close ----------------------------------------

    public function test_11_manual_close_transfers_counted_minus_float_exactly_once(): void
    {
        $this->configureClose($this->branchA, $this->safe(), '100.00');
        $this->fund($this->branchA, '500.00');
        $shift = $this->open($this->branchA, '500.00')->assertCreated()->json('data.id');

        $closed = $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '500.00'], $this->headers)->assertOk();

        $transfer = DB::table('cash_transfers')->where('id', $closed->json('data.closeTransferId'))->sole();
        $this->assertSame('400.00', $transfer->amount);
        $this->assertSame('shift-close-transfer:'.$shift, $transfer->idempotency_key);
        $this->assertSame($this->drawer($this->branchA), (int) $transfer->from_financial_location_id);
        $this->assertSame($this->safe(), (int) $transfer->to_financial_location_id);
        $this->assertSame('user', $transfer->actor_type);
        $this->assertSame('100.00', $this->ledger($this->branchA));
        $closed->assertJsonPath('data.closeType', 'manual')->assertJsonPath('data.cashCounted', true)->assertJsonPath('data.cash.counted', true);
    }

    public function test_12_repeated_manual_close_does_not_duplicate_the_transfer(): void
    {
        $this->configureClose($this->branchA, $this->safe(), '0.00');
        $this->fund($this->branchA, '75.00');
        $shift = $this->open($this->branchA, '75.00')->json('data.id');

        $first = $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '75.00'], $this->headers)->assertOk()->json('data.closeTransferId');
        $second = $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '75.00'], $this->headers)->assertOk()->json('data.closeTransferId');

        $this->assertSame($first, $second);
        $this->assertSame(1, DB::table('cash_transfers')->where('shift_id', $shift)->count());
        $this->assertSame(1, DB::table('journal_entries')->where('source_type', 'cash_transfer')->where('source_id', $first)->count());
        $this->assertSame('0.00', $this->ledger($this->branchA));
    }

    public function test_13_close_fails_when_drawer_ledger_differs_from_counted_cash(): void
    {
        $this->fund($this->branchA, '100.00');
        $shift = $this->open($this->branchA, '100.00')->json('data.id');
        // Legacy/operational opening cash that the ledger never received.
        DB::table('shifts')->where('id', $shift)->update(['opening_cash' => '150.00']);

        $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '150.00'], $this->headers)
            ->assertUnprocessable()->assertJsonValidationErrors('closingCash');
        $this->assertSame('open', DB::table('shifts')->where('id', $shift)->value('status'));
        $this->assertSame(0, DB::table('cash_transfers')->where('shift_id', $shift)->count());
    }

    // ---- A2.5 automatic close -----------------------------------------------

    public function test_14_automatic_close_uses_the_same_close_transfer_primitive(): void
    {
        $this->configureClose($this->branchA, $this->safe(), '30.00');
        $this->fund($this->branchA, '130.00');
        $shift = $this->open($this->branchA, '130.00')->json('data.id');

        $this->assertTrue(app(AutomaticShiftCloseService::class)->close($this->tenant, $shift));

        $row = DB::table('shifts')->find($shift);
        $transfer = DB::table('cash_transfers')->where('id', $row->close_transfer_id)->sole();
        $this->assertSame('automatic', $row->close_type);
        $this->assertNull($row->closing_cash, 'Automatic close must not fabricate a physical count.');
        $this->assertSame('130.00', $row->expected_cash);
        $this->assertSame('shift-close-transfer:'.$shift, $transfer->idempotency_key);
        $this->assertSame('system', $transfer->actor_type);
        $this->assertSame('100.00', $transfer->amount);
        $this->assertSame('30.00', $this->ledger($this->branchA));
    }

    public function test_15_automatic_close_retry_creates_no_duplicate_transfer(): void
    {
        $this->configureClose($this->branchA, $this->safe(), '0.00');
        $this->fund($this->branchA, '40.00');
        $shift = $this->open($this->branchA, '40.00')->json('data.id');

        $this->assertTrue(app(AutomaticShiftCloseService::class)->close($this->tenant, $shift));
        $this->assertFalse(app(AutomaticShiftCloseService::class)->close($this->tenant, $shift));
        $this->artisan('shifts:close-due')->assertExitCode(0);

        $this->assertSame(1, DB::table('cash_transfers')->where('tenant_id', $this->tenant)->where('shift_id', $shift)->count());
        $this->assertSame('0.00', $this->ledger($this->branchA));
    }

    public function test_16_required_bar_check_still_blocks_manual_and_automatic_close(): void
    {
        $warehouse = (int) DB::table('warehouses')->where('tenant_id', $this->tenant)->where('branch_id', $this->branchA)->value('id');
        DB::table('bar_check_templates')->insert(['tenant_id' => $this->tenant, 'branch_id' => $this->branchA, 'warehouse_id' => $warehouse, 'name' => 'Bar', 'is_active' => true, 'required_for_shift_close' => true, 'created_at' => now(), 'updated_at' => now()]);
        $shift = $this->open($this->branchA, '0.00')->json('data.id');

        $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '0.00'], $this->headers)
            ->assertUnprocessable()->assertJsonValidationErrors('barCheck');
        try {
            app(AutomaticShiftCloseService::class)->close($this->tenant, $shift);
            $this->fail('A pending required bar check must block automatic close.');
        } catch (ValidationException $exception) {
            $this->assertArrayHasKey('barCheck', $exception->errors());
        }
        $this->assertSame('open', DB::table('shifts')->where('id', $shift)->value('status'));
    }

    // ---- A2.3 snapshot --------------------------------------------------------

    public function test_17_open_shift_configuration_snapshot_is_immutable_after_branch_changes(): void
    {
        $this->configureClose($this->branchA, $this->safe(), '10.00');
        $this->fund($this->branchA, '60.00');
        $shift = $this->open($this->branchA, '60.00')->json('data.id');
        $petty = $this->cashLocation('A2-PETTY', null);

        $this->configureClose($this->branchA, $petty, '25.00');

        $row = DB::table('shifts')->find($shift);
        $this->assertSame($this->safe(), (int) $row->close_destination_financial_location_id);
        $this->assertSame('10.00', $row->closing_float_amount);
        $transferId = $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '60.00'], $this->headers)->assertOk()->json('data.closeTransferId');
        $transfer = DB::table('cash_transfers')->find($transferId);
        $this->assertSame($this->safe(), (int) $transfer->to_financial_location_id);
        $this->assertSame('50.00', $transfer->amount);
    }

    // ---- A2.6 / A2.7 legacy overlap reconciliation ----------------------------

    public function test_18_overlap_reconciliation_dry_run_writes_nothing(): void
    {
        [$drawer, $shifts] = $this->legacyOverlap('300.00');
        $before = $this->financialFingerprint();
        $shiftRows = DB::table('shifts')->whereIn('id', $shifts)->orderBy('id')->get()->toJson();

        $report = app(ShiftOverlapReconciliationService::class)->reconcile($this->tenant, $drawer, '300.00', 'dry', $this->owner->id, false);
        $this->artisan('shifts:reconcile-overlap', ['tenantId' => $this->tenant, 'financialLocationId' => $drawer, '--confirmed-cash' => '300.00'])->assertExitCode(0);

        $this->assertFalse($report['applied']);
        $this->assertSame([], $report['blockers']);
        $this->assertSame('300.00', $report['ledgerBalance']);
        $this->assertSame($before, $this->financialFingerprint());
        $this->assertSame($shiftRows, DB::table('shifts')->whereIn('id', $shifts)->orderBy('id')->get()->toJson());
        $this->assertSame(0, DB::table('activity_logs')->where('tenant_id', $this->tenant)->where('action', 'like', 'shift.%')->count());
    }

    public function test_19_overlap_reconciliation_refuses_confirmed_cash_different_from_ledger(): void
    {
        [$drawer, $shifts] = $this->legacyOverlap('300.00');
        $before = $this->financialFingerprint();

        $report = app(ShiftOverlapReconciliationService::class)->reconcile($this->tenant, $drawer, '250.00', 'count', $this->owner->id, true);
        $this->artisan('shifts:reconcile-overlap', ['tenantId' => $this->tenant, 'financialLocationId' => $drawer, '--confirmed-cash' => '250.00', '--reason' => 'x', '--actor' => $this->owner->id, '--apply' => true])->assertExitCode(1);

        $this->assertFalse($report['applied']);
        $this->assertContains('CONFIRMED_CASH_MISMATCH', array_column($report['blockers'], 'code'));
        $this->assertSame(2, DB::table('shifts')->whereIn('id', $shifts)->where('status', 'open')->count());
        $this->assertSame($before, $this->financialFingerprint());
    }

    public function test_20_overlap_reconciliation_refuses_when_draft_or_held_orders_exist(): void
    {
        [$drawer, $shifts] = $this->legacyOverlap('300.00');
        $draft = $this->order($shifts[0], 'draft', 'unpaid', '15.00');
        $held = $this->order($shifts[1], 'held', 'unpaid', '25.00');

        $report = app(ShiftOverlapReconciliationService::class)->reconcile($this->tenant, $drawer, '300.00', 'legacy', $this->owner->id, true);

        $this->assertFalse($report['applied']);
        $this->assertContains('ACTIVE_ORDERS', array_column($report['blockers'], 'code'));
        $this->assertEqualsCanonicalizing([$draft, $held], array_column($report['activeOrders'], 'id'));
        $this->assertSame(2, DB::table('shifts')->whereIn('id', $shifts)->where('status', 'open')->count());
        $this->assertSame('draft', DB::table('orders')->where('id', $draft)->value('status'));
        $this->assertSame('held', DB::table('orders')->where('id', $held)->value('status'));
        $this->assertSame([(int) $shifts[0], (int) $shifts[1]], [(int) DB::table('orders')->where('id', $draft)->value('shift_id'), (int) DB::table('orders')->where('id', $held)->value('shift_id')]);
    }

    public function test_20b_overlap_reconciliation_fails_closed_on_an_unknown_order_status(): void
    {
        [$drawer, $shifts] = $this->legacyOverlap('300.00');
        // A status this deployed version has never heard of must still block
        // reconciliation (M6/6C): unrecognized is never treated as terminal.
        $unknown = $this->order($shifts[0], 'awaiting_courier', 'unpaid', '15.00');

        $report = app(ShiftOverlapReconciliationService::class)->reconcile($this->tenant, $drawer, '300.00', 'legacy', $this->owner->id, true);

        $this->assertFalse($report['applied']);
        $this->assertContains('ACTIVE_ORDERS', array_column($report['blockers'], 'code'));
        $this->assertContains($unknown, array_column($report['activeOrders'], 'id'));
        $this->assertSame(2, DB::table('shifts')->whereIn('id', $shifts)->where('status', 'open')->count());
    }

    // ---- M6: administrative command actor authorization ---------------------

    public function test_20c_reconciliation_apply_refuses_an_inactive_actor(): void
    {
        [$drawer] = $this->legacyOverlap('0.00');
        $inactiveOwner = User::query()->create(['tenant_id' => $this->tenant, 'name' => 'Inactive Owner', 'email' => 'a2-inactive-'.uniqid().'@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => false]);

        $report = app(ShiftOverlapReconciliationService::class)->reconcile($this->tenant, $drawer, '0.00', 'x', $inactiveOwner->id, true);

        $this->assertFalse($report['applied']);
        $this->assertContains('ACTOR_INACTIVE', array_column($report['blockers'], 'code'));
    }

    public function test_20d_reconciliation_apply_refuses_a_wrong_tenant_actor(): void
    {
        [$drawer] = $this->legacyOverlap('0.00');
        $other = (int) DB::table('tenants')->insertGetId(['name' => 'M6 Other', 'slug' => 'a2-m6-other', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $foreignOwner = User::query()->create(['tenant_id' => $other, 'name' => 'Foreign Owner', 'email' => 'a2-foreign-'.uniqid().'@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true]);

        $report = app(ShiftOverlapReconciliationService::class)->reconcile($this->tenant, $drawer, '0.00', 'x', $foreignOwner->id, true);

        $this->assertFalse($report['applied']);
        $this->assertContains('ACTOR_INVALID', array_column($report['blockers'], 'code'));
    }

    public function test_20e_reconciliation_apply_refuses_an_insufficient_role_actor(): void
    {
        [$drawer] = $this->legacyOverlap('0.00');
        $cashier = $this->cashier($this->branchA);

        $report = app(ShiftOverlapReconciliationService::class)->reconcile($this->tenant, $drawer, '0.00', 'x', $cashier->id, true);

        $this->assertFalse($report['applied']);
        $this->assertContains('ACTOR_NOT_AUTHORIZED', array_column($report['blockers'], 'code'));
    }

    public function test_20f_reconciliation_apply_accepts_a_valid_privileged_actor(): void
    {
        [$drawer] = $this->legacyOverlap('0.00');

        $report = app(ShiftOverlapReconciliationService::class)->reconcile($this->tenant, $drawer, '0.00', 'valid owner', $this->owner->id, true);

        $this->assertTrue($report['applied']);
    }

    public function test_20g_adoption_apply_refuses_an_insufficient_role_actor(): void
    {
        $this->configureClose($this->branchA, $this->safe(), '0.00');
        $shift = (int) $this->open($this->branchA, '0.00')->assertCreated()->json('data.id');
        DB::table('shifts')->where('id', $shift)->update(['close_destination_financial_location_id' => null]);
        $cashier = $this->cashier($this->branchA);

        $report = app(LegacyShiftCloseConfigurationAdoptionService::class)->adopt($this->tenant, $shift, 'x', $cashier->id, true);

        $this->assertFalse($report['applied']);
        $this->assertContains('ACTOR_NOT_AUTHORIZED', array_column($report['blockers'], 'code'));
    }

    public function test_21_to_24_overlap_reconciliation_preserves_history_moves_no_cash_closes_all_and_audits(): void
    {
        [$drawer, $shifts] = $this->legacyOverlap('300.00');
        $this->order($shifts[0], 'paid', 'paid', '40.00', withPayment: true);
        $this->order($shifts[1], 'paid', 'paid', '60.00', withPayment: true);
        $this->order($shifts[1], 'cancelled', 'unpaid', '5.00');
        $before = $this->financialFingerprint();
        $transfersBefore = DB::table('cash_transfers')->where('tenant_id', $this->tenant)->count();

        $this->artisan('shifts:reconcile-overlap', [
            'tenantId' => $this->tenant, 'financialLocationId' => $drawer, '--confirmed-cash' => '300.00',
            '--reason' => 'Staging overlap cleanup', '--actor' => $this->owner->id, '--apply' => true,
        ])->assertExitCode(0);

        // 21: orders, payments, journals, stock movements, vouchers preserved exactly.
        $this->assertSame($before, $this->financialFingerprint());
        // 22: no cash transfer; cash stays in the drawer ledger.
        $this->assertSame($transfersBefore, DB::table('cash_transfers')->where('tenant_id', $this->tenant)->count());
        $this->assertSame('300.00', $this->ledger($this->branchA));
        // 23: every overlapping shift is administratively closed at one timestamp.
        $rows = DB::table('shifts')->whereIn('id', $shifts)->get();
        $this->assertCount(2, $rows);
        foreach ($rows as $row) {
            $this->assertSame('closed', $row->status);
            $this->assertSame('legacy_reconcile', $row->close_type);
            $this->assertNull($row->closing_cash);
            $this->assertNull($row->close_transfer_id);
            $this->assertSame('0.00', $row->cash_difference);
            $this->assertStringContainsString('[legacy_reconcile', $row->notes);
        }
        $this->assertCount(1, $rows->pluck('closed_at')->unique());
        $this->assertSame(0, $this->openShiftCount($drawer));
        // 24: durable audit record in the existing activity_logs subsystem.
        $audit = DB::table('activity_logs')->where('tenant_id', $this->tenant)->where('action', 'shift.legacy_overlap_reconciled')->sole();
        $after = json_decode($audit->after_state, true);
        $this->assertSame('financial_location', $audit->entity_type);
        $this->assertSame($drawer, (int) $audit->entity_id);
        $this->assertSame($this->branchA, (int) $audit->branch_id);
        $this->assertSame($this->owner->id, (int) $audit->user_id);
        $this->assertEqualsCanonicalizing(array_map('intval', $shifts), $after['affectedShiftIds']);
        $this->assertSame('300.00', $after['drawerLedgerBalance']);
        $this->assertSame('300.00', $after['confirmedPhysicalCash']);
        $this->assertSame('Staging overlap cleanup', $after['reason']);
        $this->assertFalse($after['cashTransferCreated']);
        $this->assertNotEmpty($after['reconciledAt']);
        $this->assertCount(2, json_decode($audit->before_state, true)['originalShifts']);
        $this->assertSame(2, DB::table('activity_logs')->where('tenant_id', $this->tenant)->where('action', 'shift.legacy_reconciled')->count());
    }

    public function test_25_new_clean_shift_opens_after_reconciliation_with_the_full_drawer_balance(): void
    {
        [$drawer, $shifts] = $this->legacyOverlap('300.00');
        app(ShiftOverlapReconciliationService::class)->reconcile($this->tenant, $drawer, '300.00', 'cleanup', $this->owner->id, true);

        // The standard one-open-shift constraint can now be installed safely.
        (require database_path('migrations/2026_09_29_000001_one_open_shift_per_cash_drawer.php'))->up();
        $this->assertTrue(DB::table('pg_indexes')->where('indexname', 'shifts_one_open_per_location')->exists());

        $this->open($this->branchA, '100.00')->assertUnprocessable()->assertJsonValidationErrors('openingCash');
        $clean = $this->open($this->branchA, '300.00')->assertCreated()->json('data');
        $this->assertEquals(300, $clean['openingCash']);
        $this->assertSame(1, $this->openShiftCount($drawer));
        $this->assertNotContains($clean['id'], array_map('intval', $shifts));
    }

    // ---- A2.8 legacy single open shift configuration adoption ----------------

    public function test_26_legacy_open_shift_config_adoption_is_audited_and_creates_no_financial_entries(): void
    {
        $this->configureClose($this->branchA, $this->safe(), '15.00');
        $shift = $this->open($this->branchA, '0.00')->json('data.id');
        DB::table('shifts')->where('id', $shift)->update(['close_destination_financial_location_id' => null, 'closing_float_amount' => '0.00']);
        $before = $this->financialFingerprint();
        $service = app(LegacyShiftCloseConfigurationAdoptionService::class);

        $dry = $service->adopt($this->tenant, $shift, null, null, false);
        $this->assertSame([], $dry['blockers']);
        $this->assertNull(DB::table('shifts')->where('id', $shift)->value('close_destination_financial_location_id'));

        $this->artisan('shifts:adopt-close-config', ['tenantId' => $this->tenant, 'shiftId' => $shift, '--reason' => 'Branch configured after open', '--actor' => $this->owner->id, '--apply' => true])->assertExitCode(0);

        $row = DB::table('shifts')->find($shift);
        $this->assertSame($this->safe(), (int) $row->close_destination_financial_location_id);
        $this->assertSame('15.00', $row->closing_float_amount);
        $this->assertSame('open', $row->status);
        $this->assertSame($before, $this->financialFingerprint());
        $audit = DB::table('activity_logs')->where('action', 'shift.close_configuration_adopted')->where('entity_id', $shift)->sole();
        $this->assertNull(json_decode($audit->before_state, true)['shift']['close_destination_financial_location_id']);
        $this->assertFalse(json_decode($audit->after_state, true)['financialEntriesCreated']);
        // Never overwrite an existing snapshot.
        $again = $service->adopt($this->tenant, $shift, 'again', $this->owner->id, true);
        $this->assertContains('ALREADY_CONFIGURED', array_column($again['blockers'], 'code'));
    }

    public function test_26b_adoption_refuses_a_shift_that_overlaps_another_on_its_drawer(): void
    {
        [, $shifts] = $this->legacyOverlap('0.00');
        DB::table('shifts')->whereIn('id', $shifts)->update(['close_destination_financial_location_id' => null]);

        $report = app(LegacyShiftCloseConfigurationAdoptionService::class)->adopt($this->tenant, (int) $shifts[0], 'x', $this->owner->id, true);

        $this->assertFalse($report['applied']);
        $this->assertContains('OVERLAPPING_OPEN_SHIFT', array_column($report['blockers'], 'code'));
        $this->assertNull(DB::table('shifts')->where('id', $shifts[0])->value('close_destination_financial_location_id'));
    }

    // ---- A2.10 permissions & localisation -------------------------------------

    public function test_27_tenant_and_branch_permissions_remain_enforced(): void
    {
        $cashierA = $this->cashier($this->branchA);
        $cashierHeaders = $this->bearer($this->tenant, $cashierA);
        // Branch isolation: a branch-A cashier cannot open or inspect branch B's drawer.
        $this->open($this->branchB, '0.00', $cashierHeaders)->assertForbidden();
        $this->getJson("/api/v1/shifts/readiness?branchId={$this->branchB}", $cashierHeaders)->assertForbidden();
        // Only the owner of a shift can close it.
        $ownerShift = $this->open($this->branchA, '0.00')->json('data.id');
        $this->postJson("/api/v1/shifts/{$ownerShift}/close", ['closingCash' => '0.00'], $cashierHeaders)->assertForbidden();
        // Tenant isolation: another tenant can neither see nor close it nor reconcile its drawer.
        $other = (int) DB::table('tenants')->insertGetId(['name' => 'Other', 'slug' => 'a2-perm-other', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $otherOwner = User::query()->create(['tenant_id' => $other, 'name' => 'Other Owner', 'email' => 'a2-other@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true]);
        $this->postJson("/api/v1/shifts/{$ownerShift}/close", ['closingCash' => '0.00'], $this->bearer($other, $otherOwner))->assertNotFound();
        $this->open($this->branchA, '0.00', $this->bearer($other, $otherOwner))->assertUnprocessable()->assertJsonValidationErrors('branchId');
        $report = app(ShiftOverlapReconciliationService::class)->reconcile($other, $this->drawer($this->branchA), '0.00', 'x', $otherOwner->id, true);
        $this->assertSame(['LOCATION_NOT_FOUND'], array_column($report['blockers'], 'code'));
        $this->assertSame('open', DB::table('shifts')->where('id', $ownerShift)->value('status'));
        // Cashiers cannot change the drawer close configuration.
        $this->putJson("/api/v1/cafe-configuration/branches/{$this->branchA}", ['shiftClosingFloatAmount' => '5.00'], $cashierHeaders)->assertForbidden();
    }

    public function test_27b_readiness_endpoint_does_not_leak_another_tenants_branch_configuration(): void
    {
        $this->configureClose($this->branchA, $this->safe(), '50.00');
        $this->fund($this->branchA, '200.00');
        $other = (int) DB::table('tenants')->insertGetId(['name' => 'M6 Readiness Other', 'slug' => 'a2-readiness-other', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $otherOwner = User::query()->create(['tenant_id' => $other, 'name' => 'Readiness Other Owner', 'email' => 'a2-readiness-other@example.test', 'password' => 'password', 'role' => 'owner', 'is_active' => true]);

        // Tenant B asking for tenant A's branch id must get a plain
        // validation rejection, never tenant A's drawer/ledger/destination.
        $response = $this->getJson("/api/v1/shifts/readiness?branchId={$this->branchA}", $this->bearer($other, $otherOwner))
            ->assertUnprocessable()->assertJsonValidationErrors('branchId');
        $this->assertStringNotContainsString('200', $response->getContent());
        $this->assertStringNotContainsString((string) $this->drawer($this->branchA), $response->getContent());
    }

    public function test_28_shift_lifecycle_errors_are_presented_in_arabic_by_default_and_english_on_request(): void
    {
        $this->open($this->branchA, '0.00')->assertCreated();
        $cashierHeaders = $this->bearer($this->tenant, $this->cashier($this->branchA));

        $arabic = $this->open($this->branchA, '0.00', $cashierHeaders)->assertUnprocessable();
        $this->assertSame('يوجد وردية مفتوحة بالفعل على صندوق النقدية هذا.', $arabic->json('errors.branchId.0'));
        $this->assertMatchesRegularExpression('/[\x{0600}-\x{06FF}]/u', $arabic->json('message'));

        DB::table('branches')->where('id', $this->branchB)->update(['shift_close_destination_financial_location_id' => null]);
        $missing = $this->open($this->branchB, '0.00')->assertUnprocessable();
        $this->assertSame('لا يمكن فتح الوردية لأن وجهة تحويل النقدية عند إغلاق الوردية غير محددة لهذا الفرع.', $missing->json('errors.'.ShiftDrawerReadinessService::FIELD_DESTINATION.'.0'));
        $this->assertStringNotContainsString('financial_locations', $missing->getContent());

        $english = $this->open($this->branchA, '0.00', $cashierHeaders + ['X-App-Locale' => 'en'])->assertUnprocessable();
        $this->assertSame('This cash drawer already has an open shift.', $english->json('errors.branchId.0'));
    }

    // ---- A2.9 reporting --------------------------------------------------------

    public function test_reports_distinguish_manual_automatic_and_legacy_reconcile_closes(): void
    {
        // Legacy reconciliation on drawer A.
        [$drawer, $shifts] = $this->legacyOverlap('0.00');
        app(ShiftOverlapReconciliationService::class)->reconcile($this->tenant, $drawer, '0.00', 'cleanup', $this->owner->id, true);
        // Automatic close on drawer B.
        $auto = $this->open($this->branchB, '0.00')->json('data.id');
        app(AutomaticShiftCloseService::class)->close($this->tenant, $auto);

        $history = collect($this->getJson('/api/v1/shifts/history', $this->headers)->assertOk()->json('data'));
        $legacy = $history->firstWhere('closeType', 'legacy_reconcile');
        $this->assertNotNull($legacy);
        $this->assertNull($legacy['cashDifference']);
        $this->assertFalse($legacy['cashCounted']);
        $this->assertTrue($legacy['administrativeClose']);
        $this->assertSame('closed', $legacy['status']);
        $automatic = $history->firstWhere('closeType', 'automatic');
        $this->assertNull($automatic['cashDifference']);
        $this->assertFalse($automatic['cashCounted']);

        $number = DB::table('shifts')->where('id', $shifts[0])->value('shift_number');
        $report = $this->getJson("/api/v1/shifts/{$number}/report", $this->headers)->assertOk()->json('data');
        $this->assertSame('legacy_reconcile', $report['closeType']);
        $this->assertNull($report['cash']['expected']);
        $this->assertNull($report['cash']['actual']);
        $this->assertNull($report['cash']['difference']);
        $this->assertNull($report['closeTransferId']);

        // Legacy/automatic closes with a stored non-zero difference are never "critical cash differences".
        DB::table('shifts')->whereIn('id', [...$shifts, $auto])->update(['cash_difference' => '12.00']);
        $exceptions = $this->getJson('/api/v1/reports/overview', $this->headers)->assertOk()->json('data.recentExceptions');
        $this->assertIsArray($exceptions);
        $this->assertSame([], array_values(array_filter($exceptions, fn ($e) => str_contains($e['description'] ?? '', 'Cash difference'))));
    }

    // ---- helpers ---------------------------------------------------------------

    private function open(int $branch, string $cash, ?array $headers = null)
    {
        return $this->postJson('/api/v1/shifts/current', ['branchId' => $branch, 'openingCash' => $cash], $headers ?? $this->headers);
    }

    /** Two historical open shifts on branch A's drawer, as created before the unique index existed. */
    private function legacyOverlap(string $ledger): array
    {
        if ($ledger !== '0.00') {
            $this->fund($this->branchA, $ledger);
        }
        $first = (int) $this->open($this->branchA, $ledger)->assertCreated()->json('data.id');
        DB::statement('DROP INDEX IF EXISTS shifts_one_open_per_location');
        $cashier = $this->cashier($this->branchA);
        $second = (int) DB::table('shifts')->insertGetId([
            'tenant_id' => $this->tenant, 'branch_id' => $this->branchA, 'user_id' => $cashier->id,
            'financial_location_id' => $this->drawer($this->branchA), 'close_destination_financial_location_id' => $this->safe(),
            'shift_number' => 'SH-LEGACY-002', 'opening_cash' => $ledger, 'status' => 'open', 'opened_at' => now()->subHour(),
            'created_at' => now(), 'updated_at' => now(),
        ]);

        return [$this->drawer($this->branchA), [$first, $second]];
    }

    private function order(int $shift, string $status, string $paymentStatus, string $total, bool $withPayment = false): int
    {
        $id = (int) DB::table('orders')->insertGetId([
            'tenant_id' => $this->tenant, 'branch_id' => $this->branchA, 'shift_id' => $shift,
            'order_number' => 'A2-'.uniqid(), 'type' => 'takeaway', 'status' => $status, 'payment_status' => $paymentStatus,
            'subtotal' => $total, 'total' => $total, 'tax_rate' => 0, 'opened_at' => now(),
            'deleted_at' => $status === 'cancelled' ? now() : null, 'created_at' => now(), 'updated_at' => now(),
        ]);
        if ($withPayment) {
            DB::table('payments')->insert(['tenant_id' => $this->tenant, 'branch_id' => $this->branchA, 'order_id' => $id, 'shift_id' => $shift, 'method' => 'cash', 'amount' => $total, 'status' => 'completed', 'paid_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        }

        return $id;
    }

    /** Every financial/history row of the tenant, serialized, to prove nothing was rewritten. */
    private function financialFingerprint(): string
    {
        $tables = ['orders', 'payments', 'journal_entries', 'cash_transfers', 'stock_movements', 'finance_documents', 'payment_refunds'];
        $data = [];
        foreach ($tables as $table) {
            $data[$table] = DB::table($table)->where('tenant_id', $this->tenant)->orderBy('id')->get()->toArray();
        }
        $data['journal_entry_lines'] = DB::table('journal_entry_lines')->where('tenant_id', $this->tenant)->orderBy('id')->get()->toArray();

        return json_encode($data);
    }

    private function configureClose(int $branch, int $destination, string $float): void
    {
        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", [
            'shiftCloseDestinationFinancialLocationId' => $destination, 'shiftClosingFloatAmount' => $float,
        ], $this->headers)->assertOk();
    }

    private function fund(int $branch, string $amount): void
    {
        $this->postJson('/api/v1/finance/cash-transfers', [
            'fromFinancialLocationId' => $this->safe(), 'toFinancialLocationId' => $this->drawer($branch),
            'amount' => $amount, 'transferDate' => now()->toDateString(), 'idempotencyKey' => 'a2-fund-'.$branch.'-'.$amount.'-'.uniqid(),
        ], $this->headers)->assertCreated();
    }

    private function ledger(int $branch): string
    {
        $drawer = $this->drawer($branch);
        $account = (int) DB::table('financial_locations')->where('id', $drawer)->value('financial_account_id');

        return app(FinancialAccountBalanceQuery::class)->summary($this->tenant, $account, locationId: $drawer)['balance'];
    }

    private function drawer(int $branch): int
    {
        return (int) DB::table('branches')->where('id', $branch)->value('pos_cash_financial_location_id');
    }

    private function safe(): int
    {
        return (int) DB::table('financial_locations')->where('tenant_id', $this->tenant)->where('code', 'MAIN-SAFE')->value('id');
    }

    private function cashLocation(string $code, ?int $branch): int
    {
        return (int) DB::table('financial_locations')->insertGetId([
            'tenant_id' => $this->tenant, 'branch_id' => $branch,
            'financial_account_id' => DB::table('financial_accounts')->where('tenant_id', $this->tenant)->where('code', '1020')->value('id'),
            'code' => $code, 'name' => $code, 'kind' => 'cash', 'type' => 'petty_cash', 'is_active' => true, 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function openShiftCount(int $drawer): int
    {
        return DB::table('shifts')->where('tenant_id', $this->tenant)->where('financial_location_id', $drawer)->where('status', 'open')->whereNull('deleted_at')->count();
    }

    private function cashier(int $branch): User
    {
        $cashier = User::query()->create(['tenant_id' => $this->tenant, 'name' => 'Cashier '.uniqid(), 'email' => 'a2-cashier-'.uniqid().'@example.test', 'password' => 'password', 'role' => 'cashier', 'is_active' => true]);
        DB::table('user_branches')->insert(['tenant_id' => $this->tenant, 'user_id' => $cashier->id, 'branch_id' => $branch, 'created_at' => now(), 'updated_at' => now()]);

        return $cashier;
    }

    private function bearer(int $tenant, User $user): array
    {
        return ['Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant, $user)];
    }
}
