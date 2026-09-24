<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('receipt_templates', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->constrained();
            $table->string('type', 32)->default('receipt');
            $table->json('header');
            $table->json('order_info');
            $table->json('items');
            $table->json('totals');
            $table->json('payment');
            $table->json('footer');
            $table->json('section_order');
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['branch_id', 'type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('receipt_templates');
    }
};
