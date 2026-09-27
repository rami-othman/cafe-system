<?php
namespace App\Support;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
final class ManufacturingRecordScope {
    public static function find(Request $request, int $tenant, string $table, int|string $id): object {
        $query = DB::table($table)->where('tenant_id', $tenant);
        $row = is_numeric($id) ? $query->where('id', $id)->first() : $query->where('reference', $id)->first();
        abort_unless($row, 404);
        FinancialActor::assertBranchAccess(FinancialActor::id($request, $tenant), $tenant, $row->branch_id ? (int) $row->branch_id : null);
        if ($request->filled('branchId')) abort_unless((int) $request->input('branchId') === (int) $row->branch_id, 404);
        return $row;
    }
}
