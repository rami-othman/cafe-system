<?php

use App\Services\DeliveryCompanyCustomerService;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // Delivery companies configured before this change become customer records that adopt
        // the ledger account already linked to their payment method (no postings move).
        $service = app(DeliveryCompanyCustomerService::class);
        DB::table('payment_methods')->where('type', 'delivery_app')->orderBy('id')
            ->get(['id', 'tenant_id'])
            ->each(fn (object $method) => $service->ensureForPaymentMethod((int) $method->tenant_id, (int) $method->id));
    }

    public function down(): void
    {
        // Customer records are real data once created; nothing to undo.
    }
};
