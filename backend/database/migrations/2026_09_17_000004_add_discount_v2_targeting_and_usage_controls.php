<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('discounts', function (Blueprint $table): void {
            $table->unsignedInteger('usage_limit_per_customer_per_day')->nullable()->after('usage_limit_per_customer');
        });

        Schema::create('discount_bundle_requirements', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('discount_id')->constrained();
            // Product identity is configuration, not a historical price source.
            $table->foreignId('product_id')->constrained();
            $table->decimal('quantity', 10, 3);
            $table->timestamps();
            $table->unique(['tenant_id', 'discount_id', 'product_id'], 'discount_bundle_requirement_product_unique');
            $table->index(['tenant_id', 'discount_id']);
        });

        Schema::create('discount_channel_targets', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('discount_id')->constrained();
            $table->string('channel_key');
            $table->timestamps();
            $table->unique(['tenant_id', 'discount_id', 'channel_key'], 'discount_channel_target_unique');
            $table->index(['tenant_id', 'discount_id']);
        });

        Schema::table('orders', function (Blueprint $table): void {
            // An order's origin is immutable transaction context. Legacy POS
            // orders are safely represented by the default as well.
            $table->string('sales_channel')->default('pos')->after('branch_id');
            $table->index(['tenant_id', 'sales_channel']);
        });

        Schema::table('discount_usages', function (Blueprint $table): void {
            // Resolved only at successful payment, in the order branch timezone.
            $table->date('business_date')->nullable()->after('customer_id');
            $table->index(['tenant_id', 'discount_id', 'customer_id', 'business_date'], 'discount_usage_customer_business_day_index');
        });

        // PostgreSQL's expression index is the final authority for both
        // generated and manually supplied coupon codes. The application still
        // gives a friendly validation error, but cannot race this constraint.
        DB::statement('CREATE UNIQUE INDEX discounts_tenant_lower_code_unique ON discounts (tenant_id, LOWER(code)) WHERE code IS NOT NULL AND deleted_at IS NULL');
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS discounts_tenant_lower_code_unique');
        Schema::table('discount_usages', function (Blueprint $table): void {
            $table->dropIndex('discount_usage_customer_business_day_index');
            $table->dropColumn('business_date');
        });
        Schema::table('orders', function (Blueprint $table): void {
            $table->dropIndex(['tenant_id', 'sales_channel']);
            $table->dropColumn('sales_channel');
        });
        Schema::dropIfExists('discount_channel_targets');
        Schema::dropIfExists('discount_bundle_requirements');
        Schema::table('discounts', function (Blueprint $table): void {
            $table->dropColumn('usage_limit_per_customer_per_day');
        });
    }
};
