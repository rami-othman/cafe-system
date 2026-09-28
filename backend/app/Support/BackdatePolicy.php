<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Client decision 2026-09-28 (T7): any invoice/return may be backdated, provided a reason is recorded. */
final class BackdatePolicy
{
    /** Returns the trimmed reason, or null when the document date is not backdated. Throws when backdated without a reason. */
    public static function reason(?int $branchId, string $documentDate, ?string $reason, string $field = 'backdateReason'): ?string
    {
        if ($documentDate >= BranchLocalDate::today($branchId)) {
            return null;
        }
        $reason = trim((string) $reason);
        if (mb_strlen($reason) < 3) {
            throw ValidationException::withMessages([$field => 'تاريخ المستند سابق لليوم. اكتب سبب التاريخ السابق.']);
        }

        return $reason;
    }

    /** A non-blocking warning when the document date falls on an already-closed daily closing. */
    public static function closedDayWarning(int $tenantId, ?int $branchId, string $date): ?array
    {
        if (! $branchId) {
            return null;
        }
        $closed = DB::table('daily_closings')->where('tenant_id', $tenantId)->where('branch_id', $branchId)
            ->whereDate('business_date', $date)->where('status', 'closed')->exists();

        return $closed ? [
            'code' => 'DAY_ALREADY_CLOSED',
            'date' => $date,
            'message' => "تم الترحيل بتاريخ يوم مُغلق ({$date}). ستظهر كحركة بعد الإغلاق في تقرير ذلك اليوم.",
        ] : null;
    }
}
