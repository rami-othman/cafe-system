<?php

namespace App\Http\Controllers\Api\SuperAdmin\V1;

use App\Actions\SuperAdmin\OnboardTenant;
use App\Http\Controllers\Controller;
use App\Services\SuperAdmin\PlatformAuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class TenantController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate(['search' => ['nullable', 'string'], 'status' => ['nullable', 'string'], 'plan' => ['nullable', 'string'], 'page' => ['nullable', 'integer', 'min:1'], 'perPage' => ['nullable', 'integer', 'min:1', 'max:100']]);
        $query = DB::table('tenants')->leftJoin('subscriptions', 'subscriptions.tenant_id', '=', 'tenants.id')->whereNull('tenants.deleted_at')->select(['tenants.id', 'tenants.name', 'tenants.slug', 'tenants.email', 'tenants.phone', 'tenants.status', 'tenants.plan', 'tenants.currency', 'tenants.created_at', 'subscriptions.status as subscription_status']);
        if ($data['search'] ?? null) {
            $query->where(fn ($q) => $q->whereILike('tenants.name', '%'.$data['search'].'%')->orWhereILike('tenants.slug', '%'.$data['search'].'%')->orWhereILike('tenants.email', '%'.$data['search'].'%'));
        }
        if ($data['status'] ?? null) {
            $query->where('tenants.status', $data['status']);
        } if ($data['plan'] ?? null) {
            $query->where('tenants.plan', $data['plan']);
        }
        $page = $query->orderByDesc('tenants.id')->paginate($data['perPage'] ?? 25, ['*'], 'page', $data['page'] ?? 1);

        return response()->json(['data' => $page->items(), 'meta' => ['currentPage' => $page->currentPage(), 'lastPage' => $page->lastPage(), 'total' => $page->total()]]);
    }

    public function store(Request $request, OnboardTenant $onboard, PlatformAuditService $audit): JsonResponse
    {
        $data = $request->validate(['name' => ['required', 'string', 'max:120'], 'slug' => ['required', 'alpha_dash', 'max:80', Rule::unique('tenants', 'slug')], 'email' => ['required', 'email'], 'phone' => ['nullable', 'string', 'max:40'], 'timezone' => ['required', 'timezone'], 'currency' => ['required', 'in:SYP'], 'logoUrl' => ['nullable', 'url'], 'planId' => ['required', 'integer', 'exists:plans,id'], 'trialDays' => ['required', 'integer', 'min:0', 'max:365'], 'ownerName' => ['required', 'string'], 'ownerEmail' => ['required', 'email', Rule::unique('users', 'email')], 'branchName' => ['required', 'string'], 'branchAddress' => ['nullable', 'string'], 'branchPhone' => ['nullable', 'string']]);
        $tenantId = $onboard->handle($data, $request->user()->id);
        $tenant = DB::table('tenants')->find($tenantId);
        $audit->record($request, 'tenant.created', 'tenant', $tenantId, $tenantId, [], (array) $tenant);

        return response()->json(['data' => $tenant], 201);
    }

    public function show(int $tenant): JsonResponse
    {
        $row = DB::table('tenants')->where('id', $tenant)->whereNull('deleted_at')->first();
        abort_if(! $row, 404);

        return response()->json(['data' => ['tenant' => $row, 'branches' => DB::table('branches')->where('tenant_id', $tenant)->whereNull('deleted_at')->get(), 'users' => DB::table('users')->where('tenant_id', $tenant)->whereNull('deleted_at')->get(['id', 'name', 'email', 'role', 'is_active', 'last_login_at']), 'subscription' => DB::table('subscriptions')->join('plans', 'plans.id', '=', 'subscriptions.plan_id')->where('tenant_id', $tenant)->select('subscriptions.*', 'plans.name as plan_name')->first(), 'usage' => ['orders' => DB::table('orders')->where('tenant_id', $tenant)->whereNull('deleted_at')->count(), 'products' => DB::table('products')->where('tenant_id', $tenant)->whereNull('deleted_at')->count()]]]);
    }

    public function status(Request $request, int $tenant, PlatformAuditService $audit): JsonResponse
    {
        $data = $request->validate(['status' => ['required', Rule::in(['trial', 'active', 'past_due', 'suspended', 'cancelled', 'archived'])], 'reason' => ['required', 'string', 'max:500']]);
        $before = DB::table('tenants')->where('id', $tenant)->whereNull('deleted_at')->first();
        abort_if(! $before, 404);
        DB::table('tenants')->where('id', $tenant)->update(['status' => $data['status'], 'updated_at' => now()]);
        $after = DB::table('tenants')->find($tenant);
        $audit->record($request, 'tenant.status_changed', 'tenant', $tenant, $tenant, (array) $before, (array) $after, $data['reason']);

        return response()->json(['data' => $after]);
    }
}
