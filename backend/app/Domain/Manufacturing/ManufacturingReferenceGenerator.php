<?php

namespace App\Domain\Manufacturing;

use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;

/**
 * Safe, concurrency-proof reference numbering — copies CustomerNumberGenerator's
 * row-lock pattern (not SalesInvoiceService's count-based one, which is fragile
 * under soft deletes/gaps). Callers must invoke this inside their own
 * DB::transaction(); the row lock on the counter is what makes it safe.
 *
 * Produces PR-YYYYMMDD-000001 (production) / CV-YYYYMMDD-000001 (conversion),
 * matching the frontend's reference format, generated only by the backend —
 * never trust a frontend-supplied reference.
 */
final class ManufacturingReferenceGenerator
{
    public function next(int $tenantId, string $prefix): string
    {
        $today = now()->toDateString();

        DB::table('manufacturing_reference_counters')->insertOrIgnore([
            'tenant_id' => $tenantId, 'prefix' => $prefix, 'date_bucket' => $today,
            'next_value' => 1, 'created_at' => now(), 'updated_at' => now(),
        ]);

        $counter = DB::table('manufacturing_reference_counters')
            ->where('tenant_id', $tenantId)->where('prefix', $prefix)->where('date_bucket', $today)
            ->lockForUpdate()->first();
        if (! $counter) {
            throw new QueryException('pgsql', 'manufacturing reference counter', [], new \RuntimeException('Unable to lock manufacturing reference counter.'));
        }

        $sequence = (int) $counter->next_value;
        DB::table('manufacturing_reference_counters')->where('id', $counter->id)->update([
            'next_value' => $sequence + 1, 'updated_at' => now(),
        ]);

        return $prefix.'-'.str_replace('-', '', $today).'-'.str_pad((string) $sequence, 6, '0', STR_PAD_LEFT);
    }
}
