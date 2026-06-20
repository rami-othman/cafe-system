<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payment_refunds', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->constrained();
            $table->foreignId('order_id')->constrained();
            $table->foreignId('payment_id')->nullable()->constrained()->nullOnDelete();
            $table->string('refund_number');
            $table->string('type')->default('full');
            $table->decimal('amount', 12, 2);
            $table->string('reason')->nullable();
            $table->text('manager_notes')->nullable();
            $table->string('status')->default('completed');
            $table->timestamp('refunded_at')->nullable();
            $table->timestamps();

            $table->unique(['tenant_id', 'refund_number']);
            $table->index(['tenant_id', 'branch_id', 'status']);
            $table->index(['tenant_id', 'order_id']);
        });

        Schema::create('print_jobs', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->constrained();
            $table->foreignId('order_id')->constrained();
            $table->string('type');
            $table->string('printer_id')->nullable();
            $table->string('channel')->default('local');
            $table->string('status')->default('queued');
            $table->timestamp('queued_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->index(['tenant_id', 'branch_id', 'status']);
            $table->index(['tenant_id', 'order_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('print_jobs');
        Schema::dropIfExists('payment_refunds');
    }
};
