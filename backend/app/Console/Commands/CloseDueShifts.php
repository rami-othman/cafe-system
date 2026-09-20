<?php

namespace App\Console\Commands;

use App\Services\AutomaticShiftCloseService;
use Carbon\CarbonImmutable;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

final class CloseDueShifts extends Command
{
    protected $signature = 'shifts:close-due';
    protected $description = 'Close shifts due at their branch end of day time';

    public function handle(AutomaticShiftCloseService $closer): int
    {
        $rows = DB::table('shifts as s')->join('branches as b', 'b.id', '=', 's.branch_id')
            ->where('s.status', 'open')->whereNull('s.deleted_at')->whereNotNull('b.shift_close_time')
            ->select('s.id', 's.tenant_id', 's.opened_at', 'b.timezone', 'b.shift_close_time')->get();
        foreach ($rows as $row) {
            $local = CarbonImmutable::now($row->timezone ?: 'UTC');
            $opened = CarbonImmutable::parse($row->opened_at, 'UTC')->setTimezone($row->timezone ?: 'UTC');
            $due = $opened->setTimeFromTimeString($row->shift_close_time);
            if ($due->lessThanOrEqualTo($opened)) $due = $due->addDay();
            if ($local->lessThan($due)) continue;
            try { $closer->close((int) $row->tenant_id, (int) $row->id); }
            catch (\Throwable $e) {
                Log::warning('Automatic shift close blocked', ['shift_id' => $row->id, 'error' => $e->getMessage()]);
                $this->warn("Shift {$row->id}: {$e->getMessage()}");
            }
        }
        return self::SUCCESS;
    }
}
