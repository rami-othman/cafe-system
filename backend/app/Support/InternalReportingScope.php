<?php
namespace App\Support;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
final class InternalReportingScope {
    public static function consolidated(?array $context = null): bool {
        if ($context !== null) return ($context['branchId'] ?? null) === null && ! ($context['includeInternal'] ?? false) && isset($context['actorId']) && FinancialActor::user($context['actorId'], $context['tenantId'])->isOwner();
        $request = request(); $actor = $request->attributes->get('auth_user');
        return $actor instanceof \App\Models\User && $actor->isOwner() && ! $request->filled('branchId') && ! $request->filled('branch_id') && ! $request->boolean('includeInternal');
    }
    public static function party(Builder $query, string $column, string $table, ?array $context = null): Builder {
        if (! self::consolidated($context)) return $query;
        return $query->whereNotIn($column, DB::table($table)->where('is_internal', true)->select('id'));
    }
    public static function journals(Builder $query, array $context): Builder {
        if (! self::consolidated($context)) return $query;
        foreach (['sales_invoice' => ['sales_invoices', 'customers', 'customer_id'], 'sales_credit_note' => ['sales_credit_notes', 'customers', 'customer_id'], 'customer_payment' => ['customer_payments', 'customers', 'customer_id'], 'customer_refund' => ['customer_refunds', 'customers', 'customer_id'], 'supplier_invoice' => ['supplier_invoices', 'suppliers', 'supplier_id'], 'supplier_payment' => ['supplier_payments', 'suppliers', 'supplier_id']] as $source => [$documents, $parties, $foreign]) {
            $query->where(fn ($q) => $q->whereNull('entries.source_type')->orWhereNotIn('entries.source_type', [$source, $source.'_reversal'])->orWhereNotIn('entries.source_id', DB::table($documents.' as internal_d')->join($parties.' as internal_p', 'internal_p.id', '=', 'internal_d.'.$foreign)->where('internal_p.is_internal', true)->where('internal_d.tenant_id', $context['tenantId'])->select('internal_d.id')));
        }
        return $query;
    }
}
