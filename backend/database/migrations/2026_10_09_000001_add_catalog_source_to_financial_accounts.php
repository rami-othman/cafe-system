<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('financial_accounts', function (Blueprint $table): void {
            $table->string('catalog_source', 32)->nullable()->index();
        });
    }

    public function down(): void
    {
        Schema::table('financial_accounts', function (Blueprint $table): void {
            $table->dropColumn('catalog_source');
        });
    }
};
