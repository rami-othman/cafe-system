<?php

namespace App\Http\Controllers\Api\Manufacturing;

use App\Http\Controllers\Controller;
use App\Services\OperationalAuditService;
use App\Support\DataScope;
use App\Support\FactoryWarehouseScope;
use App\Support\TenantContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class FactoryCurrencyController extends Controller
{
    public function show(Request $request)
    {
        [$tenant, $branch] = $this->scope($request);

        return response()->json(['data' => $this->settings($tenant, $branch)]);
    }

    public function update(Request $request)
    {
        [$tenant, $branch] = $this->scope($request);
        abort_unless(in_array($request->attributes->get('auth_user')->effectiveRoleCode(), ['owner', 'factory_manager'], true), 403);
        $data = $request->validate(['defaultCurrency' => ['required', 'in:SYP,USD'], 'usdToSyp' => ['required', 'regex:/^\d+(\.\d{1,6})?$/', 'numeric', 'gt:0', 'max:1000000000']]);
        $before = $this->settings($tenant, $branch);
        DB::transaction(function () use ($tenant, $branch, $data, $request, $before) {
            DB::table('factory_currency_settings')->upsert([['tenant_id' => $tenant, 'branch_id' => $branch, 'default_currency' => $data['defaultCurrency'], 'usd_to_syp' => $data['usdToSyp'], 'updated_at' => now(), 'created_at' => now()]], ['tenant_id', 'branch_id'], ['default_currency', 'usd_to_syp', 'updated_at']);
            app(OperationalAuditService::class)->record($request, $tenant, 'factory.currency.updated', 'branch', $branch, $before, $data, $branch, $request->attributes->get('auth_user')->id);
        });

        return response()->json(['data' => $this->settings($tenant, $branch)]);
    }

    private function scope(Request $request): array
    {
        $tenant = TenantContext::id($request);
        $branch = DataScope::resolve($request);
        $requested = (int) $request->input('branchId', $request->input('scopeBranchId', 0));
        abort_if($requested && $requested !== $branch, 403, 'المعمل غير متاح لهذا المستخدم.');
        FactoryWarehouseScope::assertFactoryBranch($tenant, $branch);

        return [$tenant, $branch];
    }

    private function settings(int $tenant, int $branch): array
    {
        $row = DB::table('factory_currency_settings')->where('tenant_id', $tenant)->where('branch_id', $branch)->first();

        return ['branchId' => $branch, 'baseCurrency' => 'SYP', 'defaultCurrency' => $row?->default_currency ?? 'SYP', 'usdToSyp' => $row?->usd_to_syp, 'updatedAt' => $row?->updated_at];
    }
}
