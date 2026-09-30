<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('discounts', function (Blueprint $table): void {
            $table->string('fixed_amount_basis')->default('per_order');
        });
    }

    public function down(): void
    {
        Schema::table('discounts', function (Blueprint $table): void {
            $table->dropColumn('fixed_amount_basis');
        });
    }
};
