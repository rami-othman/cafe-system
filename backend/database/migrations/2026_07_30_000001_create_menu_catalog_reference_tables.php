<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reporting_categories', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->string('name');
            $table->string('name_ar')->nullable();
            $table->string('name_en')->nullable();
            $table->string('code')->nullable();
            $table->text('description')->nullable();
            $table->integer('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();
            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'is_active']);
        });

        Schema::create('kitchen_stations', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->string('name');
            $table->string('name_ar')->nullable();
            $table->string('name_en')->nullable();
            $table->string('code')->nullable();
            $table->string('printer_name')->nullable();
            $table->integer('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->softDeletes();
            $table->index('tenant_id');
            $table->index(['tenant_id', 'branch_id']);
            $table->index(['tenant_id', 'is_active']);
        });

        Schema::table('products', function (Blueprint $table): void {
            $table->string('name_ar')->nullable()->after('name');
            $table->string('name_en')->nullable()->after('name_ar');
            $table->text('description_ar')->nullable()->after('description');
            $table->text('description_en')->nullable()->after('description_ar');
            $table->string('product_type')->default('standard')->after('description_en');
            $table->foreignId('reporting_category_id')->nullable()->after('category_id')->constrained()->nullOnDelete();
            $table->foreignId('kitchen_station_id')->nullable()->after('reporting_category_id')->constrained()->nullOnDelete();
            $table->unsignedSmallInteger('preparation_time_minutes')->nullable()->after('kitchen_station_id');
            $table->index(['tenant_id', 'product_type']);
            $table->index(['tenant_id', 'reporting_category_id']);
            $table->index(['tenant_id', 'kitchen_station_id']);
            $table->index(['tenant_id', 'is_active']);
        });
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table): void {
            $table->dropIndex(['tenant_id', 'product_type']);
            $table->dropIndex(['tenant_id', 'reporting_category_id']);
            $table->dropIndex(['tenant_id', 'kitchen_station_id']);
            $table->dropIndex(['tenant_id', 'is_active']);
            $table->dropConstrainedForeignId('reporting_category_id');
            $table->dropConstrainedForeignId('kitchen_station_id');
            $table->dropColumn(['name_ar', 'name_en', 'description_ar', 'description_en', 'product_type', 'preparation_time_minutes']);
        });
        Schema::dropIfExists('kitchen_stations');
        Schema::dropIfExists('reporting_categories');
    }
};
