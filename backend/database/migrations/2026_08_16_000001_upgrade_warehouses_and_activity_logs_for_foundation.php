<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('warehouses', function (Blueprint $table): void {
            $table->string('code')->nullable();
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->index(['tenant_id', 'branch_id', 'type']);
        });

        DB::table('warehouses')->orderBy('id')->get()->each(function (object $warehouse): void {
            $type = match ($warehouse->type) {
                'main' => $warehouse->branch_id ? 'branch_main' : 'central',
                default => $warehouse->type,
            };
            $code = $warehouse->code ?: sprintf('LEGACY-%06d', $warehouse->id);
            DB::table('warehouses')->where('id', $warehouse->id)->update([
                'type' => $type,
                'code' => $code,
                'updated_at' => now(),
            ]);
        });

        Schema::table('warehouses', function (Blueprint $table): void {
            $table->unique(['tenant_id', 'code'], 'warehouses_tenant_code_unique');
        });

        Schema::table('activity_logs', function (Blueprint $table): void {
            $table->json('before_state')->nullable();
            $table->json('after_state')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('activity_logs', function (Blueprint $table): void {
            $table->dropColumn(['before_state', 'after_state']);
        });

        Schema::table('warehouses', function (Blueprint $table): void {
            $table->dropUnique('warehouses_tenant_code_unique');
            $table->dropIndex(['tenant_id', 'branch_id', 'type']);
            $table->dropConstrainedForeignId('created_by');
            $table->dropConstrainedForeignId('updated_by');
            $table->dropColumn(['code', 'notes']);
        });
    }
};
