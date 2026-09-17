<?php

namespace App\Services;

use App\Models\User;
use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

/** Paginated closed-shift history, always constrained to the actor's branches. */
final class ShiftHistoryQueryService
{
    public function __construct(private readonly BranchAccessService $branches, private readonly ShiftCashSummaryService $cashSummary) {}

    /** @return array{data: array<int, array<string, mixed>>, meta: array<string, int>} */
    public function list(User $actor, int $page = 1, int $perPage = 25): array
    {
        $branchIds = $this->branches->accessibleBranchIds($actor);
        if ($branchIds === []) {
            return ['data' => [], 'meta' => ['currentPage' => 1, 'perPage' => $perPage, 'total' => 0, 'lastPage' => 1]];
        }
        $paginator = DB::table('shifts as s')->join('branches as b', 'b.id', '=', 's.branch_id')->join('users as u', 'u.id', '=', 's.user_id')
            ->where('s.tenant_id', $actor->tenant_id)->whereIn('s.branch_id', $branchIds)->where('s.status', 'closed')->whereNull('s.deleted_at')
            ->orderByDesc('s.closed_at')->paginate($perPage, ['s.*', 'b.name as branch_name', 'u.name as cashier_name'], 'page', $page);
        $data = collect($paginator->items())->map(function (object $shift): array {
            $cash = $this->cashSummary->summarize((int) $shift->tenant_id, $shift);
            $sales = DB::table('orders')->where('tenant_id', $shift->tenant_id)->where('shift_id', $shift->id)->whereNull('deleted_at')->where('status', 'paid')->selectRaw('COUNT(*) as count, COALESCE(SUM(total),0) as gross, COALESCE(SUM(discount_total),0) as discounts')->first();
            $refunds = Money::cents(DB::table('payment_refunds')->where('tenant_id', $shift->tenant_id)->where('shift_id', $shift->id)->where('status', 'completed')->sum('amount') ?? '0');
            $barDifferences = DB::table('stock_count_lines as l')->join('stock_counts as c', 'c.id', '=', 'l.stock_count_id')->where('c.tenant_id', $shift->tenant_id)->where('c.shift_id', $shift->id)->where('c.count_type', 'shift_check')->where('l.variance_quantity', '!=', 0)->count();
            $difference = Money::cents($shift->cash_difference);

            return ['shiftNumber' => $shift->shift_number ?? 'SH-'.str_pad((string) $shift->id, 6, '0', STR_PAD_LEFT), 'date' => $this->timestamp($shift->opened_at), 'cashierName' => $shift->cashier_name, 'branchName' => $shift->branch_name, 'openedAt' => $this->timestamp($shift->opened_at), 'closedAt' => $this->timestamp($shift->closed_at), 'orderCount' => (int) ($sales->count ?? 0), 'netSales' => Money::decimal(Money::cents($sales->gross ?? '0') - Money::cents($sales->discounts ?? '0') - $refunds), 'cashSales' => $cash['cashSales'], 'cashDifference' => Money::decimal($difference), 'barDifferenceCount' => $barDifferences, 'status' => abs($difference) > 50 ? 'closedWithDifference' : 'closed'];
        })->values()->all();

        return ['data' => $data, 'meta' => ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()]];
    }

    private function timestamp(?string $value): ?string
    {
        return $value === null ? null : CarbonImmutable::parse($value, 'UTC')->toIso8601String();
    }
}
