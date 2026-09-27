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
}
