<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Partners / investors per branch: the company itself is a partner (kind=company), external
 * investors are kind=investor. Branch ownership is effective-dated (shares change when an
 * investor joins or leaves). Profit distributions allocate a branch's net profit for a period
 * to its partners' current accounts, after an optional management fee for the company.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('partners', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->string('name');
            $table->string('kind', 20)->default('investor'); // company|investor
            $table->string('phone', 60)->nullable();
            $table->text('notes')->nullable();
            $table->foreignId('capital_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->foreignId('current_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->foreignId('drawings_account_id')->nullable()->constrained('financial_accounts')->nullOnDelete();
            $table->boolean('is_active')->default(true);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->softDeletes();
            $table->index(['tenant_id', 'kind']);
        });

        Schema::create('branch_ownerships', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->constrained();
            $table->foreignId('partner_id')->constrained('partners');
            $table->decimal('share_percent', 7, 4);
            $table->date('effective_from');
            $table->date('effective_to')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->index(['tenant_id', 'branch_id', 'effective_from']);
        });

        Schema::create('branch_profit_settings', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->unique()->constrained();
            $table->string('management_fee_type', 30)->default('none'); // none|revenue_percent|profit_percent
            $table->decimal('management_fee_percent', 7, 4)->default(0);
            $table->foreignId('management_fee_partner_id')->nullable()->constrained('partners')->nullOnDelete();
            $table->boolean('carry_forward_losses')->default(false);
            $table->timestamps();
        });

        Schema::create('profit_distributions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('branch_id')->constrained();
            $table->string('distribution_number', 40);
            $table->date('period_from');
            $table->date('period_to');
            $table->decimal('revenue', 14, 2)->default(0);
            $table->decimal('net_profit', 14, 2)->default(0);
            $table->decimal('carried_loss', 14, 2)->default(0);
            $table->decimal('management_fee', 14, 2)->default(0);
            $table->decimal('distributable', 14, 2)->default(0);
            $table->string('status', 20)->default('posted'); // posted|reversed
            $table->unsignedBigInteger('journal_entry_id')->nullable();
            $table->unsignedBigInteger('reversal_journal_entry_id')->nullable();
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('reversed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reversed_at')->nullable();
            $table->timestamps();
            $table->unique(['tenant_id', 'distribution_number']);
            $table->index(['tenant_id', 'branch_id', 'period_to']);
        });

        Schema::create('profit_distribution_lines', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('profit_distribution_id')->constrained()->cascadeOnDelete();
            $table->foreignId('partner_id')->constrained('partners');
            $table->string('kind', 30)->default('share'); // share|management_fee
            $table->decimal('share_percent', 7, 4)->default(0);
            $table->decimal('amount', 14, 2);
            $table->timestamps();
        });

        Schema::create('partner_transactions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('partner_id')->constrained('partners');
            $table->foreignId('branch_id')->nullable()->constrained()->nullOnDelete();
            $table->string('type', 30); // capital_in|capital_out|withdrawal|payout
            $table->date('transaction_date');
            $table->decimal('amount', 14, 2);
            $table->foreignId('counter_account_id')->constrained('financial_accounts');
            $table->text('description')->nullable();
            $table->unsignedBigInteger('journal_entry_id')->nullable();
            $table->unsignedBigInteger('reversal_journal_entry_id')->nullable();
            $table->timestamp('reversed_at')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->index(['tenant_id', 'partner_id', 'transaction_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('partner_transactions');
        Schema::dropIfExists('profit_distribution_lines');
        Schema::dropIfExists('profit_distributions');
        Schema::dropIfExists('branch_profit_settings');
        Schema::dropIfExists('branch_ownerships');
        Schema::dropIfExists('partners');
    }
};
