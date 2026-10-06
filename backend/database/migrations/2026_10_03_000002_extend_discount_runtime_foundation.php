<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        foreach (['orders', 'discounts', 'payments'] as $tableName) {
            Schema::table($tableName, fn (Blueprint $table) => $table->unique(['id', 'tenant_id'], $tableName.'_discount_identity'));
        }
        Schema::table('order_items', fn (Blueprint $table) => $table->unique(['id', 'tenant_id', 'order_id'], 'discount_item_order_identity'));
        Schema::table('order_discounts', function (Blueprint $table): void {
            $table->unique(['id', 'tenant_id', 'order_id'], 'applied_discount_order_identity');
            $table->string('source', 30)->nullable();
            $table->string('stage', 30)->nullable();
            $table->unsignedInteger('settings_version')->nullable();
            $table->jsonb('calculation_metadata')->nullable();
            $table->jsonb('policy_snapshot')->nullable();
            $table->foreign(['order_id', 'tenant_id'], 'applied_discount_order_fk')->references(['id', 'tenant_id'])->on('orders')->restrictOnDelete();
            $table->foreign(['discount_id', 'tenant_id'], 'applied_discount_policy_fk')->references(['id', 'tenant_id'])->on('discounts')->restrictOnDelete();
        });
        DB::statement("ALTER TABLE order_discounts ADD CONSTRAINT applied_discount_metadata_check CHECK ((source IS NULL OR source IN ('automatic','configured_manual','code','ad_hoc')) AND (stage IS NULL OR stage IN ('items','order')) AND (settings_version IS NULL OR settings_version >= 0))");
        Schema::table('discount_usages', function (Blueprint $table): void {
            $table->dropUnique('discount_usages_order_id_unique');
            $table->unique(['tenant_id', 'order_id', 'discount_id'], 'discount_usage_policy_unique');
            $table->foreign(['order_id', 'tenant_id'], 'discount_usage_order_fk')->references(['id', 'tenant_id'])->on('orders')->restrictOnDelete();
            $table->foreign(['discount_id', 'tenant_id'], 'discount_usage_policy_fk')->references(['id', 'tenant_id'])->on('discounts')->restrictOnDelete();
            $table->foreign(['payment_id', 'tenant_id'], 'discount_usage_payment_fk')->references(['id', 'tenant_id'])->on('payments')->restrictOnDelete();
        });
        Schema::create('order_discount_allocations', function (Blueprint $table): void {
            $table->id();
            $table->unsignedBigInteger('tenant_id');
            $table->unsignedBigInteger('order_id');
            $table->unsignedBigInteger('order_discount_id');
            $table->unsignedBigInteger('order_item_id');
            $table->decimal('amount', 12, 2);
            $table->timestamps();
            $table->unique(['tenant_id', 'order_discount_id', 'order_item_id'], 'discount_allocation_unique');
            $table->foreign(['order_discount_id', 'tenant_id', 'order_id'], 'discount_allocation_applied_fk')->references(['id', 'tenant_id', 'order_id'])->on('order_discounts')->cascadeOnDelete();
            $table->foreign(['order_item_id', 'tenant_id', 'order_id'], 'discount_allocation_item_fk')->references(['id', 'tenant_id', 'order_id'])->on('order_items')->restrictOnDelete();
        });
        DB::statement('ALTER TABLE order_discount_allocations ADD CONSTRAINT discount_allocation_amount_check CHECK (amount >= 0)');
        Schema::create('order_discount_suppressions', function (Blueprint $table): void {
            $table->id();
            $table->unsignedBigInteger('tenant_id');
            $table->unsignedBigInteger('order_id');
            $table->unsignedBigInteger('discount_id');
            $table->unsignedBigInteger('suppressed_by');
            $table->string('reason', 500);
            $table->timestamps();
            $table->unique(['tenant_id', 'order_id', 'discount_id'], 'discount_suppression_unique');
            $table->foreign(['order_id', 'tenant_id'], 'discount_suppression_order_fk')->references(['id', 'tenant_id'])->on('orders')->restrictOnDelete();
            $table->foreign(['discount_id', 'tenant_id'], 'discount_suppression_policy_fk')->references(['id', 'tenant_id'])->on('discounts')->restrictOnDelete();
            $table->foreign(['suppressed_by', 'tenant_id'], 'discount_suppression_actor_fk')->references(['id', 'tenant_id'])->on('users')->restrictOnDelete();
        });
        DB::statement('ALTER TABLE order_discount_suppressions ADD CONSTRAINT discount_suppression_reason_check CHECK (length(btrim(reason)) > 0)');
    }

    public function down(): void
    {
        // Fail before destructive changes if future multi-policy usage exists.
        if (DB::table('discount_usages')->select('order_id')->groupBy('order_id')->havingRaw('count(*) > 1')->exists()) {
            throw new RuntimeException('Multi-policy usage exists; roll forward instead of restoring order uniqueness.');
        }
        Schema::dropIfExists('order_discount_suppressions');
        Schema::dropIfExists('order_discount_allocations');
        Schema::table('discount_usages', function (Blueprint $table): void {
            foreach (['discount_usage_order_fk', 'discount_usage_policy_fk', 'discount_usage_payment_fk'] as $key) {
                $table->dropForeign($key);
            }
            $table->dropUnique('discount_usage_policy_unique');
            $table->unique('order_id');
        });
        DB::statement('ALTER TABLE order_discounts DROP CONSTRAINT applied_discount_metadata_check');
        Schema::table('order_discounts', function (Blueprint $table): void {
            $table->dropForeign('applied_discount_order_fk');
            $table->dropForeign('applied_discount_policy_fk');
            $table->dropUnique('applied_discount_order_identity');
            $table->dropColumn(['source', 'stage', 'settings_version', 'calculation_metadata', 'policy_snapshot']);
        });
        Schema::table('order_items', fn (Blueprint $table) => $table->dropUnique('discount_item_order_identity'));
        foreach (['payments', 'discounts', 'orders'] as $tableName) {
            Schema::table($tableName, fn (Blueprint $table) => $table->dropUnique($tableName.'_discount_identity'));
        }
    }
};
