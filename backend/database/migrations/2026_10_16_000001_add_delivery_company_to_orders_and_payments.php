<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            // The delivery company the order came through, for reporting only: a Finance payment
            // method of type `delivery_app`. The driver hands the cash over, so accounting is unchanged.
            $table->foreignId('delivery_company_id')->nullable()->after('type')->constrained('payment_methods')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('delivery_company_id');
        });
    }
};
