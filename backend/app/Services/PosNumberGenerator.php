<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

class PosNumberGenerator
{
    public function nextOrderNumber(int $tenantId, int $branchId): string
    {
        $sequence = $this->next($tenantId, 'order', $branchId);

        return now()->format('Ymd').'-'.str_pad((string) $sequence, 4, '0', STR_PAD_LEFT);
    }

    public function nextRefundNumber(int $tenantId): string
    {
        $sequence = $this->next($tenantId, 'refund', 0);

        return 'RF-'.now()->format('Ymd').'-'.str_pad((string) $sequence, 4, '0', STR_PAD_LEFT);
    }

    private function next(int $tenantId, string $kind, int $branchScopeId): int
    {
        // Historical counters are initialized by the Hardening A migration.
        // insertOrIgnore lets concurrent first use for a new scope converge on
        // one lockable row without deriving a number from table cardinality.
        DB::table('pos_number_counters')->insertOrIgnore([
            'tenant_id' => $tenantId,
            'kind' => $kind,
            'branch_scope_id' => $branchScopeId,
            'next_value' => 0,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $counter = DB::table('pos_number_counters')
            ->where('tenant_id', $tenantId)
            ->where('kind', $kind)
            ->where('branch_scope_id', $branchScopeId)
            ->lockForUpdate()
            ->first();

        $current = (int) $counter->next_value;
        if ($current === 0) {
            // Seed/import paths can create historical rows after the migration.
            // This fallback runs only while the counter row is locked and uses a
            // formatted-number high-water mark, never table cardinality.
            $current = $this->formattedHighWaterMark($tenantId, $kind, $branchScopeId);
        }
        $next = $current + 1;
        DB::table('pos_number_counters')->where('id', $counter->id)->update([
            'next_value' => $next,
            'updated_at' => now(),
        ]);

        return $next;
    }

    private function formattedHighWaterMark(int $tenantId, string $kind, int $branchScopeId): int
    {
        $table = $kind === 'order' ? 'orders' : 'payment_refunds';
        $prefix = $kind === 'order' ? now()->format('Ymd').'-' : 'RF-'.now()->format('Ymd').'-';
        $numberColumn = $kind === 'order' ? 'order_number' : 'refund_number';
        $query = DB::table($table)->where('tenant_id', $tenantId)->where($numberColumn, 'like', $prefix.'%');
        if ($kind === 'order') {
            $query->where('branch_id', $branchScopeId);
        }
        $number = (string) $query->orderByDesc($numberColumn)->value($numberColumn);

        return preg_match('/(\d+)$/', $number, $matches) === 1 ? (int) $matches[1] : 0;
    }
}
