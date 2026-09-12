<?php

namespace App\Domain\Customer;

use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;

final class CustomerNumberGenerator
{
    public function next(int $tenantId): string
    {
        DB::table('customer_number_counters')->insertOrIgnore([
            'tenant_id' => $tenantId,
            'next_value' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $counter = DB::table('customer_number_counters')->where('tenant_id', $tenantId)->lockForUpdate()->first();
        if (! $counter) {
            throw new QueryException('pgsql', 'customer number counter', [], new \RuntimeException('Unable to lock customer number counter.'));
        }

        $highWater = DB::table('customers')->where('tenant_id', $tenantId)->pluck('customer_number')
            ->map(fn (?string $number): int => (int) preg_replace('/\D+/', '', (string) $number))->max() ?? 0;
        $sequence = max((int) $counter->next_value, $highWater + 1);
        DB::table('customer_number_counters')->where('id', $counter->id)->update([
            'next_value' => $sequence + 1,
            'updated_at' => now(),
        ]);

        return 'C-'.str_pad((string) $sequence, 6, '0', STR_PAD_LEFT);
    }
}
