<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Fixed assets, batch 2:
 *  - fixed_asset_components: the items an asset is made of (cost split manually or equally); additions,
 *    maintenance and expenses can target the whole asset or one item.
 *  - fixed_asset_component_lines: how each outlay was allocated to the items (ledger-style, voided with its transaction).
 *  - fixed_asset_payments: an acquisition / outlay can be paid from several accounts.
 *  - fixed_asset_transactions gets the non-capitalised expense amount + its expense account.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('fixed_asset_components', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('fixed_asset_id')->constrained('fixed_assets')->cascadeOnDelete();
            $table->string('name');
            $table->decimal('base_cost', 14, 2)->default(0); // the share of the card cost allocated when the asset was entered
            $table->unsignedBigInteger('source_transaction_id')->nullable(); // set when the item was added later by an outlay
            $table->unsignedInteger('sort_order')->default(0);
            $table->text('notes')->nullable();
            $table->timestamp('voided_at')->nullable();
            $table->timestamps();
            $table->index(['tenant_id', 'fixed_asset_id']);
        });

        Schema::create('fixed_asset_component_lines', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('fixed_asset_id')->constrained('fixed_assets')->cascadeOnDelete();
            $table->foreignId('component_id')->constrained('fixed_asset_components')->cascadeOnDelete();
            $table->foreignId('transaction_id')->constrained('fixed_asset_transactions')->cascadeOnDelete();
            $table->decimal('amount', 14, 2);
            $table->boolean('capitalized')->default(true);
            $table->timestamps();
            $table->index(['tenant_id', 'fixed_asset_id']);
            $table->index('component_id');
        });

        Schema::create('fixed_asset_payments', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('fixed_asset_id')->constrained('fixed_assets')->cascadeOnDelete();
            $table->foreignId('transaction_id')->nullable()->constrained('fixed_asset_transactions')->cascadeOnDelete();
            $table->foreignId('account_id')->constrained('financial_accounts');
            $table->decimal('amount', 14, 2);
            $table->timestamps();
            $table->index(['tenant_id', 'fixed_asset_id']);
            $table->index('transaction_id');
        });

        Schema::table('fixed_asset_transactions', function (Blueprint $table): void {
            $table->decimal('expense_amount', 14, 2)->default(0); // outlay expensed to P&L (not part of the asset cost)
            $table->foreignId('expense_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->string('component_scope', 20)->nullable(); // asset|component|new_component
        });
    }

    public function down(): void
    {
        Schema::table('fixed_asset_transactions', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('expense_account_id');
            $table->dropColumn(['expense_amount', 'component_scope']);
        });
        Schema::dropIfExists('fixed_asset_payments');
        Schema::dropIfExists('fixed_asset_component_lines');
        Schema::dropIfExists('fixed_asset_components');
    }
};
