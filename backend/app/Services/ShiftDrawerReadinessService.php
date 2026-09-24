<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * The one canonical definition of "can this branch run a closable cash shift".
 *
 * Every consumer — shift open, branch configuration updates, the readiness
 * endpoint / branch payload, shift close transfer validation, and the legacy
 * configuration adoption command — calls the location validators here so the
 * rules for a POS drawer and a close destination cannot diverge.
 *
 * Issues are reported with a stable machine code, the request field they
 * belong to, and a localized message (lang/{ar,en}/shifts.php).
 */
class ShiftDrawerReadinessService
{
    public const FIELD_DRAWER = 'cashSource';

    public const FIELD_DESTINATION = 'shiftCloseDestinationFinancialLocationId';

    public const FIELD_FLOAT = 'shiftClosingFloatAmount';

    public function __construct(private readonly FinancialAccountBalanceQuery $balances) {}

    /**
     * Evaluates the branch's *current* configuration. With $lock the branch
     * row and the drawer location row are locked FOR UPDATE, which is what
     * serializes concurrent shift opens on the same physical drawer without
     * blocking other drawers.
     *
     * @return array{ready: bool, issues: list<array{code: string, field: string, message: string}>, branch: ?object, drawer: ?object, destination: ?object, closingFloat: string}
     */
    public function assess(int $tenantId, int $branchId, bool $lock = false): array
    {
        $branchQuery = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)
            ->where('is_active', true)->whereNull('deleted_at');
        if ($lock) {
            $branchQuery->lockForUpdate();
        }
        $branch = $branchQuery->first();
        if (! $branch) {
            return $this->result(null, null, null, '0.00', [$this->issue('BRANCH_UNAVAILABLE', 'branchId', 'branch_unavailable')]);
        }

