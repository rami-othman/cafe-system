<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Explicit administrative reconciliation of HISTORICAL overlapping open shifts
 * on one physical cash drawer (created before the one-open-shift invariant).
 *
 * Several legacy shifts may each hold real orders/payments on the same drawer,
 * so there is no reliable per-shift physical count. This service therefore
 * never merges or reassigns orders/payments, never rewrites journals, never
 * creates a cash transfer and never fabricates a count or difference. After
 * the operator confirms that the physical drawer cash equals the posted
 * location-specific ledger balance, it closes every overlapping shift at the
 * same timestamp with close_type `legacy_reconcile` (closing_cash NULL,
 * close_transfer_id NULL), leaving all cash in the drawer, and writes a
 * durable activity_logs audit record. The next shift then opens through the
 * normal API with openingCash == the complete drawer ledger balance.
 *
 * Default is a read-only dry run; mutation requires $apply = true.
 */
final class ShiftOverlapReconciliationService
{
    /** Order statuses that no normal workflow can still change. */
    public const TERMINAL_ORDER_STATUSES = ['paid', 'cancelled', 'refunded'];

    public function __construct(
        private readonly ShiftDrawerReadinessService $readiness,
        private readonly OperationalAuditService $audit,
        private readonly AdminCommandActorGuard $actorGuard,
    ) {}

    /** Read-only: every (tenant, drawer) with more than one live open shift. */
    public function detect(?int $tenantId = null): Collection
    {
        return DB::table('shifts')->where('status', 'open')->whereNull('deleted_at')->whereNotNull('financial_location_id')
            ->when($tenantId, fn ($q) => $q->where('tenant_id', $tenantId))
            ->groupBy('tenant_id', 'financial_location_id')->havingRaw('COUNT(*) > 1')
            ->orderBy('tenant_id')->orderBy('financial_location_id')
            ->selectRaw('tenant_id, financial_location_id, COUNT(*) as open_shift_count, MIN(opened_at) as first_opened_at')
            ->get()
            ->map(function (object $row): object {
                $row->shift_ids = DB::table('shifts')->where('tenant_id', $row->tenant_id)
                    ->where('financial_location_id', $row->financial_location_id)->where('status', 'open')
                    ->whereNull('deleted_at')->orderBy('id')->pluck('id')->map(fn ($id) => (int) $id)->all();

                return $row;
            });
    }

