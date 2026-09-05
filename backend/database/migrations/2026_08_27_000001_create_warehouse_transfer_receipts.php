<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('warehouse_transfer_receipts', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('warehouse_transfer_id')->constrained()->cascadeOnDelete();
            $table->string('idempotency_key', 120);
            $table->foreignId('received_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['warehouse_transfer_id', 'idempotency_key']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('warehouse_transfer_receipts');
    }
};
