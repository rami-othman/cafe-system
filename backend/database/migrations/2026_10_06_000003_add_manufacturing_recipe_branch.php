<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void { Schema::table('manufacturing_recipes', function (Blueprint $table) { $table->foreignId('branch_id')->nullable()->constrained('branches')->restrictOnDelete(); $table->index(['tenant_id', 'branch_id']); }); }
    public function down(): void { Schema::table('manufacturing_recipes', function (Blueprint $table) { $table->dropForeign(['branch_id']); $table->dropIndex(['tenant_id', 'branch_id']); $table->dropColumn('branch_id'); }); }
};
