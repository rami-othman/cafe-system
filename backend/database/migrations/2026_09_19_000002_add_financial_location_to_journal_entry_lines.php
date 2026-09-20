<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Reconciliation and account balances currently identify a physical cash
 * location only through financial_account_id. Since Phase 1 allows several
 * financial_locations to share one GL account (e.g. two POS drawers both
 * posting to 1010), journal lines need their own location tag so that
 * reconciling one drawer never pulls in another drawer's movements.
 *
 * This is additive only: existing rows get a null financial_location_id and
 * remain readable exactly as before by any code that still filters on
 * financial_account_id alone.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('journal_entry_lines', function (Blueprint $table): void {
            $table->foreignId('financial_location_id')->nullable()->after('financial_account_id')->constrained()->nullOnDelete();
            $table->index(['tenant_id', 'financial_account_id', 'financial_location_id'], 'journal_entry_lines_account_location_idx');
        });
    }

    public function down(): void
    {
        Schema::table('journal_entry_lines', function (Blueprint $table): void {
            $table->dropIndex('journal_entry_lines_account_location_idx');
            $table->dropConstrainedForeignId('financial_location_id');
        });
    }
};
