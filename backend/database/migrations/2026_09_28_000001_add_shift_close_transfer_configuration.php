<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('branches', function (Blueprint $table): void {
            $table->foreignId('shift_close_destination_financial_location_id')->nullable()->constrained('financial_locations')->restrictOnDelete();
            $table->decimal('shift_closing_float_amount', 14, 2)->default(0);
            $table->time('shift_close_time')->nullable();
        });
        Schema::table('shifts', function (Blueprint $table): void {
            $table->foreignId('close_destination_financial_location_id')->nullable()->constrained('financial_locations')->restrictOnDelete();
            $table->decimal('closing_float_amount', 14, 2)->default(0);
            $table->string('close_type', 20)->nullable();
            $table->foreignId('close_transfer_id')->nullable()->constrained('cash_transfers')->nullOnDelete();
        });
        Schema::table('cash_transfers', function (Blueprint $table): void {
            $table->foreignId('shift_id')->nullable()->constrained('shifts')->nullOnDelete();
            $table->string('actor_type', 20)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('cash_transfers', fn (Blueprint $table) => $table->dropConstrainedForeignId('shift_id'));
        Schema::table('cash_transfers', fn (Blueprint $table) => $table->dropColumn('actor_type'));
        Schema::table('shifts', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('close_transfer_id');
            $table->dropConstrainedForeignId('close_destination_financial_location_id');
            $table->dropColumn(['closing_float_amount', 'close_type']);
        });
        Schema::table('branches', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('shift_close_destination_financial_location_id');
            $table->dropColumn(['shift_closing_float_amount', 'shift_close_time']);
        });
    }
};
