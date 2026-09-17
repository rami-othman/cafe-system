<?php

use App\Domain\Discount\DiscountAccess;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('discount_role_permissions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained()->cascadeOnDelete();
            $table->string('role', 40);
            $table->string('permission', 80);
            $table->timestamps();
            $table->unique(['tenant_id', 'role', 'permission']);
        });
        DB::statement("ALTER TABLE discount_role_permissions ADD CONSTRAINT discount_role_permissions_role_check CHECK (role IN ('manager', 'employee'))");
        DB::statement("ALTER TABLE discount_role_permissions ADD CONSTRAINT discount_role_permissions_permission_check CHECK (permission IN ('discounts.view', 'discounts.manage', 'discounts.apply_configured', 'discounts.apply_manual'))");

        // Preserve owner implicit access while safely backfilling the temporary
        // development defaults for both non-owner tenant roles.
        $now = now();
        DB::table('tenant_roles')->whereIn('code', ['manager', 'employee'])->select('tenant_id', 'code')->distinct()->orderBy('tenant_id')->each(function (object $row) use ($now): void {
            foreach (DiscountAccess::CATALOG as $permission) {
                DB::table('discount_role_permissions')->updateOrInsert(
                    ['tenant_id' => $row->tenant_id, 'role' => $row->code, 'permission' => $permission],
                    ['created_at' => $now, 'updated_at' => $now],
                );
            }
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('discount_role_permissions');
    }
};
