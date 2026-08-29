<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('menus', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->string('name');
            $table->string('name_ar')->nullable();
            $table->string('name_en')->nullable();
            $table->text('description')->nullable();
            $table->text('description_ar')->nullable();
            $table->text('description_en')->nullable();
            $table->string('cover_image_url')->nullable();
            $table->string('status')->default('draft');
            $table->integer('priority')->default(0);
            $table->timestamps();
            $table->softDeletes();
            $table->index(['tenant_id', 'status']);
            $table->index(['tenant_id', 'priority']);
        });
        Schema::create('menu_sections', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('menu_id')->constrained();
            $table->string('name');
            $table->string('name_ar')->nullable();
            $table->string('name_en')->nullable();
            $table->text('description')->nullable();
            $table->string('image_url')->nullable();
            $table->integer('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();
            $table->index(['tenant_id', 'menu_id']);
            $table->index(['tenant_id', 'menu_id', 'is_active']);
            $table->index(['tenant_id', 'menu_id', 'sort_order']);
        });
        Schema::create('menu_item_placements', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('menu_section_id')->constrained();
            $table->foreignId('product_id')->constrained();
            $table->string('display_name_override')->nullable();
            $table->text('display_description_override')->nullable();
            $table->string('display_image_override')->nullable();
            $table->integer('sort_order')->default(0);
            $table->boolean('is_featured')->default(false);
            $table->boolean('is_visible')->default(true);
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['tenant_id', 'menu_section_id', 'product_id']);
            $table->index(['tenant_id', 'menu_section_id', 'sort_order']);
            $table->index(['tenant_id', 'product_id']);
            $table->index(['tenant_id', 'is_visible']);
        });
        Schema::create('menu_assignments', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('menu_id')->constrained();
            $table->foreignId('branch_id')->constrained();
            $table->string('channel');
            $table->integer('priority')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->unique(['tenant_id', 'menu_id', 'branch_id', 'channel']);
            $table->index(['tenant_id', 'branch_id', 'channel']);
            $table->index(['tenant_id', 'menu_id']);
        });
        Schema::create('product_variant_price_overrides', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('product_variant_id')->constrained();
            $table->string('scope_type');
            $table->string('scope_key');
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->string('channel')->nullable();
            $table->decimal('override_price', 12, 2);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['tenant_id', 'product_variant_id', 'scope_key']);
            $table->index(['tenant_id', 'product_variant_id']);
            $table->index(['tenant_id', 'branch_id']);
            $table->index(['tenant_id', 'channel']);
            $table->index(['tenant_id', 'is_active']);
        });
        Schema::create('menu_availability_rules', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('menu_id')->constrained();
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->string('channel')->nullable();
            $table->unsignedTinyInteger('day_of_week')->nullable();
            $table->time('start_time')->nullable();
            $table->time('end_time')->nullable();
            $table->date('start_date')->nullable();
            $table->date('end_date')->nullable();
            $table->integer('priority')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();
            $table->index(['tenant_id', 'menu_id']);
            $table->index(['tenant_id', 'branch_id', 'channel']);
            $table->index(['tenant_id', 'is_active']);
        });
        Schema::create('product_availability_rules', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('product_id')->constrained();
            $table->foreignId('product_variant_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->string('channel')->nullable();
            $table->unsignedTinyInteger('day_of_week')->nullable();
            $table->time('start_time')->nullable();
            $table->time('end_time')->nullable();
            $table->date('start_date')->nullable();
            $table->date('end_date')->nullable();
            $table->integer('priority')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();
            $table->index(['tenant_id', 'product_id']);
            $table->index(['tenant_id', 'branch_id', 'channel']);
            $table->index(['tenant_id', 'is_active']);
        });
        $this->createOperationalAvailability('product_operational_availabilities', 'product_id', 'products');
        $this->createOperationalAvailability('product_variant_operational_availabilities', 'product_variant_id', 'product_variants');
    }

    private function createOperationalAvailability(string $tableName, string $subjectColumn, string $subjectTable): void
    {
        $prefix = $subjectColumn === 'product_variant_id' ? 'pvoa' : 'poa';

        Schema::create($tableName, function (Blueprint $table) use ($subjectColumn, $subjectTable, $prefix): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId($subjectColumn)->constrained($subjectTable);
            $table->foreignId('branch_id')->constrained();
            $table->string('channel')->default('all');
            $table->string('status')->default('available');
            $table->decimal('remaining_quantity', 10, 3)->nullable();
            $table->timestamp('unavailable_until')->nullable();
            $table->text('reason')->nullable();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['tenant_id', $subjectColumn, 'branch_id', 'channel'], $prefix.'_scope_unique');
            $table->index(['tenant_id', 'branch_id', 'channel', 'status'], $prefix.'_branch_channel_status_index');
            $table->index(['tenant_id', $subjectColumn], $prefix.'_subject_index');
        });
    }

    public function down(): void
    {
        foreach (['product_variant_operational_availabilities', 'product_operational_availabilities', 'product_availability_rules', 'menu_availability_rules', 'product_variant_price_overrides', 'menu_assignments', 'menu_item_placements', 'menu_sections', 'menus'] as $table) {
            Schema::dropIfExists($table);
        }
    }
};
