<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', fn (Blueprint $table) => $table->unique(['id', 'tenant_id'], 'discount_settings_actor_identity'));
        Schema::create('tenant_discount_settings', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->restrictOnDelete();
            $table->unique('tenant_id');
            $table->boolean('automatic_enabled');
            $table->string('selection_strategy', 30);
            $table->string('combination_mode', 30);
            $table->string('order_discount_behavior', 30);
            $table->string('coupon_behavior', 30);
            $table->string('manual_behavior', 30);
            $table->decimal('maximum_total_discount_percent', 7, 4)->nullable();
            $table->boolean('allow_automatic_suppression');
            $table->unsignedInteger('version');
            $table->unsignedBigInteger('updated_by');
            $table->timestamps();
            $table->foreign(['updated_by', 'tenant_id'], 'discount_settings_actor_fk')->references(['id', 'tenant_id'])->on('users')->restrictOnDelete();
        });
        DB::statement("ALTER TABLE tenant_discount_settings ADD CONSTRAINT discount_settings_values_check CHECK (
            version > 0 AND NOT automatic_enabled
            AND selection_strategy IN ('highest_saving','lowest_saving','priority')
            AND combination_mode IN ('single','disjoint_items')
            AND order_discount_behavior IN ('exclusive','after_items')
            AND coupon_behavior IN ('exclusive','follow_combination_rules')
            AND manual_behavior IN ('exclusive','follow_combination_rules')
            AND (maximum_total_discount_percent IS NULL OR (maximum_total_discount_percent > 0 AND maximum_total_discount_percent <= 100))
            AND (order_discount_behavior <> 'after_items' OR combination_mode = 'disjoint_items'))");
        DB::statement('ALTER TABLE discount_role_permissions DROP CONSTRAINT discount_role_permissions_permission_check');
        DB::statement("ALTER TABLE discount_role_permissions ADD CONSTRAINT discount_role_permissions_permission_check CHECK (permission IN ('discounts.view','discounts.manage','discounts.apply_configured','discounts.apply_manual','discounts.settings.manage'))");
        DB::statement("ALTER TABLE discount_role_permissions ADD CONSTRAINT discount_settings_manager_only CHECK (permission <> 'discounts.settings.manage' OR role = 'manager')");
        Schema::table('tenant_roles', fn (Blueprint $table) => $table->boolean('discount_settings_grant_initialized')->default(false));
        // This new permission had no pre-upgrade grants or revocations. Existing
        // permissions are untouched. Mark initialization so later revocations stay.
        DB::table('tenant_roles')->where('code', 'manager')->orderBy('id')->each(function (object $role): void {
            DB::table('discount_role_permissions')->insertOrIgnore([
                'tenant_id' => $role->tenant_id, 'role' => 'manager', 'permission' => 'discounts.settings.manage',
                'created_at' => now(), 'updated_at' => now(),
            ]);
            DB::table('tenant_roles')->where('id', $role->id)->update(['discount_settings_grant_initialized' => true]);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tenant_discount_settings');
        Schema::table('users', fn (Blueprint $table) => $table->dropUnique('discount_settings_actor_identity'));
        DB::table('discount_role_permissions')->where('permission', 'discounts.settings.manage')->delete();
        DB::statement('ALTER TABLE discount_role_permissions DROP CONSTRAINT discount_settings_manager_only');
        DB::statement('ALTER TABLE discount_role_permissions DROP CONSTRAINT discount_role_permissions_permission_check');
        DB::statement("ALTER TABLE discount_role_permissions ADD CONSTRAINT discount_role_permissions_permission_check CHECK (permission IN ('discounts.view','discounts.manage','discounts.apply_configured','discounts.apply_manual'))");
        Schema::table('tenant_roles', fn (Blueprint $table) => $table->dropColumn('discount_settings_grant_initialized'));
    }
};
