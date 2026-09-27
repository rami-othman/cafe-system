<?php
namespace App\Http\Controllers\Api;
use App\Http\Controllers\Controller;
use App\Services\CustomerReceivableQueryService;
use App\Services\SupplierPayableQueryService;
use App\Support\FinanceAccess;
use App\Support\Money;
use App\Support\TenantContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
final class InternalReconciliationController extends Controller {
    public function index(Request $request, CustomerReceivableQueryService $ar, SupplierPayableQueryService $ap) {
        abort_unless(FinanceAccess::actor($request)->isOwner(), 403);
        $request->merge(['includeInternal' => true]);
        $tenant = TenantContext::id($request); $date = now()->toDateString(); $result = [];
        foreach (DB::table('customers')->where('tenant_id', $tenant)->where('is_internal', true)->whereNull('deleted_at')->get() as $customer) {
            $supplier = DB::table('suppliers')->where('tenant_id', $tenant)->where('is_internal', true)->where('internal_branch_id', $customer->owner_branch_id)->whereNull('owner_branch_id')->whereNull('deleted_at')->first();
            $receivable = array_sum(array_column($ar->invoicesAsOf($tenant, $date, (int) $customer->owner_branch_id, [], (int) $customer->id), 'remainingCents'));
            $payable = $supplier ? array_sum(array_column($ap->invoicesAsOf($tenant, $date, (int) $customer->internal_branch_id, [], (int) $supplier->id), 'remainingCents')) : 0;
            $result[] = ['factoryBranchId' => (int) $customer->owner_branch_id, 'cafeBranchId' => (int) $customer->internal_branch_id, 'customerId' => (int) $customer->id, 'supplierId' => $supplier ? (int) $supplier->id : null, 'factoryReceivable' => Money::decimal($receivable), 'cafePayable' => Money::decimal($payable), 'difference' => Money::decimal($receivable - $payable)];
        }
        return response()->json(['data' => $result]);
    }
}
