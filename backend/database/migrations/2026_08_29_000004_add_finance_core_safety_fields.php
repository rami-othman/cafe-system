<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->string('idempotency_key', 120)->nullable();
            $table->unique(['tenant_id', 'idempotency_key'], 'orders_tenant_idempotency_unique');
        });

        Schema::table('payments', function (Blueprint $table): void {
            $table->string('idempotency_key', 120)->nullable();
            $table->unique(['tenant_id', 'idempotency_key'], 'payments_tenant_idempotency_unique');
        });

        Schema::table('payment_refunds', function (Blueprint $table): void {
            $table->string('idempotency_key', 120)->nullable();
            $table->unique(['tenant_id', 'idempotency_key'], 'payment_refunds_tenant_idempotency_unique');
        });

        Schema::table('journal_entries', function (Blueprint $table): void {
            $table->string('source_event', 80)->nullable();
            $table->foreignId('reversal_of_id')->nullable()->constrained('journal_entries')->nullOnDelete();
            $table->unique(['tenant_id', 'source_type', 'source_id', 'source_event'], 'journal_entries_source_event_unique');
        });

        Schema::table('payment_refunds', function (Blueprint $table): void {
            $table->dropUnique('payment_refunds_tenant_idempotency_unique');
            $table->dropColumn('idempotency_key');
        });

        Schema::table('payments', function (Blueprint $table): void {
            $table->dropUnique('payments_tenant_idempotency_unique');
            $table->dropColumn('idempotency_key');
        });
    }

    public function down(): void
    {
        Schema::table('journal_entries', function (Blueprint $table): void {
            $table->dropUnique('journal_entries_source_event_unique');
            $table->dropConstrainedForeignId('reversal_of_id');
            $table->dropColumn('source_event');
        });

        Schema::table('orders', function (Blueprint $table): void {
            $table->dropUnique('orders_tenant_idempotency_unique');
            $table->dropColumn('idempotency_key');
        });
    }
};
