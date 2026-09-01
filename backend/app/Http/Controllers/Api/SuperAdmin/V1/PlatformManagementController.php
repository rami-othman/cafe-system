<?php

namespace App\Http\Controllers\Api\SuperAdmin\V1;

use App\Http\Controllers\Controller;
use App\Models\ApiToken;
use App\Services\SuperAdmin\PlatformAuditService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\StreamedResponse;

class PlatformManagementController extends Controller
{
    public function branches(Request $request): JsonResponse
    {
        $data = $request->validate(['tenantId' => ['nullable', 'integer', 'exists:tenants,id'], 'search' => ['nullable', 'string', 'max:120']]);
        $query = DB::table('branches')->join('tenants', 'tenants.id', '=', 'branches.tenant_id')
            ->whereNull('branches.deleted_at')->select('branches.id', 'branches.name', 'branches.is_active', 'branches.timezone', 'branches.currency', 'branches.created_at', 'tenants.id as tenant_id', 'tenants.name as tenant_name');
        if ($data['tenantId'] ?? null) {
            $query->where('branches.tenant_id', $data['tenantId']);
        }
        if ($data['search'] ?? null) {
            $query->where(fn ($q) => $q->whereILike('branches.name', '%'.$data['search'].'%')->orWhereILike('tenants.name', '%'.$data['search'].'%'));
        }

        return response()->json(['data' => $query->orderByDesc('branches.id')->get()]);
    }

    public function updateBranch(Request $request, int $branch, PlatformAuditService $audit): JsonResponse
    {
        $data = $request->validate(['isActive' => ['required', 'boolean'], 'reason' => ['required', 'string', 'max:500']]);
        $before = DB::table('branches')->where('id', $branch)->whereNull('deleted_at')->first();
        abort_if(! $before, 404);
        DB::table('branches')->where('id', $branch)->update(['is_active' => $data['isActive'], 'updated_at' => now()]);
        $after = DB::table('branches')->find($branch);
        $audit->record($request, 'branch.status_changed', 'branch', $branch, $before->tenant_id, (array) $before, (array) $after, $data['reason']);

        return response()->json(['data' => $after]);
    }

    public function tenantUsers(Request $request): JsonResponse
    {
        $data = $request->validate(['tenantId' => ['nullable', 'integer', 'exists:tenants,id'], 'search' => ['nullable', 'string', 'max:120']]);
        $query = DB::table('users')->join('tenants', 'tenants.id', '=', 'users.tenant_id')->whereNotNull('users.tenant_id')->whereNull('users.deleted_at')
            ->select('users.id', 'users.name', 'users.email', 'users.role', 'users.is_active', 'users.last_login_at', 'tenants.id as tenant_id', 'tenants.name as tenant_name');
        if ($data['tenantId'] ?? null) {
            $query->where('users.tenant_id', $data['tenantId']);
        }
        if ($data['search'] ?? null) {
            $query->where(fn ($q) => $q->whereILike('users.name', '%'.$data['search'].'%')->orWhereILike('users.email', '%'.$data['search'].'%')->orWhereILike('tenants.name', '%'.$data['search'].'%'));
        }

        return response()->json(['data' => $query->orderByDesc('users.id')->get()]);
    }

    public function updateTenantUser(Request $request, int $user, PlatformAuditService $audit): JsonResponse
    {
        $data = $request->validate(['isActive' => ['required', 'boolean'], 'reason' => ['required', 'string', 'max:500']]);
        $before = DB::table('users')->where('id', $user)->whereNotNull('tenant_id')->whereNull('deleted_at')->first();
        abort_if(! $before, 404);
        $changes = ['is_active' => $data['isActive'], 'updated_at' => now()];
        DB::table('users')->where('id', $user)->update($changes);
        if (! $data['isActive']) {
            ApiToken::query()->where('user_id', $user)->whereNull('revoked_at')->update(['revoked_at' => now(), 'updated_at' => now()]);
        }
        $after = DB::table('users')->find($user);
        $audit->record($request, 'tenant_user.updated', 'user', $user, $before->tenant_id, (array) $before, (array) $after, $data['reason']);

        return response()->json(['data' => $after]);
    }

