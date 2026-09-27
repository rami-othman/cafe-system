<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    private const TABLES = ['suppliers', 'customers', 'expense_categories', 'invoice_types', 'invoice_groups', 'customer_groups'];
    public function up(): void
    {
        foreach (self::TABLES as $name) Schema::table($name, function (Blueprint $table): void {
            $table->foreignId('owner_branch_id')->nullable()->constrained('branches')->restrictOnDelete();
            $table->index(['tenant_id', 'owner_branch_id']);
        });
    }
    public function down(): void
    {
        foreach (array_reverse(self::TABLES) as $name) Schema::table($name, function (Blueprint $table): void {
            $table->dropIndex(['tenant_id', 'owner_branch_id']);
            $table->dropConstrainedForeignId('owner_branch_id');
        });
    }
};
