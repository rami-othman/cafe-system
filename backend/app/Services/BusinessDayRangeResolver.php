<?php

namespace App\Services;

use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

final class BusinessDayRangeResolver
{
    public function resolve(int $tenantId, int $branchId, string $date): array
    {
        $branch = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->whereNull('deleted_at')->first(); abort_unless($branch, 404, 'Branch not found.');
        $timezone = $branch->timezone ?: DB::table('tenants')->where('id', $tenantId)->value('timezone') ?: 'UTC';
        $start = CarbonImmutable::parse($date, $timezone)->startOfDay();
        return ['timezone' => $timezone, 'start' => $start->utc(), 'end' => $start->addDay()->utc(), 'date' => $start->toDateString(), 'branch' => $branch];
    }

    /**
     * The same local-day-to-UTC conversion as resolve(), generalized to an
     * inclusive multi-day [dateFrom, dateTo] range for a known timezone
     * (used where the caller already resolved timezone across several
     * branches, e.g. a tenant-wide Dashboard query, so no single branch
     * lookup applies).
     */
    public static function utcRangeForTimezone(string $timezone, string $dateFrom, string $dateTo): array
    {
        $start = CarbonImmutable::parse($dateFrom, $timezone)->startOfDay();
        $end = CarbonImmutable::parse($dateTo, $timezone)->startOfDay()->addDay();

        return ['timezone' => $timezone, 'start' => $start->utc(), 'end' => $end->utc()];
    }
}
