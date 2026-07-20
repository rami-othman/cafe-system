<?php

namespace App\Http\Controllers\Api\SuperAdmin\V1;

use App\Http\Controllers\Controller;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $data = $request->validate(['from' => ['nullable', 'date'], 'to' => ['nullable', 'date', 'after_or_equal:from'], 'timezone' => ['nullable', 'timezone']]);
        $from = Carbon::parse($data['from'] ?? now()->subDays(29))->startOfDay();
        $to = Carbon::parse($data['to'] ?? now())->endOfDay();
        $orders = DB::table('orders')->whereNull('orders.deleted_at')->whereBetween('orders.closed_at', [$from, $to])->whereIn('orders.payment_status', ['paid', 'partially_refunded', 'refunded']);
        $salesByCurrency = (clone $orders)->join('branches', 'branches.id', '=', 'orders.branch_id')->selectRaw('branches.currency, SUM(orders.total) as gross_sales, COUNT(*) as orders')->groupBy('branches.currency')->get();

        $trialsEnding = DB::table('subscriptions')->join('tenants', 'tenants.id', '=', 'subscriptions.tenant_id')->where('subscriptions.status', 'trialing')->whereBetween('subscriptions.trial_ends_at', [now(), now()->addDays(14)->endOfDay()])->orderBy('subscriptions.trial_ends_at')->limit(5)->get(['subscriptions.id', 'subscriptions.trial_ends_at', 'tenants.id as tenant_id', 'tenants.name as tenant_name']);
        $suspended = DB::table('tenants')->where('status', 'suspended')->whereNull('deleted_at')->latest('updated_at')->limit(5)->get(['id', 'name', 'updated_at']);
        $alerts = collect()->concat($trialsEnding->map(fn ($row) => ['type' => 'trial_ending', 'severity' => 'warning', 'title' => 'Trial ending soon', 'detail' => $row->tenant_name.' trial ends '.$row->trial_ends_at, 'href' => '/subscriptions?endingBefore='.$row->trial_ends_at, 'tenantId' => $row->tenant_id]))->concat($suspended->map(fn ($row) => ['type' => 'tenant_suspended', 'severity' => 'critical', 'title' => 'Suspended tenant', 'detail' => $row->name.' requires review', 'href' => '/tenants/'.$row->id, 'tenantId' => $row->id]))->take(5)->values();

        return response()->json(['data' => [
            'generatedAt' => now()->toIso8601String(),
            'period' => ['from' => $from->toDateString(), 'to' => $to->toDateString(), 'timezone' => $data['timezone'] ?? config('app.timezone')],
            'metrics' => ['totalTenants' => DB::table('tenants')->whereNull('deleted_at')->count(), 'activeTenants' => DB::table('tenants')->where('status', 'active')->whereNull('deleted_at')->count(), 'trialTenants' => DB::table('tenants')->where('status', 'trial')->whereNull('deleted_at')->count(), 'trialsEndingSoon' => $trialsEnding->count(), 'suspendedTenants' => DB::table('tenants')->where('status', 'suspended')->whereNull('deleted_at')->count(), 'newTenants' => DB::table('tenants')->whereBetween('created_at', [$from, $to])->count(), 'totalBranches' => DB::table('branches')->whereNull('deleted_at')->count(), 'totalTenantUsers' => DB::table('users')->whereNotNull('tenant_id')->whereNull('deleted_at')->count(), 'activeSubscriptions' => DB::table('subscriptions')->where('status', 'active')->count()],
            'salesByCurrency' => $salesByCurrency,
            'salesTrend' => (clone $orders)->join('branches', 'branches.id', '=', 'orders.branch_id')->selectRaw('DATE(orders.closed_at) as date, branches.currency, SUM(orders.total) as gross_sales, COUNT(*) as orders')->groupByRaw('DATE(orders.closed_at), branches.currency')->orderBy('date')->get(),
            'tenantGrowth' => DB::table('tenants')->whereNull('deleted_at')->whereBetween('created_at', [$from, $to])->selectRaw('DATE(created_at) as date, COUNT(*) as tenants')->groupByRaw('DATE(created_at)')->orderBy('date')->get(),
            'subscriptionMix' => DB::table('subscriptions')->selectRaw('status, COUNT(*) as total')->groupBy('status')->get(),
            'alerts' => $alerts,
            'recentTenants' => DB::table('tenants')->whereNull('deleted_at')->latest()->limit(5)->get(['id', 'name', 'status', 'plan', 'created_at']),
            'recentActivity' => DB::table('platform_audit_logs')->leftJoin('users', 'users.id', '=', 'platform_audit_logs.actor_id')->latest('platform_audit_logs.id')->limit(10)->get(['platform_audit_logs.id', 'platform_audit_logs.action', 'platform_audit_logs.target_type', 'platform_audit_logs.target_id', 'platform_audit_logs.created_at', 'users.name as actor_name']),
        ]]);
    }
}
