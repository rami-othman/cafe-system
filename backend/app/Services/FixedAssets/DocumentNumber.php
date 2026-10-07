<?php

namespace App\Services\FixedAssets;

use Illuminate\Support\Facades\DB;

/** Sequential per-tenant numbers (DEP-000001, PD-000001 …). Call inside a transaction. */
final class DocumentNumber
{
    public static function next(int $tenantId, string $table, string $column, string $prefix): string
    {
        DB::table('tenants')->where('id', $tenantId)->lockForUpdate()->first();
        $max = 0;
        foreach (DB::table($table)->where('tenant_id', $tenantId)->where($column, 'like', $prefix.'%')->pluck($column) as $value) {
            $n = (int) substr((string) $value, strlen($prefix));
            $max = max($max, $n);
        }

        return $prefix.str_pad((string) ($max + 1), 6, '0', STR_PAD_LEFT);
    }
}
