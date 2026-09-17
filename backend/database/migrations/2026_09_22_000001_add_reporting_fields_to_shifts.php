<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('shifts', function (Blueprint $table): void {
            $table->string('shift_number', 32)->nullable()->after('id');
            $table->string('report_number', 32)->nullable()->after('shift_number');
            $table->string('cash_difference_reason', 32)->nullable()->after('cash_difference');
            $table->text('cash_difference_reason_detail')->nullable()->after('cash_difference_reason');
        });

        $this->backfillShiftNumbers();

        Schema::table('shifts', function (Blueprint $table): void {
            $table->unique(['tenant_id', 'shift_number'], 'shifts_tenant_shift_number_unique');
        });
    }

    public function down(): void
    {
        Schema::table('shifts', function (Blueprint $table): void {
            $table->dropUnique('shifts_tenant_shift_number_unique');
            $table->dropColumn(['shift_number', 'report_number', 'cash_difference_reason', 'cash_difference_reason_detail']);
        });
    }

    private function backfillShiftNumbers(): void
    {
        $shifts = DB::table('shifts')->orderBy('opened_at')->orderBy('id')->get(['id', 'tenant_id', 'branch_id', 'opened_at']);

        // Keyed by tenant+day only (not branch): shift_number is unique per
        // tenant, so branches sharing a tenant must not both mint "-001".
        $sequenceByTenantDay = [];

        foreach ($shifts as $shift) {
            $day = $shift->opened_at ? substr((string) $shift->opened_at, 0, 10) : now()->toDateString();
            $key = $shift->tenant_id.'|'.$day;
            $sequenceByTenantDay[$key] = ($sequenceByTenantDay[$key] ?? 0) + 1;

            $shiftNumber = sprintf('SH-%s-%03d', str_replace('-', '', $day), $sequenceByTenantDay[$key]);

            DB::table('shifts')->where('id', $shift->id)->update(['shift_number' => $shiftNumber]);
        }
    }
};
