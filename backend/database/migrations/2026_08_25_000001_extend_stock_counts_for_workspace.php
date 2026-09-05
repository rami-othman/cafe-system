<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('stock_counts', function (Blueprint $table): void {
            $table->string('count_type')->default('full')->after('count_date');
            $table->json('category_filters')->nullable()->after('count_type');
            $table->index(['tenant_id', 'status', 'count_date']);
        });

        Schema::table('stock_count_lines', function (Blueprint $table): void {
            $table->decimal('average_unit_cost', 15, 4)->default(0)->after('variance_quantity');
            $table->timestamp('counted_at')->nullable()->after('average_unit_cost');
        });

        DB::table('stock_count_lines')->whereNull('counted_at')->update([
            'counted_at' => DB::raw('created_at'),
        ]);
    }

    public function down(): void
    {
        Schema::table('stock_count_lines', function (Blueprint $table): void {
            $table->dropColumn(['average_unit_cost', 'counted_at']);
        });
        Schema::table('stock_counts', function (Blueprint $table): void {
            $table->dropIndex(['tenant_id', 'status', 'count_date']);
            $table->dropColumn(['count_type', 'category_filters']);
        });
    }
};
