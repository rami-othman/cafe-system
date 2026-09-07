<?php

namespace App\Services;

use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

final class BusinessDayRangeResolver
{
    /**
     * Per-request memo of branch row + resolved timezone, keyed by
     * "tenantId:branchId". resolve() is called once per (branch, date) pair
     * across dashboard alert/readiness loops — the branch and its timezone
     * never change within a single request, so re-querying it for every date
     * is pure overhead. Safe as a static cache only because the app runs on
     * plain php-fpm (fresh process per request, no Octane/Swoole worker
     * reuse) — revisit if that changes.
     */
    private static array $branchCache = [];

    public function resolve(int $tenantId, int $branchId, string $date): array
    {
        [$branch, $timezone] = $this->branchAndTimezone($tenantId, $branchId);
        $start = CarbonImmutable::parse($date, $timezone)->startOfDay();
        return ['timezone' => $timezone, 'start' => $start->utc(), 'end' => $start->addDay()->utc(), 'date' => $start->toDateString(), 'branch' => $branch];
    }

    private function branchAndTimezone(int $tenantId, int $branchId): array
    {
        $key = $tenantId.':'.$branchId;
        if (! isset(self::$branchCache[$key])) {
            $branch = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->whereNull('deleted_at')->first();
            abort_unless($branch, 404, 'Branch not found.');
            $timezone = $branch->timezone ?: DB::table('tenants')->where('id', $tenantId)->value('timezone') ?: 'UTC';
            self::$branchCache[$key] = [$branch, $timezone];
        }

        return self::$branchCache[$key];
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
