<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('bar_check_template_lines', function (Blueprint $table): void {
            $table->string('tolerance_type', 20)->default('quantity')->after('is_required');
            $table->boolean('requires_review_when_exceeded')->default(false)->after('manager_review_threshold');
        });
    }
    public function down(): void
    {
        Schema::table('bar_check_template_lines', function (Blueprint $table): void {
            $table->dropColumn(['tolerance_type', 'requires_review_when_exceeded']);
        });
    }
};
