<?php

namespace App\Http\Middleware;

use App\Services\BranchAccessService;
use App\Services\DefaultTenantRoleService;
use App\Support\FinanceAccess;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

final class EnsureCashierOpenShift
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->isMethodSafe()) return $next($request);
        $actor = FinanceAccess::actor($request);
        if (app(DefaultTenantRoleService::class)->canonicalLegacyRole($actor->effectiveRoleCode()) !== 'cashier') {
            return $next($request);
        }
        $branchId = $this->targetBranch($request, (int) $actor->tenant_id);
        $query = DB::table('shifts')->where('tenant_id', $actor->tenant_id)
            ->where('user_id', $actor->id)->where('status', 'open')->whereNull('deleted_at')
            ->whereIn('branch_id', app(BranchAccessService::class)->accessibleBranchIds($actor));
        if ($branchId !== null) $query->where('branch_id', $branchId);
        if (! $query->exists()) {
            return response()->json([
                'message' => 'يجب فتح ورديتك في الفرع قبل إنشاء السندات أو تنفيذ العمليات المالية.',
                'code' => 'NO_OPEN_SHIFT',
                'errors' => ['shiftId' => ['يجب فتح وردية أولاً.']],
            ], 422);
        }

        return $next($request);
    }

    private function targetBranch(Request $request, int $tenant): ?int
    {
        // A submitted branchId cannot override an existing document's branch.
        foreach ([
            ['api/v1/orders/*', 'order', 'orders'],
            ['api/v1/finance/vouchers/*', 'document', 'finance_documents'],
            ['api/v1/finance/purchases/*', 'purchase', 'supplier_invoices'],
            ['api/v1/finance/supplier-invoices/*', 'invoice', 'supplier_invoices'],
            ['api/v1/finance/sales-invoices/*', 'invoice', 'sales_invoices'],
            ['api/v1/finance/purchase-receipts/*', 'receipt', 'purchase_receipts'],
        ] as [$path, $parameter, $table]) {
            $id = $request->route($parameter);
            if ($request->is($path) && $id !== null) {
                $branch = DB::table($table)->where('tenant_id', $tenant)->where('id', $id)->value('branch_id');
                if ($branch !== null) return (int) $branch;
            }
        }
        if ($request->filled('branchId')) return (int) $request->input('branchId');
        if ($request->filled('financialLocationId')) {
            $branch = DB::table('financial_locations')->where('tenant_id', $tenant)
                ->where('id', $request->input('financialLocationId'))->value('branch_id');
            if ($branch !== null) return (int) $branch;
        }

        return null;
    }
}
