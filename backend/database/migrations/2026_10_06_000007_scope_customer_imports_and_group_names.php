<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::table('customer_imports', fn (Blueprint $t) => $t->foreignId('owner_branch_id')->nullable()->constrained('branches')->restrictOnDelete());
        Schema::table('customer_groups', fn (Blueprint $t) => $t->dropUnique('customer_groups_tenant_normalized_name_unique'));
        DB::statement('CREATE UNIQUE INDEX customer_groups_cafe_name_unique ON customer_groups (tenant_id, normalized_name) WHERE owner_branch_id IS NULL');
        DB::statement('CREATE UNIQUE INDEX customer_groups_factory_name_unique ON customer_groups (tenant_id, owner_branch_id, normalized_name) WHERE owner_branch_id IS NOT NULL');
    }
    public function down(): void {
        if (DB::table('customer_groups')->select('tenant_id', 'normalized_name')->groupBy('tenant_id', 'normalized_name')->havingRaw('COUNT(*) > 1')->exists()) throw new RuntimeException('Scoped group names need manual resolution before rollback; no data was deleted.');
        DB::statement('DROP INDEX customer_groups_cafe_name_unique'); DB::statement('DROP INDEX customer_groups_factory_name_unique');
        Schema::table('customer_groups', fn (Blueprint $t) => $t->unique(['tenant_id', 'normalized_name'], 'customer_groups_tenant_normalized_name_unique'));
        Schema::table('customer_imports', function (Blueprint $t) { $t->dropForeign(['owner_branch_id']); $t->dropColumn('owner_branch_id'); });
    }
};
