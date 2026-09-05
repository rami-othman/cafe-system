<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Services\DailyClosingService;
use App\Services\FinanceDashboardContext;
use App\Services\FinanceDashboardQueryService;
use App\Services\FinancialReconciliationQueryService;
use App\Services\FinancialReportQueryService;
use Illuminate\Console\Command;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** Read-only execution check for the deterministic Finance Operations demo. */
final class VerifyFinanceDemo extends Command
{
    protected $signature = 'finance:verify-demo {tenant=cafe-618-finance-demo : Demo tenant slug}';

    protected $description = 'Execute dashboard, Finance reports, reconciliation, close, and period read models for the demo tenant';

    public function handle(
        FinanceDashboardContext $dashboardContext,
        FinanceDashboardQueryService $dashboard,
        FinancialReportQueryService $reports,
        FinancialReconciliationQueryService $reconciliations,
        DailyClosingService $closings,
    ): int {
        $tenant = (int) DB::table('tenants')->where('slug', $this->argument('tenant'))->whereNull('deleted_at')->value('id');
        $owner = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        if (! $tenant || ! $owner) {
            $this->components->error('Demo tenant or its owner was not found.');
            return self::FAILURE;
        }

        $from = '2026-07-01';
        $to = '2026-09-01';
        $context = $dashboardContext->resolve($tenant, $owner, ['dateFrom' => $from, 'dateTo' => $to, 'comparison' => 'none']);
        $request = Request::create('/console/finance-demo-verify', 'GET');
        $request->attributes->set('tenant_id', $tenant);
        $request->attributes->set('auth_user', User::query()->where('tenant_id', $tenant)->findOrFail($owner));
        $reportContext = $reports->context($tenant, $owner, ['dateFrom' => $from, 'dateTo' => $to, 'comparison' => 'none']);
        $cashAccount = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $supplier = (int) DB::table('suppliers')->where('tenant_id', $tenant)->where('email', 'beans-demo@supplier.local')->value('id');
        $reconciliation = (int) DB::table('financial_reconciliations')->where('tenant_id', $tenant)->where('status', 'completed')->value('id');
        $closing = DB::table('daily_closings')->where('tenant_id', $tenant)->where('status', 'closed')->first();
        $period = DB::table('accounting_periods')->where('tenant_id', $tenant)->where('status', 'closed')->first();
        if (! $cashAccount || ! $supplier || ! $reconciliation || ! $closing || ! $period) {
            $this->components->error('Required demo records are incomplete.');
            return self::FAILURE;
        }

        $checks = [
            'dashboard' => fn () => $dashboard->summary($request, $context),
            'profitAndLoss' => fn () => $reports->profitAndLoss($reportContext),
            'balanceSheet' => fn () => $reports->balanceSheet($reportContext, $to),
            'cashFlow' => fn () => $reports->cashFlow($reportContext),
            'trialBalance' => fn () => $reports->trialBalance($reportContext),
            'generalLedger' => fn () => $reports->generalLedger($reportContext, $cashAccount),
            'supplierAging' => fn () => $reports->supplierAging($reportContext, $to),
            'supplierStatement' => fn () => $reports->supplierStatement($reportContext, $supplier),
            'reconciliationDetail' => fn () => $reconciliations->detail($tenant, $owner, $reconciliation),
            'dailyClosingDetail' => fn () => $closings->present($tenant, (int) $closing->branch_id, $closing->business_date, $closing),
            'accountingPeriodDetail' => fn () => (array) $period,
        ];

        foreach ($checks as $name => $check) {
            $check();
            $this->line($name.': PASS');
        }

        return self::SUCCESS;
    }
}
