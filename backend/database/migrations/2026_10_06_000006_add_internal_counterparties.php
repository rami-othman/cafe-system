<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void { foreach (['customers', 'suppliers'] as $name) Schema::table($name, function (Blueprint $t) { $t->boolean('is_internal')->default(false); $t->foreignId('internal_branch_id')->nullable()->constrained('branches')->restrictOnDelete(); }); }
    public function down(): void { foreach (['customers', 'suppliers'] as $name) Schema::table($name, function (Blueprint $t) { $t->dropForeign(['internal_branch_id']); $t->dropColumn(['is_internal', 'internal_branch_id']); }); }
};
