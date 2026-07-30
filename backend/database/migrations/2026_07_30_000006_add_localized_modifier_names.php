<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('modifier_groups', function (Blueprint $table): void {
            $table->string('name_ar')->nullable()->after('name');
            $table->string('name_en')->nullable()->after('name_ar');
        });

        Schema::table('modifier_options', function (Blueprint $table): void {
            $table->string('name_ar')->nullable()->after('name');
            $table->string('name_en')->nullable()->after('name_ar');
        });
    }

    public function down(): void
    {
        Schema::table('modifier_options', fn (Blueprint $table) => $table->dropColumn(['name_ar', 'name_en']));
        Schema::table('modifier_groups', fn (Blueprint $table) => $table->dropColumn(['name_ar', 'name_en']));
    }
};
