<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('menu_price_adjustment_items', function (Blueprint $table): void {
            $table->foreignId('product_id')->nullable()->after('product_variant_id')->constrained()->nullOnDelete();
            $table->string('product_name')->nullable()->after('product_id');
            $table->string('product_name_ar')->nullable()->after('product_name');
            $table->string('product_name_en')->nullable()->after('product_name_ar');
            $table->string('variant_name')->nullable()->after('product_name_en');
            $table->string('variant_name_ar')->nullable()->after('variant_name');
            $table->string('variant_name_en')->nullable()->after('variant_name_ar');
            $table->boolean('is_default')->nullable()->after('variant_name_en');
        });
    }

    public function down(): void
    {
        Schema::table('menu_price_adjustment_items', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('product_id');
            $table->dropColumn(['product_name', 'product_name_ar', 'product_name_en', 'variant_name', 'variant_name_ar', 'variant_name_en', 'is_default']);
        });
    }
};
