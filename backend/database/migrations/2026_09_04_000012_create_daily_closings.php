<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void { Schema::create('daily_closings', function (Blueprint $table): void { $table->id(); $table->foreignId('tenant_id')->constrained(); $table->foreignId('branch_id')->constrained()->restrictOnDelete(); $table->date('business_date'); $table->string('reference', 50); $table->string('status', 12)->default('open'); $table->decimal('actual_cash', 14, 2)->nullable(); $table->decimal('expected_cash', 14, 2)->nullable(); $table->decimal('cash_difference', 14, 2)->nullable(); $table->json('summary_snapshot')->nullable(); $table->json('blockers_snapshot')->nullable(); $table->text('notes')->nullable(); $table->timestamp('calculated_at')->nullable(); $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete(); $table->foreignId('closed_by')->nullable()->constrained('users')->nullOnDelete(); $table->timestamp('closed_at')->nullable(); $table->timestamps(); $table->unique(['tenant_id','branch_id','business_date'], 'daily_closing_tenant_branch_date_unique'); $table->unique(['tenant_id','reference']); $table->index(['tenant_id','branch_id','status']); }); }
    public function down(): void { Schema::dropIfExists('daily_closings'); }
};
