<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->foreignId('warehouse_id')->nullable()->after('branch_id')
                ->constrained('warehouses')->restrictOnDelete();
            $table->index(['tenant_id', 'branch_id', 'warehouse_id']);
        });
        Schema::table('branches', function (Blueprint $table): void {
            $table->foreignId('pos_inventory_warehouse_id')->nullable()->after('tenant_id')
                ->constrained('warehouses')->nullOnDelete();
        });

        DB::table('branches')->whereNull('deleted_at')->orderBy('id')->get(['id', 'tenant_id'])->each(function (object $branch): void {
            $bars = DB::table('warehouses')->where('tenant_id', $branch->tenant_id)->where('branch_id', $branch->id)
                ->where('type', 'bar')->where('is_active', true)->whereNull('deleted_at')->pluck('id');
            if ($bars->count() === 1) {
                DB::table('branches')->where('id', $branch->id)->update(['pos_inventory_warehouse_id' => $bars->first()]);
            }
        });
    }

    public function down(): void
    {
        Schema::table('branches', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('pos_inventory_warehouse_id');
        });
        Schema::table('orders', function (Blueprint $table): void {
            $table->dropIndex(['tenant_id', 'branch_id', 'warehouse_id']);
            $table->dropConstrainedForeignId('warehouse_id');
        });
    }
};
