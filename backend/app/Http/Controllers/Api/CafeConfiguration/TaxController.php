<?php

namespace App\Http\Controllers\Api\CafeConfiguration;

use App\Http\Controllers\Controller;
use App\Http\Requests\CafeConfiguration\UpdateTaxRequest;
use App\Http\Resources\CafeConfiguration\TaxResource;
use App\Models\Tenant;
use App\Services\TenantTaxService;
use App\Support\TenantContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class TaxController extends Controller
{
    public function __construct(private readonly TenantTaxService $taxes) {}

    public function show(Request $request): TaxResource
    {
        return new TaxResource($this->tenant($request));
    }

    public function update(UpdateTaxRequest $request): TaxResource
    {
        $tenant = $this->tenant($request);

        DB::transaction(function () use ($tenant, $request): void {
            $this->taxes->updateRateFor($tenant->id, $request->validated('taxRate'));
        });

        return new TaxResource($tenant->fresh());
    }

    private function tenant(Request $request): Tenant
    {
        return Tenant::query()->findOrFail(TenantContext::id($request));
    }
}
