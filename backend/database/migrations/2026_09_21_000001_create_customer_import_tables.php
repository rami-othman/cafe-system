<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customer_imports', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('actor_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('original_filename', 255);
            $table->char('file_fingerprint', 64);
            $table->string('detected_encoding', 32);
            $table->string('detected_delimiter', 1);
            $table->string('status', 32);
            $table->boolean('create_missing_groups')->nullable();
            $table->unsignedInteger('total_rows')->default(0);
            $table->unsignedInteger('ready_rows')->default(0);
            $table->unsignedInteger('warning_rows')->default(0);
            $table->unsignedInteger('rejected_rows')->default(0);
            $table->unsignedInteger('duplicate_candidates')->default(0);
            $table->unsignedInteger('processed_rows')->default(0);
            $table->unsignedInteger('created_customers')->default(0);
            $table->unsignedInteger('skipped_customers')->default(0);
            $table->unsignedInteger('failed_rows')->default(0);
            $table->unsignedInteger('created_groups')->default(0);
            $table->unsignedInteger('created_memberships')->default(0);
            $table->json('group_summary')->default('{}');
            $table->timestamp('started_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->string('failure_code', 80)->nullable();
            $table->timestamps();

            $table->index(['tenant_id', 'file_fingerprint', 'status'], 'customer_imports_tenant_fingerprint_status_idx');
            $table->index(['tenant_id', 'status', 'created_at'], 'customer_imports_tenant_status_created_idx');
        });

        Schema::create('customer_import_rows', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('customer_import_id')->constrained('customer_imports')->cascadeOnDelete();
            $table->unsignedInteger('source_row_number');
            $table->string('legacy_customer_number', 120)->nullable();
            $table->string('legacy_account_code', 120)->nullable();
            $table->text('source_name')->nullable();
            $table->string('normalized_name', 255)->nullable();
            $table->string('source_phone_one', 120)->nullable();
            $table->string('source_mobile', 120)->nullable();
            $table->string('source_group', 255)->nullable();
            $table->json('parsed_payload')->default('{}');
            $table->string('classification', 40);
            $table->string('status', 40);
            $table->json('warning_codes')->default('[]');
            $table->json('error_codes')->default('[]');
            $table->foreignId('matched_customer_id')->nullable()->constrained('customers')->nullOnDelete();
            $table->foreignId('created_customer_id')->nullable()->constrained('customers')->nullOnDelete();
            $table->foreignId('created_group_id')->nullable()->constrained('customer_groups')->nullOnDelete();
            $table->boolean('membership_created')->default(false);
            $table->timestamps();

            $table->unique(['customer_import_id', 'source_row_number'], 'customer_import_rows_import_source_unique');
            $table->index(['tenant_id', 'normalized_name'], 'customer_import_rows_tenant_name_idx');
            $table->index(['customer_import_id', 'status'], 'customer_import_rows_import_status_idx');
        });
    }

    public function down(): void
    {
        if (! app()->environment('testing')) {
            return;
        }

        Schema::dropIfExists('customer_import_rows');
        Schema::dropIfExists('customer_imports');
    }
};