    public function plans(): JsonResponse
    {
        return response()->json(['data' => DB::table('plans')->leftJoin('plan_features', 'plan_features.plan_id', '=', 'plans.id')
            ->select('plans.*', DB::raw('COUNT(plan_features.id) as feature_count'))->groupBy('plans.id')->orderBy('plans.display_order')->get()]);
    }

    public function storePlan(Request $request, PlatformAuditService $audit): JsonResponse
    {
        $data = $request->validate(['code' => ['required', 'alpha_dash', 'max:80', Rule::unique('plans', 'code')], 'name' => ['required', 'string', 'max:120'], 'description' => ['nullable', 'string'], 'monthlyPrice' => ['required', 'numeric', 'min:0'], 'yearlyPrice' => ['required', 'numeric', 'min:0'], 'currency' => ['required', 'string', 'size:3'], 'isActive' => ['boolean']]);
        $id = DB::table('plans')->insertGetId(['code' => $data['code'], 'name' => $data['name'], 'description' => $data['description'] ?? null, 'monthly_price' => $data['monthlyPrice'], 'yearly_price' => $data['yearlyPrice'], 'currency' => strtoupper($data['currency']), 'is_active' => $data['isActive'] ?? true, 'display_order' => DB::table('plans')->max('display_order') + 1, 'created_at' => now(), 'updated_at' => now()]);
        $plan = DB::table('plans')->find($id);
        $audit->record($request, 'plan.created', 'plan', $id, null, [], (array) $plan);

        return response()->json(['data' => $plan], 201);
    }

    public function updatePlan(Request $request, int $plan, PlatformAuditService $audit): JsonResponse
    {
        $data = $request->validate(['name' => ['required', 'string', 'max:120'], 'description' => ['nullable', 'string'], 'monthlyPrice' => ['required', 'numeric', 'min:0'], 'yearlyPrice' => ['required', 'numeric', 'min:0'], 'currency' => ['required', 'string', 'size:3'], 'isActive' => ['required', 'boolean']]);
        $before = DB::table('plans')->find($plan);
        abort_if(! $before, 404);
        DB::table('plans')->where('id', $plan)->update(['name' => $data['name'], 'description' => $data['description'] ?? null, 'monthly_price' => $data['monthlyPrice'], 'yearly_price' => $data['yearlyPrice'], 'currency' => strtoupper($data['currency']), 'is_active' => $data['isActive'], 'updated_at' => now()]);
        $after = DB::table('plans')->find($plan);
        $audit->record($request, 'plan.updated', 'plan', $plan, null, (array) $before, (array) $after);

        return response()->json(['data' => $after]);
    }

    public function subscriptions(Request $request): JsonResponse
    {
        $data = $request->validate(['status' => ['nullable', 'string'], 'endingBefore' => ['nullable', 'date']]);
        $query = DB::table('subscriptions')->join('tenants', 'tenants.id', '=', 'subscriptions.tenant_id')->join('plans', 'plans.id', '=', 'subscriptions.plan_id')
            ->select('subscriptions.*', 'tenants.name as tenant_name', 'tenants.slug as tenant_slug', 'plans.name as plan_name', 'plans.code as plan_code');
        if ($data['status'] ?? null) {
            $query->where('subscriptions.status', $data['status']);
        }
        if ($data['endingBefore'] ?? null) {
            $query->where('subscriptions.trial_ends_at', '<=', Carbon::parse($data['endingBefore'])->endOfDay());
        }

        return response()->json(['data' => $query->orderBy('subscriptions.trial_ends_at')->get()]);
    }

