<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('invoice_groups', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->string('code', 40);
            $table->string('name', 120);
            $table->text('description')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'is_active', 'name']);
        });

        Schema::create('invoice_types', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('invoice_group_id')->constrained('invoice_groups')->restrictOnDelete();
            $table->string('code', 40);
            $table->string('name', 120);
            // Determines the debit account rule; `none` is a non-financial test/document type.
            $table->string('posting_behavior', 20)->default('other');
            $table->boolean('is_postable')->default(true);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
            $table->unique(['tenant_id', 'code']);
            $table->index(['tenant_id', 'invoice_group_id', 'is_active']);
        });

        Schema::table('supplier_invoices', function (Blueprint $table): void {
            $table->foreignId('invoice_type_id')->nullable()->after('invoice_type')->constrained('invoice_types')->nullOnDelete();
            $table->index(['tenant_id', 'invoice_type_id']);
        });

        foreach (DB::table('tenants')->orderBy('id')->pluck('id') as $tenantId) {
            $accountingGroupId = (int) DB::table('invoice_groups')->insertGetId([
                'tenant_id' => $tenantId, 'code' => 'accounting', 'name' => 'فواتير محاسبية',
                'description' => 'فواتير يمكن ترحيلها إلى القيود المحاسبية.', 'is_active' => true,
                'created_at' => now(), 'updated_at' => now(),
            ]);
            $testGroupId = (int) DB::table('invoice_groups')->insertGetId([
                'tenant_id' => $tenantId, 'code' => 'test', 'name' => 'فواتير تجريبية',
                'description' => 'للتجارب والتوثيق فقط؛ لا تنشئ قيوداً محاسبية.', 'is_active' => true,
                'created_at' => now(), 'updated_at' => now(),
            ]);
            $types = [
                ['code' => 'expense', 'name' => 'مصروف', 'posting_behavior' => 'expense', 'is_postable' => true, 'group' => $accountingGroupId],
                ['code' => 'inventory', 'name' => 'مخزون', 'posting_behavior' => 'inventory', 'is_postable' => true, 'group' => $accountingGroupId],
                ['code' => 'other', 'name' => 'أخرى', 'posting_behavior' => 'other', 'is_postable' => true, 'group' => $accountingGroupId],
                ['code' => 'test', 'name' => 'فاتورة تجريبية', 'posting_behavior' => 'none', 'is_postable' => false, 'group' => $testGroupId],
            ];
            foreach ($types as $type) {
                $typeId = (int) DB::table('invoice_types')->insertGetId([
                    'tenant_id' => $tenantId, 'invoice_group_id' => $type['group'], 'code' => $type['code'],
                    'name' => $type['name'], 'posting_behavior' => $type['posting_behavior'],
                    'is_postable' => $type['is_postable'], 'is_active' => true,
                    'created_at' => now(), 'updated_at' => now(),
                ]);
                if ($type['code'] !== 'test') {
                    DB::table('supplier_invoices')->where('tenant_id', $tenantId)->where('invoice_type', $type['code'])->update(['invoice_type_id' => $typeId]);
                }
            }
        }
    }

    public function down(): void
    {
        Schema::table('supplier_invoices', function (Blueprint $table): void {
            $table->dropIndex(['tenant_id', 'invoice_type_id']);
            $table->dropConstrainedForeignId('invoice_type_id');
        });
        Schema::dropIfExists('invoice_types');
        Schema::dropIfExists('invoice_groups');
    }
};
