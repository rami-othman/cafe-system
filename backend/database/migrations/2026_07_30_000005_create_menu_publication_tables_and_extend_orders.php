<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('menu_publications', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->string('status')->default('pending');
            $table->json('change_summary')->nullable();
            $table->json('validation_result')->nullable();
            $table->foreignId('published_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('published_at')->nullable();
            $table->foreignId('source_publication_id')->nullable()->constrained('menu_publications')->nullOnDelete();
            $table->text('failure_message')->nullable();
            $table->timestamps();
            $table->index(['tenant_id', 'status']);
            $table->index(['tenant_id', 'published_at']);
        });
        Schema::create('published_menu_versions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('menu_publication_id')->constrained();
            $table->foreignId('branch_id')->constrained();
            $table->string('channel');
            $table->unsignedBigInteger('version_number');
            $table->json('payload_json');
            $table->char('checksum', 64);
            $table->string('status')->default('current');
            $table->timestamp('published_at');
            $table->timestamps();
            $table->unique(['tenant_id', 'branch_id', 'channel', 'version_number']);
            $table->unique(['tenant_id', 'branch_id', 'channel', 'checksum']);
            $table->index(['tenant_id', 'branch_id', 'channel', 'status']);
            $table->index('menu_publication_id');
        });
        Schema::create('menu_audit_logs', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained();
            $table->foreignId('menu_publication_id')->nullable()->constrained()->nullOnDelete();
            $table->string('entity_type');
            $table->unsignedBigInteger('entity_id')->nullable();
            $table->string('action');
            $table->json('before_data')->nullable();
            $table->json('after_data')->nullable();
            $table->foreignId('changed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('created_at')->useCurrent();
            $table->index(['tenant_id', 'created_at']);
            $table->index(['tenant_id', 'entity_type', 'entity_id']);
            $table->index('menu_publication_id');
        });
        Schema::table('order_items', function (Blueprint $table): void {
            $table->foreignId('product_variant_id')->nullable()->after('product_id')->constrained()->nullOnDelete();
            $table->string('variant_name')->nullable()->after('product_name');
        });
        Schema::table('orders', function (Blueprint $table): void {
            $table->foreignId('published_menu_version_id')->nullable()->after('branch_id')->constrained()->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('orders', fn (Blueprint $table) => $table->dropConstrainedForeignId('published_menu_version_id'));
        Schema::table('order_items', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('product_variant_id');
            $table->dropColumn('variant_name');
        });
        Schema::dropIfExists('menu_audit_logs');
        Schema::dropIfExists('published_menu_versions');
        Schema::dropIfExists('menu_publications');
    }
};
