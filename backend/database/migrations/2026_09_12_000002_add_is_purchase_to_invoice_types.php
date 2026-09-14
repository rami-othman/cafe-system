<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Purchasing Center (`GET /finance/purchases`) is a filtered, tagged read
     * of `supplier_invoices` — never a second ledger. This flag is the tag:
     * an invoice type marked `is_purchase` shows up in the Purchasing Center;
     * one that isn't (e.g. a tenant's non-financial "test" type) does not.
     * Every currently-postable type represents money owed to a supplier for
     * something purchased, so it defaults to true; the non-financial `none`
     * behavior (the seeded "test" type) is the only type backfilled false.
     */
    public function up(): void
    {
        Schema::table('invoice_types', function (Blueprint $table): void {
            $table->boolean('is_purchase')->default(true)->after('is_postable');
        });

        DB::table('invoice_types')->where('posting_behavior', 'none')->update(['is_purchase' => false]);
    }

    public function down(): void
    {
        Schema::table('invoice_types', function (Blueprint $table): void {
            $table->dropColumn('is_purchase');
        });
    }
};
