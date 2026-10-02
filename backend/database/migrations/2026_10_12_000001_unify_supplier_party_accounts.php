<?php

use App\Services\PartyAccountService;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * A supplier is also a customer, but must have ONE account, under Suppliers (223 / 2000).
 * Earlier builds created that shared account under the receivables parent (121 / 1200):
 * move those accounts, and adopt an imported same-name supplier account instead of keeping two.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('suppliers') || ! Schema::hasColumn('suppliers', 'customer_id')) {
            return;
        }
        $parties = app(PartyAccountService::class);
        foreach (DB::table('suppliers')->distinct()->pluck('tenant_id') as $tenantId) {
            $parties->consolidateSuppliers((int) $tenantId);
        }
    }

    public function down(): void
    {
        // Data-only repair; accounts are not moved back.
    }
};
