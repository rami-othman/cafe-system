<?php

namespace App\Services;

use App\Domain\Customer\CustomerNameNormalizer;
use App\Domain\Customer\CustomerNumberGenerator;
use Illuminate\Support\Facades\DB;

/**
 * A delivery company (a `delivery_app` payment method) is also a customer record: it owes the café
 * the cash of the orders its drivers collected. The customer record simply adopts the ledger account
 * the manager linked to the payment method, so the company shows up in Customers and its account
 * ledger is the single place that shows everything between the café and the company.
 */
final class DeliveryCompanyCustomerService
{
    public function __construct(private readonly CustomerNumberGenerator $numbers) {}

    /** Creates (or re-uses) the customer record behind a delivery_app payment method. Returns its id. */
    public function ensureForPaymentMethod(int $tenantId, int $paymentMethodId, ?int $actorId = null): ?int
    {
        $method = DB::table('payment_methods')->where('tenant_id', $tenantId)->where('id', $paymentMethodId)
            ->where('type', 'delivery_app')->first(['id', 'name', 'financial_account_id']);
        if (! $method) {
            return null;
        }

        return DB::transaction(function () use ($tenantId, $method): int {
            $existing = DB::table('customers')->where('tenant_id', $tenantId)
                ->where('financial_account_id', $method->financial_account_id)->whereNull('deleted_at')->first(['id']);
            if ($existing) {
                return (int) $existing->id;
            }
            $name = CustomerNameNormalizer::normalize($method->name);

            return (int) DB::table('customers')->insertGetId([
                'tenant_id' => $tenantId,
                'customer_number' => $this->numbers->next($tenantId),
                'name' => $name['displayName'], 'normalized_name' => $name['normalizedName'],
                'customer_type' => 'registered', 'is_walk_in' => false, 'is_active' => true,
                'financial_account_id' => $method->financial_account_id,
                'created_at' => now(), 'updated_at' => now(),
            ]);
        });
    }

    /**
     * Ledger account of the delivery company an order came through, or null when the order has none
     * (or the company is no longer an active, linked delivery_app method).
     */
    public function accountCodeForOrder(int $tenantId, object $order): ?string
    {
        if (empty($order->delivery_company_id)) {
            return null;
        }
        $code = DB::table('payment_methods as pm')->join('financial_accounts as a', 'a.id', '=', 'pm.financial_account_id')
            ->where('pm.tenant_id', $tenantId)->where('pm.id', $order->delivery_company_id)->where('pm.type', 'delivery_app')
            ->where('a.is_active', true)->whereNull('a.deleted_at')->value('a.code');

        return $code === null ? null : (string) $code;
    }
}
