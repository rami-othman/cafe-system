<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * A second, additive status dimension — deliberately never merged into
     * `supplier_invoices.status` (which already conflates document and
     * payment lifecycle). Null means "not applicable" (no inventory lines);
     * for an inventory-line invoice it is one of
     * not_received|partially_received|received, derived and maintained by
     * PurchaseReceivingService::recomputeReceiptStatus() the same way
     * SupplierPaymentService derives the payment status — never edited
     * directly by any controller.
     */
    public function up(): void
    {
        Schema::table('supplier_invoices', function (Blueprint $table): void {
            $table->string('receipt_status', 20)->nullable()->after('status');
        });
    }

    public function down(): void
    {
        Schema::table('supplier_invoices', function (Blueprint $table): void {
            $table->dropColumn('receipt_status');
        });
    }
};
