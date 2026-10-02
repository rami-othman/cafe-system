<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** The owner sets, per customer, how far below zero the wallet may go (0 = only the funds the customer actually holds). */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('customers', 'wallet_credit_limit')) {
            Schema::table('customers', function (Blueprint $table): void {
                $table->decimal('wallet_credit_limit', 14, 2)->default(0);
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('customers', 'wallet_credit_limit')) {
            Schema::table('customers', fn (Blueprint $table) => $table->dropColumn('wallet_credit_limit'));
        }
    }
};
