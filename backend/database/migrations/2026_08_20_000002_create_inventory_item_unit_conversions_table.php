<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inventory_item_unit_conversions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('inventory_item_id')->constrained();
            $table->string('source_unit', 40);
            $table->string('target_unit', 40);
            $table->decimal('factor', 18, 6);
            $table->boolean('is_active')->default(true);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->unique(
                ['tenant_id', 'inventory_item_id', 'source_unit', 'target_unit'],
                'inventory_item_unit_conversions_scope_unique',
            );
            $table->index(['tenant_id', 'inventory_item_id', 'is_active']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('inventory_item_unit_conversions');
    }
};
