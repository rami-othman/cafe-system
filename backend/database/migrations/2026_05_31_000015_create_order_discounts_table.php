<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('order_discounts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('order_id')->constrained();
            $table->foreignId('discount_id')->nullable()->constrained()->nullOnDelete();
            $table->string('discount_name');
            $table->string('discount_type');
            $table->decimal('discount_value', 12, 2);
            $table->decimal('discount_amount', 12, 2);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('order_discounts');
    }
};
