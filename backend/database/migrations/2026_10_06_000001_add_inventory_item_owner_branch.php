<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('inventory_items', function (Blueprint $table): void {
            $table->foreignId('owner_branch_id')->nullable()->constrained('branches')->restrictOnDelete();
            $table->index(['tenant_id', 'owner_branch_id']);
        });
    }

    public function down(): void
    {
        Schema::table('inventory_items', function (Blueprint $table): void {
            $table->dropIndex(['tenant_id', 'owner_branch_id']);
            $table->dropConstrainedForeignId('owner_branch_id');
        });
    }
};
