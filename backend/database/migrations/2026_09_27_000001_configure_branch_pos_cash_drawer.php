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
        Schema::table('branches', function (Blueprint $table): void {
            $table->foreignId('pos_cash_financial_location_id')->nullable()
                ->constrained('financial_locations')->restrictOnDelete();
        });

        $setup = app(FinancialSetupService::class);
        DB::table('branches')->where('is_active', true)->whereNull('deleted_at')
            ->orderBy('id')->get(['id', 'tenant_id'])->each(function (object $branch) use ($setup): void {
                if (! DB::table('financial_accounts')->where('tenant_id', $branch->tenant_id)
                    ->where('code', '1010')->where('is_active', true)->whereNull('deleted_at')->exists()) {
                    // Leave an incomplete tenant for explicit setup instead of aborting all tenants.
                    return;
                }
                $drawers = DB::table('financial_locations')->where('tenant_id', $branch->tenant_id)
                    ->where('branch_id', $branch->id)->where('kind', 'cash')->where('type', 'cash_drawer')->get();
                if ($drawers->where('is_active', true)->count() > 1 || ($drawers->count() > 1 && $drawers->where('is_active', true)->isEmpty())) {
                    // Ambiguous existing configuration needs an authorized user selection.
                    return;
                }
                $setup->ensureBranchCashDrawer((int) $branch->tenant_id, (int) $branch->id);
            });

        // Repair only open null shifts whose branch now has a validated configured drawer.
        DB::table('branches')->whereNotNull('pos_cash_financial_location_id')->get(['id', 'tenant_id', 'pos_cash_financial_location_id'])
            ->each(function (object $branch): void {
                DB::table('shifts')->where('tenant_id', $branch->tenant_id)->where('branch_id', $branch->id)
                    ->where('status', 'open')->whereNull('deleted_at')->whereNull('financial_location_id')
                    ->update(['financial_location_id' => $branch->pos_cash_financial_location_id, 'updated_at' => now()]);
            });
    }

    public function down(): void
    {
        // Existing shifts may still reference the drawers this repaired — that
        // shift data is intentionally left in place. Only undo the schema this
        // migration added, so later migrations' down() can drop
        // `financial_locations` without a dangling FK from `branches`.
        Schema::table('branches', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('pos_cash_financial_location_id');
        });
    }
};