    public function updateSubscription(Request $request, int $subscription, PlatformAuditService $audit): JsonResponse
    {
        $data = $request->validate(['status' => ['required', Rule::in(['trialing', 'active', 'past_due', 'cancelled'])], 'planId' => ['nullable', 'integer', 'exists:plans,id'], 'reason' => ['required', 'string', 'max:500']]);
        $before = DB::table('subscriptions')->find($subscription);
        abort_if(! $before, 404);
        DB::table('subscriptions')->where('id', $subscription)->update(array_filter(['status' => $data['status'], 'plan_id' => $data['planId'] ?? null, 'cancelled_at' => $data['status'] === 'cancelled' ? now() : null, 'updated_at' => now()], fn ($value) => $value !== null));
        $after = DB::table('subscriptions')->find($subscription);
        DB::table('subscription_events')->insert(['subscription_id' => $subscription, 'actor_id' => $request->user()->id, 'event' => 'admin.updated', 'reason' => $data['reason'], 'occurred_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        $audit->record($request, 'subscription.updated', 'subscription', $subscription, $before->tenant_id, (array) $before, (array) $after, $data['reason']);

        return response()->json(['data' => $after]);
    }

    public function analytics(Request $request): JsonResponse
    {
        $data = $request->validate(['from' => ['nullable', 'date'], 'to' => ['nullable', 'date', 'after_or_equal:from']]);
        $from = Carbon::parse($data['from'] ?? now()->subDays(29))->startOfDay();
        $to = Carbon::parse($data['to'] ?? now())->endOfDay();
        $orders = DB::table('orders')->whereNull('orders.deleted_at')->whereBetween('orders.closed_at', [$from, $to])->whereIn('orders.payment_status', ['paid', 'partially_refunded', 'refunded']);

        return response()->json(['data' => ['period' => compact('from', 'to'), 'salesTrend' => (clone $orders)->join('branches', 'branches.id', '=', 'orders.branch_id')->selectRaw('DATE(orders.closed_at) as date, branches.currency, SUM(orders.total) as gross_sales, COUNT(*) as orders')->groupByRaw('DATE(orders.closed_at), branches.currency')->orderBy('date')->get(), 'tenantGrowth' => DB::table('tenants')->whereNull('deleted_at')->whereBetween('created_at', [$from, $to])->selectRaw('DATE(created_at) as date, COUNT(*) as tenants')->groupByRaw('DATE(created_at)')->orderBy('date')->get(), 'subscriptionMix' => DB::table('subscriptions')->selectRaw('status, COUNT(*) as total')->groupBy('status')->get()]]);
    }

    public function auditLogs(Request $request): JsonResponse
    {
        $data = $request->validate(['action' => ['nullable', 'string'], 'tenantId' => ['nullable', 'integer', 'exists:tenants,id']]);
        $query = DB::table('platform_audit_logs')->leftJoin('users as actors', 'actors.id', '=', 'platform_audit_logs.actor_id')->leftJoin('tenants', 'tenants.id', '=', 'platform_audit_logs.tenant_id')
            ->select('platform_audit_logs.id', 'platform_audit_logs.action', 'platform_audit_logs.target_type', 'platform_audit_logs.target_id', 'platform_audit_logs.reason', 'platform_audit_logs.created_at', 'actors.name as actor_name', 'tenants.name as tenant_name');
        if ($data['action'] ?? null) {
            $query->where('platform_audit_logs.action', $data['action']);
        } if ($data['tenantId'] ?? null) {
            $query->where('platform_audit_logs.tenant_id', $data['tenantId']);
        }

        return response()->json(['data' => $query->latest('platform_audit_logs.id')->limit(100)->get()]);
    }

    public function announcements(): JsonResponse
    {
        return response()->json(['data' => DB::table('announcements')->latest()->get()]);
    }

    public function storeAnnouncement(Request $request, PlatformAuditService $audit): JsonResponse
    {
        $data = $request->validate(['title' => ['required', 'string', 'max:160'], 'message' => ['required', 'string', 'max:5000'], 'severity' => ['required', Rule::in(['information', 'warning', 'critical'])], 'status' => ['required', Rule::in(['draft', 'published', 'archived'])], 'expiresAt' => ['nullable', 'date']]);
        $id = DB::table('announcements')->insertGetId(['created_by' => $request->user()->id, 'title' => $data['title'], 'message' => $data['message'], 'severity' => $data['severity'], 'status' => $data['status'], 'published_at' => $data['status'] === 'published' ? now() : null, 'expires_at' => $data['expiresAt'] ?? null, 'created_at' => now(), 'updated_at' => now()]);
        $announcement = DB::table('announcements')->find($id);
        $audit->record($request, 'announcement.created', 'announcement', $id, null, [], (array) $announcement);

        return response()->json(['data' => $announcement], 201);
    }

    public function updateAnnouncement(Request $request, int $announcement, PlatformAuditService $audit): JsonResponse
    {
        $data = $request->validate(['status' => ['required', Rule::in(['draft', 'published', 'archived'])], 'reason' => ['nullable', 'string', 'max:500']]);
        $before = DB::table('announcements')->find($announcement);
        abort_if(! $before, 404);
        DB::table('announcements')->where('id', $announcement)->update(['status' => $data['status'], 'published_at' => $data['status'] === 'published' ? ($before->published_at ?? now()) : $before->published_at, 'updated_at' => now()]);
        $after = DB::table('announcements')->find($announcement);
        $audit->record($request, 'announcement.status_changed', 'announcement', $announcement, null, (array) $before, (array) $after, $data['reason'] ?? null);

        return response()->json(['data' => $after]);
    }

    public function health(): JsonResponse
    {
        $database = 'healthy';
        try {
            DB::select('select 1');
        } catch (\Throwable) {
            $database = 'down';
        }
        $failedJobs = Schema::hasTable('failed_jobs') ? DB::table('failed_jobs')->count() : null;

        return response()->json(['data' => ['generatedAt' => now()->toIso8601String(), 'services' => [['name' => 'Database', 'status' => $database], ['name' => 'Queue failures', 'status' => $failedJobs ? 'warning' : 'healthy', 'value' => $failedJobs], ['name' => 'Scheduler', 'status' => 'unknown', 'value' => 'No heartbeat configured']]]]);
    }

    public function settings(): JsonResponse
    {
        return response()->json(['data' => DB::table('platform_settings')->orderBy('key')->get()]);
    }

    public function updateSetting(Request $request, string $setting, PlatformAuditService $audit): JsonResponse
    {
        $data = $request->validate(['value' => ['required']]);
        $before = DB::table('platform_settings')->where('key', $setting)->first();
        DB::table('platform_settings')->updateOrInsert(['key' => $setting], ['value' => json_encode($data['value']), 'updated_at' => now(), 'created_at' => $before?->created_at ?? now()]);
        $after = DB::table('platform_settings')->where('key', $setting)->first();
        $audit->record($request, 'platform_setting.updated', 'platform_setting', null, null, (array) $before, (array) $after);

        return response()->json(['data' => $after]);
    }

    public function platformAdmins(): JsonResponse
    {
        return response()->json(['data' => DB::table('users')->whereNull('users.tenant_id')->join('platform_role_user', 'platform_role_user.user_id', '=', 'users.id')->join('platform_roles', 'platform_roles.id', '=', 'platform_role_user.platform_role_id')->select('users.id', 'users.name', 'users.email', 'users.is_active', 'users.last_login_at', 'platform_roles.name as role_name', 'platform_roles.code as role_code')->orderBy('users.name')->get()]);
    }

    public function exportTenants(Request $request, PlatformAuditService $audit): StreamedResponse
    {
        $audit->record($request, 'export.tenants');

        return response()->streamDownload(function (): void {
            $handle = fopen('php://output', 'w');
            fputcsv($handle, ['Name', 'Slug', 'Email', 'Status', 'Plan', 'Currency', 'Created at']);
            DB::table('tenants')->whereNull('deleted_at')->orderBy('id')->select('name', 'slug', 'email', 'status', 'plan', 'currency', 'created_at')->each(function ($tenant) use ($handle): void {
                fputcsv($handle, [(string) $tenant->name, (string) $tenant->slug, (string) $tenant->email, (string) $tenant->status, (string) $tenant->plan, (string) $tenant->currency, (string) $tenant->created_at]);
            });
            fclose($handle);
        }, 'tenants-'.now()->toDateString().'.csv', ['Content-Type' => 'text/csv; charset=UTF-8']);
    }
}
