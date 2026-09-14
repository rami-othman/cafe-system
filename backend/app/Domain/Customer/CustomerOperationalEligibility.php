<?php

namespace App\Domain\Customer;

use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

final class CustomerOperationalEligibility
{
    public function scope(Builder $query, int $tenantId): Builder
    {
        return $query->where('tenant_id', $tenantId)->where('is_active', true)->whereNull('deleted_at');
    }

    public function assert(int $tenantId, ?int $customerId): void
    {
        if ($customerId === null) {
            return;
        }

        $customer = DB::table('customers')->where('tenant_id', $tenantId)->where('id', $customerId)->lockForUpdate()->first();
        if (! $customer || ! $customer->is_active || $customer->deleted_at !== null) {
            throw CustomerDomainException::notOperationallyEligible();
        }
    }
}
