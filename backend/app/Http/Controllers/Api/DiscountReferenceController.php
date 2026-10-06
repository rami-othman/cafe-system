<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\DiscountProductVariantService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class DiscountReferenceController extends Controller
{
    public function products(Request $request): JsonResponse
    {
        $query = DB::table('products')->where('tenant_id', TenantContext::id($request))->where('is_active', true)->whereNull('deleted_at');

        return $this->page($request, $query);
    }

    public function variants(Request $request, int $product): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        abort_unless(DB::table('products')->where('tenant_id', $tenantId)->where('id', $product)->where('is_active', true)->whereNull('deleted_at')->exists(), 404);
        $query = DB::table('product_variants')->where('tenant_id', $tenantId)->where('product_id', $product)->where('is_active', true)->whereNull('deleted_at');

        return $this->page($request, $query);
    }

    private function page(Request $request, $query): JsonResponse
    {
        $data = $request->validate(['search' => ['sometimes', 'string', 'max:100'], 'perPage' => ['sometimes', 'integer', 'between:1,100'], 'page' => ['sometimes', 'integer', 'min:1']]);
        if (isset($data['search'])) {
            $search = '%'.mb_strtolower(trim($data['search'])).'%';
            $query->where(function ($query) use ($search): void {
                $query->whereRaw('LOWER(name) LIKE ?', [$search])->orWhereRaw("LOWER(COALESCE(name_ar, '')) LIKE ?", [$search])->orWhereRaw("LOWER(COALESCE(name_en, '')) LIKE ?", [$search]);
            });
        }
        $page = $query->orderBy('name')->orderBy('id')->paginate($data['perPage'] ?? 20, ['id', 'name', 'name_ar', 'name_en', 'is_active', 'deleted_at']);

        return response()->json(['data' => array_map(DiscountProductVariantService::selector(...), $page->items()),
            'meta' => ['currentPage' => $page->currentPage(), 'lastPage' => $page->lastPage(), 'perPage' => $page->perPage(), 'total' => $page->total()]]);
    }
}
