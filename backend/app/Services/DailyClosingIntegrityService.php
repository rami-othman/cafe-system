<?php

namespace App\Services;

use App\Domain\Inventory\InventoryAccountingMapper;
use App\Support\Money;
use Illuminate\Support\Facades\DB;

/**
 * Live (never-snapshotted) integrity signals for Daily Closing: financial
 * activity discovered after a day was already closed, and inventory
 * movements whose mandatory Finance posting is missing/failed/unconfigured.
 * Reuses InventoryAccountingMapper as the sole applicability engine rather
 * than re-deriving posting rules here.
 */
final class DailyClosingIntegrityService
{
    private const INVENTORY_POSTING_TYPES = ['waste', 'stock_count_variance', 'adjustment_in', 'adjustment_out'];

    public function __construct(private readonly InventoryAccountingMapper $mapper) {}

    /** Posted journals dated within the closed business day but posted after closed_at. */
    public function lateActivityAfterClose(int $tenant, int $branch, string $date, string $closedAt): array
    {
        return DB::table('journal_entries')
            ->where('tenant_id', $tenant)
            ->where('branch_id', $branch)
            ->where('status', 'posted')
            ->whereDate('entry_date', $date)
            ->where('posted_at', '>', $closedAt)
            ->orderBy('posted_at')
            ->get(['id', 'entry_number', 'source_type', 'source_id', 'posted_at'])
            ->map(fn (object $entry): array => [
                'code' => 'LATE_FINANCIAL_ACTIVITY_AFTER_CLOSE',
                'journalId' => (int) $entry->id,
                'reference' => $entry->entry_number,
                'sourceType' => $entry->source_type,
                'sourceId' => $entry->source_id !== null ? (int) $entry->source_id : null,
                'amount' => $this->journalAmount($tenant, (int) $entry->id),
                'postedAt' => $entry->posted_at,
            ])
            ->values()
            ->all();
    }

    /** Inventory movements for this business date whose mandatory Finance posting is missing, failed, or unconfigured. */
    public function inventoryPostingIssues(int $tenant, int $branch, string $date): array
    {
        return DB::table('stock_movements as m')
            ->leftJoin('inventory_items as i', 'i.id', '=', 'm.inventory_item_id')
            ->where('m.tenant_id', $tenant)
            ->where('m.branch_id', $branch)
            ->whereDate('m.occurred_at', $date)
            ->whereIn('m.type', self::INVENTORY_POSTING_TYPES)
            ->get(['m.id', 'm.type', 'm.reference_type', 'm.reference_id', 'm.total_cost', 'm.quantity_out', 'i.name_en as item_name_en', 'i.name_ar as item_name_ar'])
            ->map(function (object $movement) use ($tenant): ?array {
                $impact = $this->mapper->impactForMovement($tenant, $movement);
                if (! in_array($impact['status'], ['CONFIGURATION_REQUIRED', 'FAILED'], true)) {
                    return null;
                }

                return [
                    'code' => 'UNPOSTED_INVENTORY_FINANCIAL_EVENT',
                    'movementId' => (int) $movement->id,
                    'movementReference' => $movement->reference_type && $movement->reference_id ? $movement->reference_type.':'.$movement->reference_id : null,
                    'type' => $movement->type,
                    'item' => $movement->item_name_en ?? $movement->item_name_ar,
                    'amount' => Money::decimal(Money::cents((string) $movement->total_cost, 'totalCost')),
                    'financeStatus' => $impact['status'],
                    'message' => $impact['message'] ?? null,
                ];
            })
            ->filter()
            ->values()
            ->all();
    }

    private function journalAmount(int $tenant, int $journalId): ?string
    {
        $totals = DB::table('journal_entry_lines')->where('tenant_id', $tenant)->where('journal_entry_id', $journalId)
            ->selectRaw('COALESCE(SUM(debit),0) as debit, COALESCE(SUM(credit),0) as credit')->first();
        if (! $totals) {
            return null;
        }

        return Money::decimal(max(Money::cents($totals->debit), Money::cents($totals->credit)));
    }
}
