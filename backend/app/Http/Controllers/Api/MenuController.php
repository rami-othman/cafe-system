<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class MenuController extends Controller
{
    public function categories(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        $categories = DB::table('categories')
            ->where('tenant_id', $tenantId)
            ->where('is_active', true)
            ->whereNull('deleted_at')
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get()
            ->map(fn ($category) => [
                'id' => $category->id,
                'name' => $category->name,
                'description' => $category->description,
                'sortOrder' => $category->sort_order,
            ]);

        return response()->json(['data' => $categories]);
    }

    public function products(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $availability = $request->query('availability', 'available');

        $query = DB::table('products')
            ->leftJoin('categories', 'categories.id', '=', 'products.category_id')
            ->where('products.tenant_id', $tenantId)
            ->whereNull('products.deleted_at')
            ->select([
                'products.id',
                'products.category_id',
                'products.name',
                'products.description',
                'products.price',
                'products.image_url',
                'products.is_active',
                'products.sort_order',
                'categories.name as category_name',
            ]);

        if ($request->filled('categoryId')) {
            $query->where('products.category_id', (int) $request->query('categoryId'));
        }

        if ($request->filled('search')) {
            $search = '%'.$request->query('search').'%';
            $query->where(fn ($q) => $q->where('products.name', 'like', $search)->orWhere('products.sku', 'like', $search));
        }

        if ($availability === 'available') {
            $query->where('products.is_active', true);
        } elseif ($availability === 'unavailable') {
            $query->where('products.is_active', false);
        }

        $products = $query->orderBy('products.sort_order')->orderBy('products.name')->get()
            ->map(fn ($product) => $this->productSummary($product));

        return response()->json(['data' => $products]);
    }

    public function product(Request $request, int $product): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        $row = DB::table('products')
            ->where('tenant_id', $tenantId)
            ->where('id', $product)
            ->whereNull('deleted_at')
            ->first();

        abort_if(! $row, 404, 'Product not found.');

        $groups = DB::table('product_modifier_group')
            ->join('modifier_groups', 'modifier_groups.id', '=', 'product_modifier_group.modifier_group_id')
            ->where('product_modifier_group.tenant_id', $tenantId)
            ->where('product_modifier_group.product_id', $product)
            ->where('modifier_groups.is_active', true)
            ->whereNull('modifier_groups.deleted_at')
            ->orderBy('product_modifier_group.sort_order')
            ->select('modifier_groups.*')
            ->get()
            ->map(function ($group) use ($tenantId) {
                $options = DB::table('modifier_options')
                    ->where('tenant_id', $tenantId)
                    ->where('modifier_group_id', $group->id)
                    ->whereNull('deleted_at')
                    ->orderBy('sort_order')
                    ->get()
                    ->map(fn ($option) => [
                        'id' => $option->id,
                        'name' => $option->name,
                        'priceDelta' => (float) $option->price_delta,
                        'isDefault' => (bool) $option->is_default,
                        'isAvailable' => (bool) $option->is_available,
                    ]);

                return [
                    'id' => $group->id,
                    'name' => $group->name,
                    'type' => $group->selection_type,
                    'required' => (bool) $group->is_required,
                    'minSelections' => $group->min_selections,
                    'maxSelections' => $group->max_selections,
                    'sortOrder' => $group->sort_order,
                    'options' => $options,
                ];
            });

        return response()->json([
            'data' => array_merge($this->productSummary($row), ['modifierGroups' => $groups]),
        ]);
    }

    private function productSummary(object $product): array
    {
        return [
            'id' => $product->id,
            'categoryId' => $product->category_id,
            'categoryName' => property_exists($product, 'category_name') ? $product->category_name : null,
            'name' => $product->name,
            'description' => $product->description,
            'imageUrl' => $product->image_url,
            'basePrice' => (float) $product->price,
            'isAvailable' => (bool) $product->is_active,
            'sortOrder' => $product->sort_order,
        ];
    }
}
