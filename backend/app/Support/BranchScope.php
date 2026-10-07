<?php

namespace App\Support;

use Illuminate\Database\Query\Builder;

/**
 * The single branch-scoping rule for tables that allow a nullable
 * company-wide branch_id (journal_entries, expenses, stock_movements,
 * supplier_invoices/payments, financial_locations): viewing one specific
 * branch means an EXACT match only — company-wide records are never
 * arbitrarily attributed to a branch. Viewing "all authorized branches"
 * includes company-wide (NULL) records alongside every authorized branch.
 */
final class BranchScope
{
    public static function applyFinancial(Builder $query, string $column, \App\Models\User $actor): Builder
    {
        if ($actor->isOwner()) return $query;
        $ids = FinancialActor::operationalBranchIds((int) $actor->id, (int) $actor->tenant_id);
        if ($actor->effectiveRoleCode() === 'factory_manager') return $query->whereIn($column, $ids);
        // Preserve the existing cafe role policy for company-wide records.
        return $query->where(fn (Builder $q) => $q->whereIn($column, $ids)->orWhereNull($column));
    }
    public static function apply(Builder $query, string $column, ?int $branchId, array $authorizedBranchIds): Builder
    {
        if ($branchId !== null) {
            return $query->where($column, $branchId);
        }

        return $query->where(fn (Builder $q) => $q->whereIn($column, $authorizedBranchIds)->orWhereNull($column));
    }

    /**
     * Branch scope for queries joined as `journal_entries as entries` + `journal_entry_lines as lines`.
     * A line's branch is its own branch_id, falling back to its entry's (lines written before the
     * line-level dimension, or by code that does not set it). Same NULL = company-wide rule as apply().
     */
    public static function applyJournalLines(Builder $query, ?int $branchId, array $authorizedBranchIds): Builder
    {
        $expression = 'COALESCE(lines.branch_id, entries.branch_id)';
        if ($branchId !== null) {
            return $query->whereRaw("$expression = ?", [$branchId]);
        }
        if ($authorizedBranchIds === []) {
            return $query->whereRaw("$expression IS NULL");
        }
        $ids = array_values(array_map('intval', $authorizedBranchIds));
        $placeholders = implode(',', array_fill(0, count($ids), '?'));

        return $query->where(fn (Builder $q) => $q->whereRaw("$expression IN ($placeholders)", $ids)->orWhereRaw("$expression IS NULL"));
    }
}