    /**
     * @return array{applied: bool, dryRun: bool, blockers: list<array{code: string, message: string}>, tenantId: int, financialLocationId: int, drawer: ?array, branchId: ?int, ledgerBalance: ?string, confirmedCash: ?string, shifts: list<array>, activeOrders: list<array>, reason: ?string, actorId: ?int, reconciledAt: ?string}
     */
    public function reconcile(int $tenantId, int $locationId, ?string $confirmedCash, ?string $reason, ?int $actorId, bool $apply = false): array
    {
        return DB::transaction(function () use ($tenantId, $locationId, $confirmedCash, $reason, $actorId, $apply): array {
            $report = [
                'applied' => false, 'dryRun' => ! $apply, 'blockers' => [], 'tenantId' => $tenantId,
                'financialLocationId' => $locationId, 'drawer' => null, 'branchId' => null, 'ledgerBalance' => null,
                'confirmedCash' => null, 'shifts' => [], 'activeOrders' => [], 'reason' => $reason, 'actorId' => $actorId,
                'reconciledAt' => null,
            ];
            $block = function (string $code, string $message) use (&$report): void {
                $report['blockers'][] = ['code' => $code, 'message' => $message];
            };

            // 1. Lock the physical drawer location row.
            $location = DB::table('financial_locations')->where('tenant_id', $tenantId)->where('id', $locationId)->lockForUpdate()->first();
            if (! $location) {
                $block('LOCATION_NOT_FOUND', "Financial location {$locationId} does not exist for tenant {$tenantId}.");

                return $report;
            }
            $report['drawer'] = ['id' => (int) $location->id, 'code' => $location->code, 'name' => $location->name, 'type' => $location->type, 'kind' => $location->kind];
            $report['branchId'] = $location->branch_id ? (int) $location->branch_id : null;
            if ($location->kind !== 'cash' || $location->type !== 'cash_drawer') {
                $block('NOT_A_CASH_DRAWER', 'Only a physical cash drawer location can be reconciled.');
            }

            // 2. Lock every currently overlapping open shift on it.
            $shifts = DB::table('shifts')->where('tenant_id', $tenantId)->where('financial_location_id', $locationId)
                ->where('status', 'open')->whereNull('deleted_at')->orderBy('id')->lockForUpdate()->get();
            if ($shifts->count() < 2) {
                $block('NO_OVERLAP', "Found {$shifts->count()} open shift(s) on this drawer; reconciliation requires at least 2 overlapping open shifts.");
            }

            // 3. Current posted location-specific drawer ledger balance.
            $ledger = $this->readiness->drawerLedgerBalance($tenantId, $location);
            $report['ledgerBalance'] = $ledger;
            if ($confirmedCash === null || trim($confirmedCash) === '') {
                $block('CONFIRMED_CASH_REQUIRED', "Provide --confirmed-cash equal to the counted physical drawer cash (ledger balance is {$ledger}).");
            } else {
                try {
                    $confirmedCents = Money::cents($confirmedCash, 'confirmedCash');
                    $report['confirmedCash'] = Money::decimal($confirmedCents);
                    if ($confirmedCents !== Money::cents($ledger)) {
                        $block('CONFIRMED_CASH_MISMATCH', "Confirmed physical cash {$report['confirmedCash']} does not equal the posted drawer ledger balance {$ledger}. Investigate before reconciling.");
                    }
                } catch (\Illuminate\Validation\ValidationException) {
                    $block('CONFIRMED_CASH_INVALID', 'The confirmed cash must be a non-negative amount with at most two decimals.');
                }
            }

            // 4. Inspect every order attached to those shifts.
            $shiftIds = $shifts->pluck('id')->all();
            $orders = $shiftIds === [] ? collect() : DB::table('orders')->where('tenant_id', $tenantId)->whereIn('shift_id', $shiftIds)
                ->get(['id', 'shift_id', 'order_number', 'status', 'payment_status', 'total', 'deleted_at']);
            $active = $orders->filter(fn (object $o): bool => $o->deleted_at === null && ! in_array($o->status, self::TERMINAL_ORDER_STATUSES, true));
            $report['activeOrders'] = $active->map(fn (object $o): array => ['id' => (int) $o->id, 'shiftId' => (int) $o->shift_id, 'orderNumber' => $o->order_number, 'status' => $o->status, 'paymentStatus' => $o->payment_status, 'total' => $o->total])->values()->all();
            if ($active->isNotEmpty()) {
                $block('ACTIVE_ORDERS', "{$active->count()} linked order(s) are still active (draft/held/other). Resolve them through the normal POS workflow first; reconciliation never cancels or reassigns orders.");
            }

            $report['shifts'] = $shifts->map(function (object $shift) use ($tenantId, $orders): array {
                $own = $orders->where('shift_id', $shift->id);

                return [
                    'id' => (int) $shift->id, 'shiftNumber' => $shift->shift_number, 'branchId' => (int) $shift->branch_id,
                    'userId' => (int) $shift->user_id, 'openedAt' => $shift->opened_at, 'openingCash' => $shift->opening_cash,
                    'closeDestinationFinancialLocationId' => $shift->close_destination_financial_location_id,
                    'orderCounts' => $own->groupBy('status')->map->count()->all(),
                    'completedPaymentCount' => DB::table('payments')->where('tenant_id', $tenantId)->where('shift_id', $shift->id)->where('status', 'completed')->count(),
                ];
            })->values()->all();

            if ($apply) {
                if ($reason === null || trim($reason) === '') {
                    $block('REASON_REQUIRED', 'A --reason is required to apply a reconciliation.');
                }
                $actorIssue = $this->actorGuard->invalidReason($tenantId, $actorId);
                if ($actorIssue !== null) {
                    $block($actorIssue['code'], $actorIssue['message']);
                }
            }

            if (! $apply || $report['blockers'] !== []) {
                return $report;
            }

            // 5. Administrative close of every overlapping shift at one timestamp.
            $now = now();
            $stamp = $now->copy()->utc()->toIso8601String();
            $report['reconciledAt'] = $stamp;
            $note = sprintf(
                '[legacy_reconcile %s] Administratively closed as one of %d overlapping open shifts on cash drawer #%d (%s). Posted drawer ledger balance %s equals confirmed physical cash %s. No per-shift count, no cash difference and no close transfer were recorded; all cash remains in the drawer for the next shift. Reason: %s. Actor user #%d.',
                $stamp, count($shiftIds), $locationId, $location->code, $ledger, $report['confirmedCash'], trim((string) $reason), $actorId,
            );
            foreach ($shifts as $shift) {
                $updated = DB::table('shifts')->where('tenant_id', $tenantId)->where('id', $shift->id)->where('status', 'open')->update([
                    'status' => 'closed',
                    'close_type' => ShiftCloseService::TYPE_LEGACY_RECONCILE,
                    'closed_at' => $now,
                    'closing_cash' => null,
                    'close_transfer_id' => null,
                    'report_number' => $shift->report_number ?: ($shift->shift_number ? 'RPT-'.str_replace('SH-', '', $shift->shift_number) : null),
                    'notes' => trim(($shift->notes ? $shift->notes."\n" : '').$note),
                    'updated_at' => $now,
                ]);
                if ($updated !== 1) {
                    throw new \RuntimeException("Shift {$shift->id} changed during reconciliation; aborted without changes.");
                }
                $after = DB::table('shifts')->where('id', $shift->id)->first();
                $this->audit->recordContext($tenantId, 'shift.legacy_reconciled', 'shift', (int) $shift->id,
                    ['shift' => (array) $after, 'financialLocationId' => $locationId, 'reconciledAt' => $stamp, 'reason' => $reason],
                    $actorId, (int) $shift->branch_id, false, ['shift' => (array) $shift]);
            }
            $report['applied'] = true;
            $this->audit->recordContext($tenantId, 'shift.legacy_overlap_reconciled', 'financial_location', $locationId, [
                'tenantId' => $tenantId, 'branchId' => $report['branchId'], 'financialLocationId' => $locationId,
                'drawer' => $report['drawer'], 'affectedShiftIds' => array_map('intval', $shiftIds),
                'drawerLedgerBalance' => $ledger, 'confirmedPhysicalCash' => $report['confirmedCash'],
                'reason' => $reason, 'actorId' => $actorId, 'reconciledAt' => $stamp,
                'shifts' => $report['shifts'], 'cashTransferCreated' => false,
            ], $actorId, $report['branchId'], false, ['originalShifts' => $shifts->map(fn ($s) => (array) $s)->values()->all()]);

            return $report;
        });
    }
}
