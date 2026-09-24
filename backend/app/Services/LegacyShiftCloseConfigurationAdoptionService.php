<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

/**
 * Controlled, audited adoption of the branch's CURRENT validated close
 * configuration by a single legacy open shift that was opened before the
 * branch had a close destination (close_destination_financial_location_id
 * NULL). This is configuration adoption only: it copies the close destination
 * and closing float snapshot onto the shift and creates no financial entry.
 *
 * Default is a read-only dry run; mutation requires $apply = true.
 */
final class LegacyShiftCloseConfigurationAdoptionService
{
    public function __construct(
        private readonly ShiftDrawerReadinessService $readiness,
        private readonly OperationalAuditService $audit,
        private readonly AdminCommandActorGuard $actorGuard,
    ) {}

    /** @return array{applied: bool, dryRun: bool, blockers: list<array{code: string, message: string}>, shift: ?array, adopted: ?array} */
    public function adopt(int $tenantId, int $shiftId, ?string $reason, ?int $actorId, bool $apply = false): array
    {
        return DB::transaction(function () use ($tenantId, $shiftId, $reason, $actorId, $apply): array {
            $report = ['applied' => false, 'dryRun' => ! $apply, 'blockers' => [], 'shift' => null, 'adopted' => null, 'reason' => $reason, 'actorId' => $actorId];
            $block = function (string $code, string $message) use (&$report): void {
                $report['blockers'][] = ['code' => $code, 'message' => $message];
            };

            $shift = DB::table('shifts')->where('tenant_id', $tenantId)->where('id', $shiftId)->whereNull('deleted_at')->lockForUpdate()->first();
            if (! $shift) {
                $block('SHIFT_NOT_FOUND', "Shift {$shiftId} does not exist for tenant {$tenantId}.");

                return $report;
            }
            $report['shift'] = ['id' => (int) $shift->id, 'shiftNumber' => $shift->shift_number, 'branchId' => (int) $shift->branch_id, 'status' => $shift->status,
                'financialLocationId' => $shift->financial_location_id, 'closeDestinationFinancialLocationId' => $shift->close_destination_financial_location_id,
                'closingFloatAmount' => $shift->closing_float_amount];
            if ($shift->status !== 'open') {
                $block('SHIFT_NOT_OPEN', 'Only an open shift can adopt a close configuration.');
            }
            if ($shift->close_destination_financial_location_id !== null) {
                $block('ALREADY_CONFIGURED', 'This shift already has a close destination snapshot; it is never overwritten.');
            }
            if (! $shift->financial_location_id) {
                $block('SHIFT_HAS_NO_DRAWER', 'This shift has no cash drawer; it cannot adopt a close configuration.');
            } else {
                $overlap = DB::table('shifts')->where('tenant_id', $tenantId)->where('financial_location_id', $shift->financial_location_id)
                    ->where('status', 'open')->whereNull('deleted_at')->where('id', '<>', $shift->id)->lockForUpdate()->pluck('id');
                if ($overlap->isNotEmpty()) {
                    $block('OVERLAPPING_OPEN_SHIFT', 'Other open shifts share this drawer ('.$overlap->implode(', ').'). Reconcile the overlap first (shifts:reconcile-overlap).');
                }
                if (! $this->readiness->drawerLocation($tenantId, (int) $shift->branch_id, (int) $shift->financial_location_id, true)) {
                    $block('SHIFT_DRAWER_INVALID', 'The shift drawer is no longer an active cash drawer of its branch.');
                }
            }

            // Validate the branch's current close configuration with the canonical rules,
            // relative to the drawer this shift actually uses.
            $branch = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $shift->branch_id)->lockForUpdate()->first();
            $issues = $branch ? $this->readiness->configurationIssues(
                $tenantId, $branch,
                $shift->financial_location_id ? (int) $shift->financial_location_id : null,
                $branch->shift_close_destination_financial_location_id ? (int) $branch->shift_close_destination_financial_location_id : null,
                $branch->shift_closing_float_amount, true,
            ) : [['code' => 'BRANCH_UNAVAILABLE', 'message' => __('shifts.branch_unavailable')]];
            foreach ($issues as $issue) {
                if (! in_array($issue['code'], ['POS_DRAWER_NOT_CONFIGURED', 'POS_DRAWER_INVALID'], true)) {
                    $block($issue['code'], $issue['message']);
                }
            }
            if ($branch && $report['blockers'] === []) {
                $report['adopted'] = ['closeDestinationFinancialLocationId' => (int) $branch->shift_close_destination_financial_location_id,
                    'closingFloatAmount' => $branch->shift_closing_float_amount];
            }

            if ($apply) {
                if ($reason === null || trim($reason) === '') {
                    $block('REASON_REQUIRED', 'A --reason is required to apply the adoption.');
                }
                $actorIssue = $this->actorGuard->invalidReason($tenantId, $actorId);
                if ($actorIssue !== null) {
                    $block($actorIssue['code'], $actorIssue['message']);
                }
            }
            if (! $apply || $report['blockers'] !== []) {
                return $report;
            }

            $updated = DB::table('shifts')->where('tenant_id', $tenantId)->where('id', $shift->id)->where('status', 'open')
                ->whereNull('close_destination_financial_location_id')->update([
                    'close_destination_financial_location_id' => $report['adopted']['closeDestinationFinancialLocationId'],
                    'closing_float_amount' => $report['adopted']['closingFloatAmount'],
                    'updated_at' => now(),
                ]);
            if ($updated !== 1) {
                throw new \RuntimeException("Shift {$shift->id} changed during adoption; aborted without changes.");
            }
            $after = DB::table('shifts')->where('id', $shift->id)->first();
            $this->audit->recordContext($tenantId, 'shift.close_configuration_adopted', 'shift', (int) $shift->id, [
                'shift' => (array) $after, 'adopted' => $report['adopted'], 'reason' => $reason, 'actorId' => $actorId,
                'financialEntriesCreated' => false,
            ], $actorId, (int) $shift->branch_id, false, ['shift' => (array) $shift]);
            $report['applied'] = true;

            return $report;
        });
    }
}
