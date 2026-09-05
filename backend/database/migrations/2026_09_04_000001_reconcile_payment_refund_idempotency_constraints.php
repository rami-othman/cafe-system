<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * MAIN briefly added redundant order-scoped indexes while Finance already
     * owned the tenant-scoped idempotency contract. The tenant-scoped indexes
     * match the API behavior: a reused key on any other order is a conflict.
     */
    public function up(): void
    {
        DB::statement('DROP INDEX IF EXISTS payments_tenant_order_idempotency_unique');
        DB::statement('DROP INDEX IF EXISTS refunds_tenant_order_idempotency_unique');
    }

    /**
     * The historical migration remains recorded on upgraded deployments. Its
     * rollback owns the tenant-scoped indexes and columns, so there is nothing
     * to restore here.
     */
    public function down(): void
    {
        // Intentionally empty; see the rollback note above.
    }
};
