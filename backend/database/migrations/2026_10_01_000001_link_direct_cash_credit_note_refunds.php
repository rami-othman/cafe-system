<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customer_refunds', function (Blueprint $table): void {
            $table->foreignId('sales_credit_note_id')->nullable()
                ->constrained('sales_credit_notes')->restrictOnDelete();
            $table->unique(['tenant_id', 'sales_credit_note_id'], 'customer_refunds_credit_note_unique');
        });
    }

    public function down(): void
    {
        Schema::table('customer_refunds', function (Blueprint $table): void {
            $table->dropUnique('customer_refunds_credit_note_unique');
            $table->dropConstrainedForeignId('sales_credit_note_id');
        });
    }
};
