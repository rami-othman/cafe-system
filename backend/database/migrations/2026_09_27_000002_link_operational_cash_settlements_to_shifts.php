<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customer_payments', function (Blueprint $table): void {
            $table->foreignId('shift_id')->nullable()->constrained('shifts')->nullOnDelete();
        });
        Schema::table('customer_refunds', function (Blueprint $table): void {
            $table->foreignId('shift_id')->nullable()->constrained('shifts')->nullOnDelete();
        });
        Schema::table('expenses', function (Blueprint $table): void {
            $table->foreignId('shift_id')->nullable()->constrained('shifts')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('expenses', fn (Blueprint $table) => $table->dropConstrainedForeignId('shift_id'));
        Schema::table('customer_refunds', fn (Blueprint $table) => $table->dropConstrainedForeignId('shift_id'));
        Schema::table('customer_payments', fn (Blueprint $table) => $table->dropConstrainedForeignId('shift_id'));
    }
};
