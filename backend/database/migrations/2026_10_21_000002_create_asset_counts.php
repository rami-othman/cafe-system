<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Physical asset counts (جرد فعلي): a snapshot of the register that is ticked off by code/barcode. No accounting impact. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('asset_counts', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->string('count_number', 30);
            $table->foreignId('branch_id')->nullable()->constrained('branches')->nullOnDelete();
            $table->date('count_date');
            $table->string('status', 20)->default('open'); // open|closed|cancelled
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('closed_at')->nullable();
            $table->timestamps();
            $table->unique(['tenant_id', 'count_number']);
        });

        Schema::create('asset_count_lines', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('asset_count_id')->constrained('asset_counts')->cascadeOnDelete();
            $table->foreignId('fixed_asset_id')->constrained('fixed_assets');
            $table->foreignId('expected_branch_id')->nullable()->constrained('branches')->nullOnDelete();
            $table->string('asset_code', 60);
            $table->string('asset_name');
            $table->string('status', 20)->default('pending'); // pending|found|missing|extra
            $table->text('note')->nullable();
            $table->timestamp('counted_at')->nullable();
            $table->timestamps();
            $table->unique(['asset_count_id', 'fixed_asset_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('asset_count_lines');
        Schema::dropIfExists('asset_counts');
    }
};