        return $this->evaluate(
            $tenantId,
            $branch,
            $branch->pos_cash_financial_location_id ? (int) $branch->pos_cash_financial_location_id : null,
            $branch->shift_close_destination_financial_location_id ? (int) $branch->shift_close_destination_financial_location_id : null,
            $branch->shift_closing_float_amount ?? '0',
            $lock,
        );
    }

    /**
     * Validates a proposed configuration (e.g. a branch update payload merged
     * over the stored values) with exactly the same rules as shift open.
     *
     * @return list<array{code: string, field: string, message: string}>
     */
    public function configurationIssues(int $tenantId, object $branch, ?int $drawerId, ?int $destinationId, mixed $closingFloat, bool $requireDestination = false): array
    {
        $issues = $this->evaluate($tenantId, $branch, $drawerId, $destinationId, $closingFloat ?? '0', false)['issues'];
        if (! $requireDestination) {
            $issues = array_values(array_filter($issues, fn (array $issue): bool => $issue['code'] !== 'CLOSE_DESTINATION_NOT_CONFIGURED'));
        }

        return $issues;
    }

    /**
     * Throws a localized ValidationException (one message per field) unless the
     * branch configuration is ready. Returns the resolved configuration.
     *
     * @return array{branch: object, drawer: object, destination: object, closingFloat: string}
     */
    public function assertReady(int $tenantId, int $branchId, bool $lock = false): array
    {
        $result = $this->assess($tenantId, $branchId, $lock);
        if (! $result['ready']) {
            throw $this->exception($result['issues']);
        }

        return ['branch' => $result['branch'], 'drawer' => $result['drawer'], 'destination' => $result['destination'], 'closingFloat' => $result['closingFloat']];
    }

    /** @param list<array{code: string, field: string, message: string}> $issues */
    public function exception(array $issues): ValidationException
    {
        $messages = [];
        foreach ($issues as $issue) {
            $messages[$issue['field']][] = $issue['message'];
        }

        return ValidationException::withMessages($messages);
    }

    /**
     * An active cash drawer of this tenant that belongs to the branch, joined to
     * its active financial account. Locks only the location row when asked.
     */
    public function drawerLocation(int $tenantId, int $branchId, int $locationId, bool $lock = false): ?object
    {
        $query = $this->locationQuery($tenantId, $locationId)
            ->where('locations.branch_id', $branchId)->where('locations.type', 'cash_drawer');
        if ($lock) {
            $query->lock($this->lockClause());
        }

        return $query->first();
    }

    /**
     * An active cash location of this tenant, global or of the same branch.
     * The caller must additionally ensure it is not the drawer itself.
     */
    /**
     * A close destination must never be a physical POS drawer (M1): another
     * branch's shift could still be reading/writing that drawer, and routing
     * a close transfer into it would mutate a live drawer's ledger outside
     * that drawer's own shift lifecycle.
     */
    public function destinationLocation(int $tenantId, int $branchId, int $locationId, bool $lock = false): ?object
    {
        $query = $this->locationQuery($tenantId, $locationId)
            ->where('locations.type', '<>', 'cash_drawer')
            ->where(fn ($q) => $q->whereNull('locations.branch_id')->orWhere('locations.branch_id', $branchId));
        if ($lock) {
            $query->lock($this->lockClause());
        }

        return $query->first();
    }

    /** The posted location-specific ledger balance of a drawer, as a decimal string. */
    public function drawerLedgerBalance(int $tenantId, object $drawer): string
    {
        return $this->balances->summary($tenantId, (int) $drawer->financial_account_id, locationId: (int) $drawer->id)['balance'];
    }

    /** The currently open (not deleted) shift on a physical drawer, if any. */
    public function openShiftOnDrawer(int $tenantId, int $drawerId): ?object
    {
        return DB::table('shifts')->where('tenant_id', $tenantId)->where('financial_location_id', $drawerId)
            ->where('status', 'open')->whereNull('deleted_at')->orderBy('id')->first();
    }

    /**
     * Client-facing readiness payload (codes + localized messages + the
     * current drawer ledger balance used as the expected opening count).
     *
     * @return array<string, mixed>
     */
    public function payload(int $tenantId, int $branchId): array
    {
        $result = $this->assess($tenantId, $branchId);
        $drawer = $result['drawer'];
        $issues = $result['issues'];
        $openShift = null;
        if ($drawer) {
            $open = $this->openShiftOnDrawer($tenantId, (int) $drawer->id);
            if ($open) {
                $openShift = ['id' => (int) $open->id, 'shiftNumber' => $open->shift_number, 'userId' => (int) $open->user_id,
                    'userName' => DB::table('users')->where('id', $open->user_id)->value('name')];
                $issues[] = $this->issue('DRAWER_HAS_OPEN_SHIFT', 'branchId', 'drawer_has_open_shift');
            }
        }

        return [
            'branchId' => $branchId,
            'ready' => $issues === [],
            'canOpenShift' => $issues === [],
            'issues' => $issues,
            'drawer' => $drawer ? ['id' => (int) $drawer->id, 'name' => $drawer->name, 'ledgerBalance' => $this->drawerLedgerBalance($tenantId, $drawer)] : null,
            'closeDestination' => $result['destination'] ? ['id' => (int) $result['destination']->id, 'name' => $result['destination']->name] : null,
            'closingFloat' => $result['closingFloat'],
            'openShift' => $openShift,
        ];
    }

    private function evaluate(int $tenantId, object $branch, ?int $drawerId, ?int $destinationId, mixed $closingFloat, bool $lock): array
    {
        $issues = [];
        $drawer = null;
        $destination = null;
        $branchId = (int) $branch->id;

        if (! $drawerId) {
            $issues[] = $this->issue('POS_DRAWER_NOT_CONFIGURED', self::FIELD_DRAWER, 'drawer_not_configured');
        } else {
            $drawer = $this->drawerLocation($tenantId, $branchId, $drawerId, $lock);
            if (! $drawer) {
                $issues[] = $this->issue('POS_DRAWER_INVALID', self::FIELD_DRAWER, 'drawer_invalid');
            }
        }

        if (! $destinationId) {
            $issues[] = $this->issue('CLOSE_DESTINATION_NOT_CONFIGURED', self::FIELD_DESTINATION, 'destination_not_configured');
        } elseif ($drawerId && $destinationId === $drawerId) {
            $issues[] = $this->issue('CLOSE_DESTINATION_SAME_AS_DRAWER', self::FIELD_DESTINATION, 'destination_same_as_drawer');
        } elseif (DB::table('financial_locations')->where('tenant_id', $tenantId)->where('id', $destinationId)->value('type') === 'cash_drawer') {
            $issues[] = $this->issue('CLOSE_DESTINATION_IS_DRAWER', self::FIELD_DESTINATION, 'destination_is_drawer');
        } else {
            $destination = $this->destinationLocation($tenantId, $branchId, $destinationId, $lock);
            if (! $destination) {
                $issues[] = $this->issue('CLOSE_DESTINATION_INVALID', self::FIELD_DESTINATION, 'destination_invalid');
            }
        }

        try {
            $floatCents = is_numeric($closingFloat) ? Money::cents((string) $closingFloat) : -1;
        } catch (ValidationException) {
            $floatCents = -1;
        }
        if ($floatCents < 0) {
            $issues[] = $this->issue('CLOSING_FLOAT_INVALID', self::FIELD_FLOAT, 'closing_float_invalid');
        }

        return $this->result($branch, $drawer, $destination, Money::decimal(max($floatCents, 0)), $issues);
    }

    private function locationQuery(int $tenantId, int $locationId)
    {
        return DB::table('financial_locations as locations')
            ->join('financial_accounts as accounts', function ($join) use ($tenantId): void {
                $join->on('accounts.id', '=', 'locations.financial_account_id')->where('accounts.tenant_id', '=', $tenantId);
            })
            ->where('locations.tenant_id', $tenantId)->where('locations.id', $locationId)
            ->where('locations.kind', 'cash')->where('locations.is_active', true)
            ->where('accounts.is_active', true)->whereNull('accounts.deleted_at')
            ->select('locations.*', 'accounts.code as account_code');
    }

    /** Lock only the physical location row, never the shared cash account row. */
    private function lockClause(): string|bool
    {
        return DB::connection()->getDriverName() === 'pgsql' ? 'for update of locations' : true;
    }

    private function issue(string $code, string $field, string $key): array
    {
        return ['code' => $code, 'field' => $field, 'message' => __('shifts.'.$key)];
    }

    private function result(?object $branch, ?object $drawer, ?object $destination, string $float, array $issues): array
    {
        return ['ready' => $issues === [], 'issues' => $issues, 'branch' => $branch, 'drawer' => $drawer, 'destination' => $destination, 'closingFloat' => $float];
    }
}
