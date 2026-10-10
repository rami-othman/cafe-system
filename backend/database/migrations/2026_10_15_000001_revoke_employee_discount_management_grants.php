<?php

use App\Domain\Discount\DiscountAccess;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Product decision: the Employee role applies Discounts in POS but never
 * administers Discount Policies. Early development defaults granted Employees
 * the same discounts.view / discounts.manage rows as Managers. Remove only
 * those two stale rows for the default `employee` role; Owner, Manager and POS
 * apply grants are untouched. Idempotent. DiscountAccess enforces the same rule
 * at runtime, so a row restored out of band is inert.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('discount_role_permissions')) {
            return;
        }

        DB::table('discount_role_permissions')
            ->where('role', 'employee')
            ->whereIn('permission', DiscountAccess::ADMINISTRATIVE)
            ->delete();
    }

    public function down(): void
    {
        // Revoked administrative grants are intentionally not restored.
    }
};
