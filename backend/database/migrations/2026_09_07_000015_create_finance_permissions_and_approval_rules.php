<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('finance_role_permissions', function (Blueprint $table): void {
            $table->id(); $table->foreignId('tenant_id')->constrained(); $table->string('role', 40); $table->string('permission', 100); $table->timestamps();
            $table->unique(['tenant_id', 'role', 'permission']); $table->index(['tenant_id', 'role']);
        });
        Schema::create('finance_approval_rules', function (Blueprint $table): void {
            $table->id(); $table->foreignId('tenant_id')->constrained(); $table->string('action_type', 80); $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete(); $table->string('role', 40)->nullable(); $table->decimal('max_amount', 14, 2)->nullable(); $table->boolean('is_active')->default(true); $table->timestamps();
            $table->index(['tenant_id', 'action_type', 'branch_id', 'is_active']);
        });
    }
    public function down(): void { Schema::dropIfExists('finance_approval_rules'); Schema::dropIfExists('finance_role_permissions'); }
};
