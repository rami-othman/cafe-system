<?php

use App\Services\FinancialSetupService;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Multiple physical drawers may post to the same 1010 ledger account.
        Schema::table('financial_locations', function (Blueprint $table): void {
            $table->dropUnique(['tenant_id', 'financial_account_id']);
            $table->index(['tenant_id', 'financial_account_id']);
        });

        $setup = app(FinancialSetupService::class);
        DB::table('branches')->where('is_active', true)->whereNull('deleted_at')
            ->orderBy('id')->get(['id', 'tenant_id'])->each(function (object $branch) use ($setup): void {
                $setup->ensureBranchCashDrawer((int) $branch->tenant_id, (int) $branch->id);
            });

        // Keep the historical global location and its ID, but let CASH be used
        // with any branch drawer mapped to its ledger account.
        $globalCashMethodIds = DB::table('payment_methods as methods')
            ->join('financial_locations as locations', 'locations.id', '=', 'methods.financial_location_id')
            ->where('methods.code', 'CASH')->where('methods.type', 'cash')
            ->where('locations.code', 'CASH-DRAWER')
            ->pluck('methods.id');
        DB::table('payment_methods')->whereIn('id', $globalCashMethodIds)
            ->update(['financial_location_id' => null, 'updated_at' => now()]);
    }

    public function down(): void
    {
        // Restoring the old uniqueness would reject the branch drawers and
        // would require deleting historical locations. This repair is additive.
    }
};
