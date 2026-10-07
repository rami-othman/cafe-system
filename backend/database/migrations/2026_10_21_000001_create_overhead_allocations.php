<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Head-office (branch-less) expenses charged to branches for a period so that each branch's
 * P&L, and therefore investors' profit shares, carries its part of the overhead.
 * Journal: Dr the same expense account on each branch / Cr the account on the head office.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('overhead_allocations', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->string('allocation_number', 30);
            $table->date('period_from');
            $table->date('period_to');
            $table->string('basis', 20); // revenue|equal|manual
            $table->decimal('total_amount', 18, 2)->default(0);
            $table->string('status', 20)->default('posted'); // posted|reversed
            $table->text('notes')->nullable();
            $table->foreignId('journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
            $table->foreignId('reversal_journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('reversed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reversed_at')->nullable();
            $table->timestamps();
            $table->unique(['tenant_id', 'allocation_number']);
            $table->index(['tenant_id', 'period_to']);
        });

        Schema::create('overhead_allocation_branches', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('overhead_allocation_id')->constrained('overhead_allocations')->cascadeOnDelete();
            $table->foreignId('branch_id')->constrained();
            $table->decimal('share_percent', 7, 4);
            $table->decimal('amount', 18, 2);
            $table->timestamps();
        });

        Schema::create('overhead_allocation_accounts', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('overhead_allocation_id')->constrained('overhead_allocations')->cascadeOnDelete();
            $table->foreignId('financial_account_id')->constrained('financial_accounts');
            $table->decimal('amount', 18, 2);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('overhead_allocation_accounts');
        Schema::dropIfExists('overhead_allocation_branches');
        Schema::dropIfExists('overhead_allocations');
    }
};
