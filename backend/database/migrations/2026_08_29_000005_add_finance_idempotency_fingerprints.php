<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->string('idempotency_fingerprint', 64)->nullable()->after('idempotency_key');
        });

        Schema::table('payments', function (Blueprint $table): void {
            $table->string('idempotency_fingerprint', 64)->nullable()->after('idempotency_key');
        });

        Schema::table('payment_refunds', function (Blueprint $table): void {
            $table->string('idempotency_fingerprint', 64)->nullable()->after('idempotency_key');
        });

        Schema::table('journal_entries', function (Blueprint $table): void {
            $table->unique(['tenant_id', 'reversal_of_id'], 'journal_entries_tenant_reversal_unique');
        });
    }

    public function down(): void
    {
        Schema::table('journal_entries', function (Blueprint $table): void {
            $table->dropUnique('journal_entries_tenant_reversal_unique');
        });

        Schema::table('payment_refunds', function (Blueprint $table): void {
            $table->dropColumn('idempotency_fingerprint');
        });

        Schema::table('payments', function (Blueprint $table): void {
            $table->dropColumn('idempotency_fingerprint');
        });

        Schema::table('orders', function (Blueprint $table): void {
            $table->dropColumn('idempotency_fingerprint');
        });
    }
};
