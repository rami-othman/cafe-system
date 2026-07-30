<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenants', function (Blueprint $table): void {
            $table->decimal('tax_rate', 8, 6)->default('0.080000')->after('currency');
        });

        Schema::table('orders', function (Blueprint $table): void {
            $table->decimal('tax_rate', 8, 6)->default('0.080000')->after('tax_total');
        });

        DB::table('orders')->update(['tax_rate' => '0.080000']);
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->dropColumn('tax_rate');
        });

        Schema::table('tenants', function (Blueprint $table): void {
            $table->dropColumn('tax_rate');
        });
    }
};
