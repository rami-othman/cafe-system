<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('shifts', function (Blueprint $table): void {
            $table->date('business_date')->nullable();
            $table->timestamp('period_end_exclusive')->nullable();
            $table->timestamp('close_executed_at')->nullable();
            $table->foreignId('continuation_of_shift_id')->nullable()->constrained('shifts');
            $table->unique('continuation_of_shift_id');
            $table->string('cash_count_basis')->nullable();
            $table->string('bar_count_basis')->nullable();
            $table->json('close_snapshot')->nullable();
            $table->json('close_request')->nullable();
        });
        Schema::create('shift_period_reassignments', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('from_shift_id')->constrained('shifts');
            $table->foreignId('to_shift_id')->constrained('shifts');
            $table->string('record_table');
            $table->unsignedBigInteger('record_id');
            $table->foreignId('created_by')->constrained('users');
            $table->timestamp('created_at');
            $table->unique(['from_shift_id', 'record_table', 'record_id'], 'shift_period_reassignments_unique');
        });
        Schema::table('stock_counts', function (Blueprint $table): void {
            $table->timestamp('period_end_exclusive')->nullable();
            $table->string('count_basis')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('stock_counts', fn (Blueprint $table) => $table->dropColumn(['period_end_exclusive', 'count_basis']));
        Schema::dropIfExists('shift_period_reassignments');
        Schema::table('shifts', function (Blueprint $table): void {
            $table->dropUnique(['continuation_of_shift_id']);
            $table->dropConstrainedForeignId('continuation_of_shift_id');
            $table->dropColumn(['business_date', 'period_end_exclusive', 'close_executed_at', 'cash_count_basis', 'bar_count_basis', 'close_snapshot', 'close_request']);
        });
    }
};
