<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PosStateController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $data = $request->validate([
            'branchId' => ['required', 'integer', 'exists:branches,id'],
        ]);

        $tenantId = TenantContext::id($request);
        $shift = DB::table('shifts')
            ->where('tenant_id', $tenantId)
            ->where('branch_id', $data['branchId'])
            ->where('status', 'open')
            ->latest('opened_at')
            ->first();

        $unavailableProducts = DB::table('products')
            ->join('categories', 'categories.id', '=', 'products.category_id')
            ->where('products.tenant_id', $tenantId)
            ->where('products.is_active', false)
            ->whereNull('products.deleted_at')
            ->select(['products.id', 'products.name', 'products.price', 'categories.name as category'])
            ->limit(10)
            ->get()
            ->map(fn ($product) => [
                'id' => $product->id,
                'name' => $product->name,
                'category' => $product->category,
                'price' => (float) $product->price,
                'severity' => 'warning',
                'message' => 'Product is currently unavailable.',
            ]);

        return response()->json([
            'data' => [
                'branchId' => (int) $data['branchId'],
                'terminal' => [
                    'status' => $shift ? 'open' : 'closed',
                    'message' => $shift
                        ? 'Terminal is ready for orders.'
                        : 'POS station is closed. Open a shift before taking orders.',
                ],
                'currentShift' => $shift ? [
                    'id' => $shift->id,
                    'openedAt' => $shift->opened_at,
                    'openingCash' => (float) $shift->opening_cash,
                ] : null,
                'currentOrder' => [
                    'status' => 'empty',
                    'message' => 'Cart is empty.',
                ],
                'alerts' => $unavailableProducts,
            ],
        ]);
    }
}
