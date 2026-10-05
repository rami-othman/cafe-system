<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // The part of a customer payment not applied to any invoice: it stays as credit on the
        // customer's own account (their wallet). Always amount minus the allocations at posting time.
        Schema::table('customer_payments', function (Blueprint $table): void {
            $table->decimal('advance_amount', 14, 2)->default(0)->after('amount');
        });
    }

    public function down(): void
    {
        Schema::table('customer_payments', fn (Blueprint $table) => $table->dropColumn('advance_amount'));
    }
};
