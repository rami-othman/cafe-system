<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('bar_check_templates', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->constrained();
            $table->foreignId('warehouse_id')->constrained();
            $table->string('name');
            $table->boolean('is_active')->default(true);
            $table->boolean('required_for_shift_close')->default(false);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->index(['tenant_id', 'warehouse_id', 'is_active']);
        });

        Schema::create('bar_check_template_lines', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('bar_check_template_id')->constrained()->cascadeOnDelete();
            $table->foreignId('inventory_item_id')->constrained();
            $table->string('count_unit');
            $table->boolean('is_required')->default(true);
            $table->decimal('quantity_tolerance', 15, 3)->default(0);
            $table->decimal('manager_review_threshold', 15, 3)->nullable();
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
            $table->unique(['bar_check_template_id', 'inventory_item_id'], 'bar_check_template_item_unique');
        });

        Schema::table('stock_counts', function (Blueprint $table): void {
            $table->foreignId('branch_id')->nullable()->after('warehouse_id')->constrained()->nullOnDelete();
            $table->foreignId('shift_id')->nullable()->after('warehouse_id')->constrained()->nullOnDelete();
            $table->foreignId('bar_check_template_id')->nullable()->after('shift_id')->constrained('bar_check_templates')->nullOnDelete();
            $table->index(['tenant_id', 'shift_id', 'count_type']);
        });

        Schema::table('stock_count_lines', function (Blueprint $table): void {
            $table->boolean('is_required')->default(true)->after('inventory_item_id');
            $table->decimal('quantity_tolerance', 15, 3)->default(0)->after('variance_quantity');
            $table->decimal('manager_review_threshold', 15, 3)->nullable()->after('quantity_tolerance');
            $table->string('variance_status')->nullable()->after('manager_review_threshold');
            $table->foreignId('reason_entered_by')->nullable()->constrained('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('stock_count_lines', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('reason_entered_by');
            $table->dropColumn(['is_required', 'quantity_tolerance', 'manager_review_threshold', 'variance_status']);
        });
        Schema::table('stock_counts', function (Blueprint $table): void {
            $table->dropIndex(['tenant_id', 'shift_id', 'count_type']);
            $table->dropConstrainedForeignId('bar_check_template_id');
            $table->dropConstrainedForeignId('shift_id');
            $table->dropConstrainedForeignId('branch_id');
        });
        Schema::dropIfExists('bar_check_template_lines');
        Schema::dropIfExists('bar_check_templates');
    }
};
