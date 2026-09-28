<?php

namespace App\Services;

use App\Models\User;
use App\Support\Money;
use App\Support\SalesTotals;
use App\Support\ShiftClosePresentation;
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
            if (! empty($shift->close_snapshot)) {
                return $this->frozenEntry($shift);
            }
            $cash = $this->cashSummary->summarize((int) $shift->tenant_id, $shift);
            $sales = DB::table('orders')->where('tenant_id', $shift->tenant_id)->where('shift_id', $shift->id)->whereNull('deleted_at')->whereIn('payment_status', ['paid', 'partially_refunded', 'refunded'])->selectRaw('COUNT(*) as count, COALESCE(SUM(total + COALESCE(discount_total, 0)),0) as gross, COALESCE(SUM(discount_total),0) as discounts')->first();
            $refunds = Money::cents(DB::table('payment_refunds')->where('tenant_id', $shift->tenant_id)->where('shift_id', $shift->id)->where('status', 'completed')->sum('amount') ?? '0');
            $barDifferences = DB::table('stock_count_lines as l')->join('stock_counts as c', 'c.id', '=', 'l.stock_count_id')->where('c.tenant_id', $shift->tenant_id)->where('c.shift_id', $shift->id)->where('c.count_type', 'shift_check')->where('l.variance_quantity', '!=', 0)->count();
            // Only a physically counted (manual) close can carry a cash difference;
            // automatic and legacy_reconcile closes report none (null), never a fabricated one.
            $presentation = ShiftClosePresentation::for($shift);
            $difference = $presentation['cashDifference'];
            // Same purchases/expenses split as ShiftSnapshotService (T5):
            // shift_cash_movements' `expenses` figure already folds supplier
            // payments in, so purchasesPaid is subtracted back out of it.
            $purchasesPaidCents = Money::cents((string) DB::table('shift_cash_movements')->where('tenant_id', $shift->tenant_id)->where('shift_id', $shift->id)->where('source_type', 'supplier_payment')->sum('amount') ?: '0');
            $expensesPaidCents = max(0, Money::cents($cash['expenses']) - $purchasesPaidCents);
            $salesTotals = SalesTotals::make(Money::cents($sales->gross ?? '0'), $refunds, Money::cents($sales->discounts ?? '0'), $purchasesPaidCents, $expensesPaidCents);

            return ['shiftNumber' => $shift->shift_number ?? 'SH-'.str_pad((string) $shift->id, 6, '0', STR_PAD_LEFT), 'date' => $this->timestamp($shift->opened_at), 'cashierName' => $shift->cashier_name, 'branchName' => $shift->branch_name, 'openedAt' => $this->timestamp($shift->opened_at), 'closedAt' => $this->timestamp($shift->closed_at), 'orderCount' => (int) ($sales->count ?? 0), 'netSales' => Money::decimal(Money::cents($sales->gross ?? '0') - Money::cents($sales->discounts ?? '0') - $refunds), 'cashSales' => $cash['cashSales'], 'cashDifference' => $difference, 'barDifferenceCount' => $barDifferences, 'closeType' => $presentation['closeMode'], 'cashCounted' => $presentation['cashCounted'], 'administrativeClose' => $presentation['administrativeClose'], 'status' => $presentation['cashCounted'] && abs(Money::cents($difference)) > 50 ? 'closedWithDifference' : 'closed'] + $salesTotals;
        })->values()->all();

        return ['data' => $data, 'meta' => ['currentPage' => $paginator->currentPage(), 'perPage' => $paginator->perPage(), 'total' => $paginator->total(), 'lastPage' => $paginator->lastPage()]];
    }

    private function timestamp(?string $value): ?string
    {
        return $value === null ? null : CarbonImmutable::parse($value, 'UTC')->toIso8601String();
    }

    private function frozenEntry(object $shift): array
    {
        $snapshot = json_decode($shift->close_snapshot, true, 512, JSON_THROW_ON_ERROR);
        $sales = $snapshot['sales'];
        $presentation = ShiftClosePresentation::for($shift);
        $differences = collect($snapshot['barCount']['lines'])->filter(fn ($line) => $line['counted'] !== null && abs((float) $line['counted'] - (float) $line['theoretical']) > 0.0001)->count();

        return [
            'shiftNumber' => $shift->shift_number, 'date' => $this->timestamp($shift->opened_at),
            'cashierName' => $snapshot['identity']['cashierName'], 'branchName' => $snapshot['identity']['branchName'],
            'openedAt' => $this->timestamp($shift->opened_at), 'closedAt' => $this->timestamp($shift->closed_at),
            'orderCount' => (int) $sales['orderCount'],
            'netSales' => Money::decimal(Money::cents($sales['grossSales']) - Money::cents($sales['discounts']) - Money::cents($sales['refunds'])),
            'cashSales' => $snapshot['drawer']['cashSales'], 'cashDifference' => $presentation['cashDifference'],
            'barDifferenceCount' => $differences, 'closeType' => $presentation['closeMode'],
            'cashCounted' => $presentation['cashCounted'], 'administrativeClose' => $presentation['administrativeClose'], 'status' => 'closed',
            'businessDate' => $shift->business_date, 'closeExecutedAt' => $this->timestamp($shift->close_executed_at),
            // A snapshot frozen before T5 has no salesSum/salesTotal/salesNet
            // of its own — salesTotal already equals the netSales above, so
            // it is the only safe fallback (purchases/expenses are not
            // reconstructable from an old snapshot without re-deriving them).
            'salesSum' => $sales['salesSum'] ?? Money::decimal(Money::cents($sales['grossSales'])),
            'salesTotal' => $sales['salesTotal'] ?? Money::decimal(Money::cents($sales['grossSales']) - Money::cents($sales['discounts']) - Money::cents($sales['refunds'])),
            'salesNet' => $sales['salesNet'] ?? Money::decimal(Money::cents($sales['grossSales']) - Money::cents($sales['discounts']) - Money::cents($sales['refunds'])),
            'purchasesPaid' => $sales['purchasesPaid'] ?? '0.00',
            'expensesPaid' => $sales['expensesPaid'] ?? '0.00',
        ];
    }
}
