<?php

namespace App\Services;

use App\Support\Money;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Tenant-scoped, batched enrichment for journal-backed financial transactions.
 * This is deliberately read-only: journals remain the accounting truth and
 * source records only provide business context for their linked journal.
 */
final class FinancialTransactionSourceResolver
{
    public function resolve(int $tenantId, Collection $entries): array
    {
        $groups = $entries->filter(fn (object $entry) => $entry->source_id !== null)
            ->groupBy('source_type')->map(fn (Collection $rows) => $rows->pluck('source_id')->map(fn ($id) => (int) $id)->unique()->values());
        $sources = [];
        foreach ($groups as $type => $ids) {
            foreach ($this->records($tenantId, (string) $type, $ids->all()) as $id => $source) {
                $sources[$type][(int) $id] = $source;
            }
        }

        return $entries->mapWithKeys(function (object $entry) use ($sources): array {
            $source = $entry->source_id === null ? null : ($sources[$entry->source_type][(int) $entry->source_id] ?? null);
            return [(int) $entry->id => $this->serialize($entry, $source)];
        })->all();
    }

    private function records(int $tenantId, string $type, array $ids): array
    {
        if ($ids === []) return [];
        return match ($type) {
            'pos_order' => DB::table('orders as orders')->leftJoin('payments as payments', fn ($join) => $join->on('payments.order_id', '=', 'orders.id')->where('payments.tenant_id', $tenantId)->where('payments.status', 'completed'))
                ->leftJoin('payment_methods as methods', fn ($join) => $join->on('methods.id', '=', 'payments.payment_method_id')->where('methods.tenant_id', $tenantId))
                ->where('orders.tenant_id', $tenantId)->whereIn('orders.id', $ids)->whereNull('orders.deleted_at')
                ->select('orders.id', 'orders.order_number as reference', 'orders.total as amount', 'payments.payment_method_id', 'methods.code as payment_method_code', 'methods.name as payment_method_name')->get()->keyBy('id')->all(),
            'payment_refund' => DB::table('payment_refunds as refunds')->join('payments as payments', fn ($join) => $join->on('payments.id', '=', 'refunds.payment_id')->where('payments.tenant_id', $tenantId))
                ->leftJoin('payment_methods as methods', fn ($join) => $join->on('methods.id', '=', 'payments.payment_method_id')->where('methods.tenant_id', $tenantId))
                ->where('refunds.tenant_id', $tenantId)->whereIn('refunds.id', $ids)
                ->select('refunds.id', 'refunds.refund_number as reference', 'refunds.amount', 'payments.payment_method_id', 'methods.code as payment_method_code', 'methods.name as payment_method_name')->get()->keyBy('id')->all(),
            'expense' => DB::table('expenses as expenses')->leftJoin('payment_methods as methods', fn ($join) => $join->on('methods.id', '=', 'expenses.payment_method_id')->where('methods.tenant_id', $tenantId))
                ->where('expenses.tenant_id', $tenantId)->whereIn('expenses.id', $ids)->whereNull('expenses.deleted_at')
                ->select('expenses.id', 'expenses.expense_number as reference', 'expenses.total_amount as amount', 'expenses.payment_method_id', 'methods.code as payment_method_code', 'methods.name as payment_method_name')->get()->keyBy('id')->all(),
            'cash_transfer' => DB::table('cash_transfers')->where('tenant_id', $tenantId)->whereIn('id', $ids)->select('id', DB::raw("CONCAT('CT-', id) as reference"), 'amount')->get()->keyBy('id')->all(),
            'supplier_invoice' => DB::table('supplier_invoices')->where('tenant_id', $tenantId)->whereIn('id', $ids)->whereNull('deleted_at')->select('id', 'internal_reference as reference', 'total_amount as amount')->get()->keyBy('id')->all(),
            'supplier_payment' => DB::table('supplier_payments as payments')->leftJoin('payment_methods as methods', fn ($join) => $join->on('methods.id', '=', 'payments.payment_method_id')->where('methods.tenant_id', $tenantId))
                ->where('payments.tenant_id', $tenantId)->whereIn('payments.id', $ids)->select('payments.id', 'payments.payment_number as reference', 'payments.amount', 'payments.payment_method_id', 'methods.code as payment_method_code', 'methods.name as payment_method_name')->get()->keyBy('id')->all(),
            'inventory_movement' => DB::table('stock_movements')->where('tenant_id', $tenantId)->whereIn('id', $ids)->select('id', DB::raw("CONCAT('SM-', id) as reference"), 'total_cost as amount')->get()->keyBy('id')->all(),
            'journal_reversal' => DB::table('journal_entries')->where('tenant_id', $tenantId)->whereIn('id', $ids)->select('id', 'entry_number as reference')->get()->keyBy('id')->all(),
            default => [],
        };
    }

    private function serialize(object $entry, ?object $record): array
    {
        $normalized = $this->normalizedType((string) $entry->source_type, $entry->source_event);
        $basis = match ($normalized) {
            'sale' => 'business_total', 'refund' => 'refund_total', 'expense' => 'business_total',
            'cash_transfer', 'supplier_payment' => 'payment_total', 'supplier_invoice' => 'business_total',
            'inventory_waste', 'stock_count_variance' => 'inventory_cost', default => 'journal_total',
        };
        $amount = $record?->amount ?? $entry->total_debit;
        return [
            'source' => ['type' => $entry->source_type, 'normalizedType' => $normalized, 'event' => $entry->source_event, 'id' => $entry->source_id ? (int) $entry->source_id : null, 'reference' => $record?->reference, 'resourceKind' => $this->resourceKind($normalized), 'available' => $record !== null || in_array($normalized, ['manual_journal'], true)],
            'displayAmount' => ['amount' => Money::decimal(Money::cents($amount, 'amount')), 'currency' => 'SYP', 'basis' => $basis],
            'paymentMethod' => ($record?->payment_method_id ?? null) ? ['id' => (int) $record->payment_method_id, 'code' => $record->payment_method_code ?? null, 'name' => $record->payment_method_name ?? null] : null,
        ];
    }

    public function normalizedType(string $type, ?string $event): string
    {
        if ($type === 'inventory_movement') return $event === 'INVENTORY_WASTE' ? 'inventory_waste' : 'stock_count_variance';
        return match ($type) {
            'pos_order' => 'sale', 'payment_refund' => 'refund', 'expense' => 'expense', 'cash_transfer' => 'cash_transfer',
            'supplier_invoice' => 'supplier_invoice', 'supplier_payment' => 'supplier_payment', 'manual' => 'manual_journal',
            'journal_reversal' => 'journal_reversal', default => 'journal',
        };
    }

    private function resourceKind(string $normalized): string
    {
        return match ($normalized) {
            'sale' => 'order', 'refund' => 'refund', 'expense' => 'expense', 'cash_transfer' => 'cash_transfer',
            'supplier_invoice' => 'supplier_invoice', 'supplier_payment' => 'supplier_payment',
            'inventory_waste', 'stock_count_variance' => 'inventory_movement', default => 'journal',
        };
    }
}
