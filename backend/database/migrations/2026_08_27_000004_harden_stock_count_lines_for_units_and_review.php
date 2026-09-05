<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('stock_count_lines', function (Blueprint $table): void {
            // counted_quantity is historical and non-nullable in deployed databases.
            // is_counted distinguishes a real zero count from a line not counted yet.
            $table->boolean('is_counted')->default(false)->after('is_required');
            $table->decimal('entered_quantity', 15, 3)->nullable()->after('counted_quantity');
            $table->string('entered_unit', 40)->nullable()->after('entered_quantity');
            $table->decimal('conversion_factor', 18, 6)->nullable()->after('entered_unit');
            $table->decimal('base_quantity', 15, 3)->nullable()->after('conversion_factor');
            $table->string('tolerance_type', 20)->default('quantity')->after('quantity_tolerance');
            $table->boolean('requires_review_when_exceeded')->default(false)->after('manager_review_threshold');
            $table->string('manager_review_status', 20)->nullable()->after('variance_status');
            $table->foreignId('manager_reviewed_by')->nullable()->after('manager_review_status')->constrained('users')->nullOnDelete();
            $table->timestamp('manager_reviewed_at')->nullable()->after('manager_reviewed_by');
            $table->string('manager_review_notes', 1000)->nullable()->after('manager_reviewed_at');
            $table->index(['stock_count_id', 'is_counted'], 'stock_count_lines_counted_index');
        });
    }

    public function down(): void
    {
        Schema::table('stock_count_lines', function (Blueprint $table): void {
            $table->dropIndex('stock_count_lines_counted_index');
            $table->dropConstrainedForeignId('manager_reviewed_by');
            $table->dropColumn([
                'is_counted', 'entered_quantity', 'entered_unit', 'conversion_factor',
                'base_quantity', 'tolerance_type', 'requires_review_when_exceeded',
                'manager_review_status', 'manager_reviewed_at', 'manager_review_notes',
            ]);
        });
    }
};
