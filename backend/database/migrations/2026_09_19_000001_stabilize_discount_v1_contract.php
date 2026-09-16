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
            // Date-only values are evaluated in the order branch timezone. They
            // deliberately do not inherit the PHP application's timezone.
            $table->date('start_date')->nullable()->after('starts_at');
            $table->date('end_date')->nullable()->after('start_date');
        });

        // The existing polymorphic target table is the canonical target
        // representation for products, categories, branches, customer groups,
        // and payment methods. This removes duplicate target ambiguity without
        // rewriting historical Discount data.
        DB::statement('DELETE FROM discount_targets a USING discount_targets b WHERE a.id > b.id AND a.tenant_id = b.tenant_id AND a.discount_id = b.discount_id AND a.target_type = b.target_type AND a.target_id = b.target_id');
        Schema::table('discount_targets', function (Blueprint $table): void {
            $table->unique(['tenant_id', 'discount_id', 'target_type', 'target_id'], 'discount_targets_tenant_policy_target_unique');
        });
    }

    public function down(): void
    {
        Schema::table('discount_targets', function (Blueprint $table): void {
            $table->dropUnique('discount_targets_tenant_policy_target_unique');
        });
        Schema::table('discounts', function (Blueprint $table): void {
            $table->dropColumn(['start_date', 'end_date']);
        });
    }
};
