<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::table('branches', fn (Blueprint $t) => $t->foreignId('default_warehouse_id')->nullable()->constrained('warehouses')->restrictOnDelete());
        Schema::create('factory_warehouse_migration_snapshots', function (Blueprint $t) { $t->unsignedBigInteger('warehouse_id')->primary(); $t->string('previous_type'); });
        DB::statement('UPDATE branches SET default_warehouse_id = pos_inventory_warehouse_id');
        $ids = DB::table('branches')->where('branch_type', 'factory')->pluck('id');
        foreach (DB::table('warehouses')->whereIn('branch_id', $ids)->get(['id', 'type']) as $w) DB::table('factory_warehouse_migration_snapshots')->insert(['warehouse_id' => $w->id, 'previous_type' => $w->type]);
        DB::table('warehouses')->whereIn('branch_id', $ids)->update(['type' => 'factory']);
        DB::table('branches')->whereIn('id', $ids)->update(['pos_inventory_warehouse_id' => null]);
    }
    public function down(): void {
        DB::statement("UPDATE branches SET pos_inventory_warehouse_id = default_warehouse_id WHERE branch_type = 'factory'");
        foreach (DB::table('factory_warehouse_migration_snapshots')->get() as $w) DB::table('warehouses')->where('id', $w->warehouse_id)->update(['type' => $w->previous_type]);
        Schema::drop('factory_warehouse_migration_snapshots');
        Schema::table('branches', function (Blueprint $t) { $t->dropForeign(['default_warehouse_id']); $t->dropColumn('default_warehouse_id'); });
    }
};
