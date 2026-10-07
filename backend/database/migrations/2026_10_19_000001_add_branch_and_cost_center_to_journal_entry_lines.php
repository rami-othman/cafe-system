<?php

use App\Services\InterBranchAccount;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Branch becomes a dimension of every journal LINE, not only of the entry header, so one
 * entry can move value between branches (asset transfer, shared-cost allocation) and each
 * branch still gets its own balanced books (profit per branch, investor shares).
 *
 * - journal_entry_lines.branch_id: NULL = company-wide (head office). Existing lines inherit
 *   their entry's branch; reports read COALESCE(lines.branch_id, entries.branch_id).
 * - cost_centers + journal_entry_lines.cost_center_id: optional second dimension (structure only).
 * - Each tenant gets an inter-branch clearing account ("جاري الفروع") mapped to
 *   branches.inter_branch, used to keep every branch balanced inside a multi-branch entry.
 *
 * Additive only: no posted amount, account or date changes.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('cost_centers')) {
            Schema::create('cost_centers', function (Blueprint $table): void {
                $table->id();
                $table->foreignId('tenant_id')->constrained();
                $table->foreignId('parent_id')->nullable()->constrained('cost_centers')->nullOnDelete();
                $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
                $table->string('code', 40);
                $table->string('name_ar');
                $table->string('name_en')->nullable();
                $table->boolean('is_active')->default(true);
                $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
                $table->timestamps();
                $table->softDeletes();

                $table->unique(['tenant_id', 'code']);
            });
        }

        Schema::table('journal_entry_lines', function (Blueprint $table): void {
            if (! Schema::hasColumn('journal_entry_lines', 'branch_id')) {
                $table->foreignId('branch_id')->nullable()->after('financial_location_id')->constrained()->nullOnDelete();
                $table->index(['tenant_id', 'branch_id', 'financial_account_id'], 'journal_entry_lines_branch_account_idx');
            }
            if (! Schema::hasColumn('journal_entry_lines', 'cost_center_id')) {
                $table->foreignId('cost_center_id')->nullable()->after('branch_id')->constrained('cost_centers')->nullOnDelete();
            }
        });

        DB::statement('UPDATE journal_entry_lines SET branch_id = (SELECT journal_entries.branch_id FROM journal_entries WHERE journal_entries.id = journal_entry_lines.journal_entry_id) WHERE branch_id IS NULL');

        if (Schema::hasTable('sales_account_mappings')) {
            $service = app(InterBranchAccount::class);
            foreach (DB::table('tenants')->pluck('id') as $tenantId) {
                if (DB::table('financial_accounts')->where('tenant_id', $tenantId)->exists()) {
                    $service->ensure((int) $tenantId);
                }
            }
        }
    }

    public function down(): void
    {
        Schema::table('journal_entry_lines', function (Blueprint $table): void {
            if (Schema::hasColumn('journal_entry_lines', 'cost_center_id')) {
                $table->dropConstrainedForeignId('cost_center_id');
            }
            if (Schema::hasColumn('journal_entry_lines', 'branch_id')) {
                $table->dropIndex('journal_entry_lines_branch_account_idx');
                $table->dropConstrainedForeignId('branch_id');
            }
        });
        Schema::dropIfExists('cost_centers');
    }
};
