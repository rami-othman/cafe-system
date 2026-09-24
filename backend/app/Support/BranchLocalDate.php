<?php

namespace App\Support;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Answers "what calendar date is today for this branch?" using branches.timezone.
 *
 * Storage stays UTC everywhere (config('app.timezone')). This helper is only for
 * deriving business-day defaults (voucher date, payment date, cash/bank "today"
 * metrics) — it never converts stored timestamps.
 */
final class BranchLocalDate
{
    public static function today(?int $branchId): string
    {
        return Carbon::now(self::timezone($branchId))->toDateString();
    }

    /** Falls back to UTC when the branch has no timezone configured. */
    public static function timezone(?int $branchId): string
    {
        if ($branchId === null) {
            return 'UTC';
        }

        $timezone = DB::table('branches')->where('id', $branchId)->value('timezone');

        return $timezone ?: 'UTC';
    }
}
