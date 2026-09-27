<?php
namespace App\Http\Controllers\Api\Manufacturing;
use App\Http\Controllers\Controller;
use App\Support\FactoryWarehouseScope;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
final class ManufacturingIngredientController extends Controller {
    public function index(Request $request) {
        $tenant = TenantContext::id($request); $branch = (int) $request->input('branchId');
        FactoryWarehouseScope::assertFactoryBranch($tenant, $branch);
        FinancialActor::assertBranchAccess(FinancialActor::id($request, $tenant), $tenant, $branch);
        $warehouse = app(\App\Services\FactoryInventoryWarehouseResolver::class)->forBranch($tenant, $branch);
        $q = DB::table('inventory_items as i')->leftJoin('stock_balances as b', function ($join) use ($tenant, $warehouse) { $join->on('b.inventory_item_id', '=', 'i.id')->where('b.tenant_id', $tenant)->where('b.warehouse_id', $warehouse->id); })
            ->where('i.tenant_id', $tenant)->where('i.owner_branch_id', $branch)->where('i.is_active', true)->whereNull('i.deleted_at')
            ->whereIn('i.item_type', $request->input('types', ['raw_material', 'packaging', 'semi_finished_good']));
        if ($request->filled('search')) { $search = '%'.$request->input('search').'%'; $q->where(fn ($s) => $s->where('i.name_ar', 'ilike', $search)->orWhere('i.name_en', 'ilike', $search)->orWhere('i.sku', 'ilike', $search)); }
        $rows = $q->select('i.*')->selectRaw('COALESCE(b.quantity_on_hand - b.reserved_quantity, 0) as available_quantity, COALESCE(b.average_unit_cost, 0) as average_cost')->orderBy('i.id')->paginate(min(100, max(1, (int) $request->input('perPage', 30))));
        return response()->json(['data' => collect($rows->items())->map(fn ($i) => ['id' => (int) $i->id, 'sku' => $i->sku, 'nameAr' => $i->name_ar, 'nameEn' => $i->name_en, 'itemType' => $i->item_type, 'unit' => $i->unit, 'isActive' => true, 'ownerBranchId' => $branch, 'availableQuantity' => (string) $i->available_quantity, 'totalQuantity' => (string) $i->available_quantity, 'latestUnitCost' => (string) $i->average_cost, 'averageCost' => (string) $i->average_cost]), 'meta' => ['currentPage' => $rows->currentPage(), 'lastPage' => $rows->lastPage(), 'total' => $rows->total()]]);
    }
}
