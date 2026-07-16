<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('discounts', function (Blueprint $table): void {
            $table->text('description')->nullable()->after('name');
            $table->string('application_mode')->default('code')->after('code');
            $table->text('conditions')->nullable()->after('scope');
            $table->json('active_days')->nullable()->after('ends_at');
            $table->time('start_time')->nullable()->after('active_days');
            $table->time('end_time')->nullable()->after('start_time');
            $table->unsignedInteger('usage_limit_per_customer')->nullable()->after('usage_limit');
            $table->string('customer_eligibility')->nullable()->after('usage_limit_per_customer');
            $table->string('payment_method')->nullable()->after('customer_eligibility');
            $table->decimal('estimated_saved_value', 12, 2)->default(0)->after('used_count');
            $table->string('display_period_primary')->nullable()->after('estimated_saved_value');
            $table->string('display_period_secondary')->nullable()->after('display_period_primary');
        });
    }

    public function down(): void
    {
        Schema::table('discounts', function (Blueprint $table): void {
            $table->dropColumn([
                'description', 'application_mode', 'conditions', 'active_days',
                'start_time', 'end_time', 'usage_limit_per_customer',
                'customer_eligibility', 'payment_method', 'estimated_saved_value',
                'display_period_primary', 'display_period_secondary',
            ]);
        });
    }
};
