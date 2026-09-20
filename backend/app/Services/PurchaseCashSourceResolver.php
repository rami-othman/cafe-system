<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Purchase adapter for the shared physical cash source resolver. */
final class PurchaseCashSourceResolver
{
    public function __construct(private readonly CashSourceResolver $cashSources) {}

    public function mode(int $tenantId, int $actorId): string
    {
        return $this->cashSources->mode($tenantId, $actorId);
    }

    public function allowedLocations(int $tenantId, int $actorId, int $branchId): array
    {
        return $this->cashSources->allowedLocations($tenantId, $actorId, $branchId);
    }

    /** @return object{location:object,method:object,shift:?object,mode:string} */
    public function resolve(int $tenantId, int $actorId, int $branchId, bool $lock = false, ?int $selectedLocationId = null): object
    {
        $source = $this->cashSources->resolve($tenantId, $actorId, $branchId, $selectedLocationId, $lock);
        $query = DB::table('payment_methods')->where('tenant_id', $tenantId)->where('code', 'CASH')
            ->where('type', 'cash')
            ->whereNull('financial_location_id')->where('is_active', true);
        if ($lock) $query->lockForUpdate();
        $method = $query->first();
        if (! $method) {
            throw ValidationException::withMessages(['paymentMethodId' => 'طريقة الدفع النقدي غير متاحة لهذا الصندوق.']);
        }
        return (object) ['location' => $source->location, 'method' => $method, 'shift' => $source->shift, 'mode' => $source->mode];
    }
}
