<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('discounts', fn (Blueprint $table) => $table->integer('priority')->default(0));
        DB::statement('ALTER TABLE discounts ADD CONSTRAINT discount_priority_check CHECK (priority BETWEEN 0 AND 1000)');
        DB::statement("ALTER TABLE discounts ADD CONSTRAINT discount_automatic_code_check CHECK (application_mode <> 'automatic' OR code IS NULL)");
        Schema::create('order_discount_intents', function (Blueprint $table): void {
            $table->id();
            $table->unsignedBigInteger('tenant_id');
            $table->unsignedBigInteger('order_id');
            $table->jsonb('intent');
            $table->timestamps();
            $table->unique(['tenant_id', 'order_id']);
            $table->foreign(['order_id', 'tenant_id'])->references(['id', 'tenant_id'])->on('orders')->restrictOnDelete();
        });
        foreach (['discount_reviews', 'discount_operations', 'discount_payment_quotes'] as $name) {
            Schema::create($name, function (Blueprint $table) use ($name): void {
                $table->id();
                $table->unsignedBigInteger('tenant_id');
                $table->unsignedBigInteger('order_id');
                $table->string('identity', 120);
                $table->string('fingerprint', 64);
                $table->jsonb('payload');
                $table->jsonb('result');
                $table->timestamps();
                $table->unique(['tenant_id', 'identity'], $name.'_identity');
                $table->foreign(['order_id', 'tenant_id'])->references(['id', 'tenant_id'])->on('orders')->restrictOnDelete();
            });
        }
        DB::statement('ALTER TABLE discount_role_permissions DROP CONSTRAINT discount_role_permissions_permission_check');
        DB::statement("ALTER TABLE discount_role_permissions ADD CONSTRAINT discount_role_permissions_permission_check CHECK (permission IN ('discounts.view','discounts.manage','discounts.apply_configured','discounts.apply_manual','discounts.settings.manage','discounts.automatic.suppress'))");
        DB::statement("ALTER TABLE discount_role_permissions ADD CONSTRAINT discount_suppression_manager_only CHECK (permission <> 'discounts.automatic.suppress' OR role = 'manager')");
        // Suppression is an explicit Owner grant; do not grant it to employees
        // or silently restore a revoked Manager grant.
    }

    public function down(): void
    {
        if (DB::table('order_discounts')->whereNotNull('source')->exists()) {
            throw new RuntimeException('Engine snapshots exist; roll forward.');
        }
        foreach (['discount_reviews', 'discount_operations', 'discount_payment_quotes', 'order_discount_intents'] as $name) {
            if (DB::table($name)->exists()) {
                throw new RuntimeException('Engine protocol data exists; roll forward.');
            }
        }
        foreach (['discount_reviews', 'discount_operations', 'discount_payment_quotes', 'order_discount_intents'] as $name) {
            Schema::drop($name);
        }
        DB::table('discount_role_permissions')->where('permission', 'discounts.automatic.suppress')->delete();
        DB::statement('ALTER TABLE discount_role_permissions DROP CONSTRAINT discount_suppression_manager_only');
        DB::statement('ALTER TABLE discount_role_permissions DROP CONSTRAINT discount_role_permissions_permission_check');
        DB::statement("ALTER TABLE discount_role_permissions ADD CONSTRAINT discount_role_permissions_permission_check CHECK (permission IN ('discounts.view','discounts.manage','discounts.apply_configured','discounts.apply_manual','discounts.settings.manage'))");
        DB::statement('ALTER TABLE discounts DROP CONSTRAINT discount_priority_check');
        DB::statement('ALTER TABLE discounts DROP CONSTRAINT discount_automatic_code_check');
        Schema::table('discounts', fn (Blueprint $table) => $table->dropColumn('priority'));
    }
};
