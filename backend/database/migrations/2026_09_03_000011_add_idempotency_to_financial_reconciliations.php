<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('financial_reconciliations', function (Blueprint $table): void {
            $table->string('idempotency_key', 120)->nullable()->after('reference');
            $table->string('idempotency_fingerprint', 64)->nullable()->after('idempotency_key');
            $table->unique(['tenant_id', 'idempotency_key'], 'recon_session_idempotency_unique');
        });
    }

    public function down(): void
    {
        Schema::table('financial_reconciliations', function (Blueprint $table): void {
            $table->dropUnique('recon_session_idempotency_unique');
            $table->dropColumn(['idempotency_key', 'idempotency_fingerprint']);
        });
    }
};
