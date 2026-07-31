<?php

namespace App\Http\Controllers\Api\Admin\Catalog;

use App\Http\Controllers\Controller;
use App\Http\Resources\Catalog\ProductDetailResource;
use App\Http\Resources\Catalog\ProductModifierGroupResource;
use App\Http\Resources\Catalog\ProductSummaryResource;
use App\Http\Resources\Catalog\ProductVariantResource;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Services\Catalog\CatalogProductService;
use App\Services\Catalog\ProductModifierAssignmentService;
use App\Services\Catalog\ProductVariantService;
use App\Support\TenantContext;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ProductCatalogController extends Controller
{
    public function __construct(private readonly CatalogProductService $products, private readonly ProductVariantService $variants, private readonly ProductModifierAssignmentService $assignments) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $query = Product::query()->where('tenant_id', $tenant)->with(['category', 'reportingCategory', 'kitchenStation', 'defaultVariant'])->withCount(['variants' => fn ($q) => $q->where('is_active', true), 'modifierGroups']);
        $status = $request->query('status', 'active');
        if ($status === 'all') {
            $query->withTrashed();
        } elseif ($status === 'archived') {
            $query->onlyTrashed();
        } else {
            $query->where('is_active', true);
        }
        foreach (['categoryId' => 'category_id', 'reportingCategoryId' => 'reporting_category_id', 'kitchenStationId' => 'kitchen_station_id', 'productType' => 'product_type'] as $key => $column) {
            if ($request->filled($key)) {
                $query->where($column, $request->query($key));
            }
        }
        if ($request->has('hasVariants')) {
            $request->boolean('hasVariants') ? $query->has('variants') : $query->doesntHave('variants');
        } if ($request->has('hasModifierGroups')) {
            $request->boolean('hasModifierGroups') ? $query->has('modifierGroups') : $query->doesntHave('modifierGroups');
        }
        if ($request->filled('search')) {
            $search = '%'.strtolower($request->query('search')).'%';
            $query->where(function (Builder $q) use ($search) {
                $q->whereRaw('LOWER(name) LIKE ?', [$search])->orWhereRaw('LOWER(COALESCE(name_ar, \'\')) LIKE ?', [$search])->orWhereRaw('LOWER(COALESCE(name_en, \'\')) LIKE ?', [$search])->orWhereRaw('LOWER(COALESCE(sku, \'\')) LIKE ?', [$search])->orWhereRaw('LOWER(COALESCE(barcode, \'\')) LIKE ?', [$search])->orWhereHas('variants', fn ($v) => $v->whereRaw('LOWER(name) LIKE ? OR LOWER(COALESCE(sku, \'\')) LIKE ? OR LOWER(COALESCE(barcode, \'\')) LIKE ?', [$search, $search, $search]));
            });
        }
        $sort = in_array($request->query('sort'), ['name', 'sort_order', 'created_at'], true) ? $request->query('sort') : 'sort_order';
        $page = $query->orderBy($sort, $request->query('direction') === 'desc' ? 'desc' : 'asc')->orderBy('id')->paginate(min((int) $request->query('perPage', 20), 100));

        return response()->json(['data' => collect($page->items())->map(fn ($product) => (new ProductSummaryResource($product))->resolve($request)), 'meta' => ['currentPage' => $page->currentPage(), 'lastPage' => $page->lastPage(), 'perPage' => $page->perPage(), 'total' => $page->total()]]);
    }

    public function show(Request $request, int $product): JsonResponse
    {
        return response()->json(['data' => (new ProductDetailResource($this->findProduct(TenantContext::id($request), $product, $request->boolean('includeArchived'))))->resolve($request)]);
    }

    public function store(Request $request): JsonResponse
    {
        $product = $this->products->create(TenantContext::id($request), $this->productData($request, true));

        return response()->json(['data' => (new ProductDetailResource($product))->resolve($request)], 201);
    }

    public function update(Request $request, int $product): JsonResponse
    {
        $model = $this->findProduct(TenantContext::id($request), $product);
        $updated = $this->products->update($model, $this->productData($request, false, $model));

        return response()->json(['data' => (new ProductDetailResource($updated))->resolve($request)]);
    }

    public function archive(Request $request, int $product): JsonResponse
    {
        $model = $this->products->archive($this->findProduct(TenantContext::id($request), $product));

        return response()->json(['message' => 'Product archived successfully.', 'data' => (new ProductDetailResource($model))->resolve($request)]);
    }

    public function restore(Request $request, int $product): JsonResponse
    {
        $model = $this->products->restore($this->findProduct(TenantContext::id($request), $product, true));

        return response()->json(['message' => 'Product restored successfully.', 'data' => (new ProductDetailResource($model))->resolve($request)]);
    }

    public function storeVariant(Request $request, int $product): JsonResponse
    {
        $variant = $this->variants->create($this->findProduct(TenantContext::id($request), $product), $this->variantData($request, true));

        return response()->json(['data' => (new ProductVariantResource($variant))->resolve($request)], 201);
    }

    public function updateVariant(Request $request, int $variant): JsonResponse
    {
        $model = $this->findVariant(TenantContext::id($request), $variant);
        $merged = array_replace($this->variantCurrent($model), $this->variantData($request, false));

        return response()->json(['data' => (new ProductVariantResource($this->variants->update($model, $merged)))->resolve($request)]);
    }

    public function setDefaultVariant(Request $request, int $variant): JsonResponse
    {
        return response()->json(['data' => (new ProductVariantResource($this->variants->setDefault($this->findVariant(TenantContext::id($request), $variant))))->resolve($request)]);
    }

    public function archiveVariant(Request $request, int $variant): JsonResponse
    {
        $data = $request->validate(['replacementDefaultVariantId' => ['nullable', 'integer']]);
        $model = $this->variants->archive($this->findVariant(TenantContext::id($request), $variant), $data['replacementDefaultVariantId'] ?? null);

        return response()->json(['message' => 'Product variant archived successfully.', 'data' => (new ProductVariantResource($model))->resolve($request)]);
    }

    public function restoreVariant(Request $request, int $variant): JsonResponse
    {
        $data = $request->validate(['makeDefault' => ['nullable', 'boolean']]);
        $model = $this->variants->restore($this->findVariant(TenantContext::id($request), $variant, true), $data['makeDefault'] ?? false);

        return response()->json(['message' => 'Product variant restored successfully.', 'data' => (new ProductVariantResource($model))->resolve($request)]);
    }

    public function reorderVariants(Request $request, int $product): JsonResponse
    {
        $data = $request->validate(['items' => ['required', 'array'], 'items.*.id' => ['required', 'integer'], 'items.*.sortOrder' => ['required', 'integer']]);
        $this->variants->reorder($this->findProduct(TenantContext::id($request), $product), $data['items']);

        return response()->json(['message' => 'Product variants reordered successfully.', 'data' => $data['items']]);
    }

    public function modifierGroups(Request $request, int $product): JsonResponse
    {
        $model = $this->findProduct(TenantContext::id($request), $product);

        return response()->json(['data' => ProductModifierGroupResource::collection($model->modifierGroups()->with('options')->orderByPivot('sort_order')->get())->resolve($request)]);
    }

    public function syncModifierGroups(Request $request, int $product): JsonResponse
    {
        $data = $request->validate(['groups' => ['required', 'array'], 'groups.*.modifierGroupId' => ['required', 'integer'], 'groups.*.sortOrder' => ['required', 'integer'], 'groups.*.isRequiredOverride' => ['nullable', 'boolean'], 'groups.*.minSelectionsOverride' => ['nullable', 'integer', 'min:0'], 'groups.*.maxSelectionsOverride' => ['nullable', 'integer', 'min:0'], 'groups.*.allowQuantityOverride' => ['nullable', 'boolean']]);
        $model = $this->findProduct(TenantContext::id($request), $product);
        $this->assignments->sync($model, $data['groups']);

        return $this->modifierGroups($request, $product);
    }

    private function findProduct(int $tenant, int $id, bool $trashed = false): Product
    {
        return Product::query()->when($trashed, fn ($q) => $q->withTrashed())->where('tenant_id', $tenant)->with(['category', 'reportingCategory', 'kitchenStation', 'variants' => fn ($q) => $q->where('tenant_id', $tenant)->when($trashed, fn ($variants) => $variants->withTrashed())->orderBy('sort_order')->orderBy('id'), 'variants.product', 'defaultVariant', 'modifierGroups.options'])->findOrFail($id);
    }

    private function findVariant(int $tenant, int $id, bool $trashed = false): ProductVariant
    {
        return ProductVariant::query()->when($trashed, fn ($q) => $q->withTrashed())->where('tenant_id', $tenant)->with('product')->findOrFail($id);
    }

    private function productData(Request $request, bool $create, ?Product $current = null): array
    {
        $rules = ['name' => [$create ? 'required' : 'sometimes', 'string', 'max:255'], 'nameAr' => ['nullable', 'string'], 'nameEn' => ['nullable', 'string'], 'description' => ['nullable', 'string'], 'descriptionAr' => ['nullable', 'string'], 'descriptionEn' => ['nullable', 'string'], 'imageUrl' => ['nullable', 'string', 'max:255'], 'categoryId' => ['nullable', 'integer'], 'reportingCategoryId' => ['nullable', 'integer'], 'kitchenStationId' => ['nullable', 'integer'], 'productType' => ['nullable', Rule::in(['standard', 'open_price', 'combo'])], 'preparationTimeMinutes' => ['nullable', 'integer', 'min:0', 'max:1440'], 'isStockTracked' => ['nullable', 'boolean'], 'isActive' => ['nullable', 'boolean'], 'sortOrder' => ['nullable', 'integer']];
        if ($create) {
            $rules += ['variants' => ['required', 'array', 'min:1'], 'variants.*.name' => ['required', 'string'], 'variants.*.sku' => ['nullable', 'string'], 'variants.*.barcode' => ['nullable', 'string'], 'variants.*.basePrice' => ['required', 'numeric', 'min:0'], 'variants.*.costPrice' => ['nullable', 'numeric', 'min:0'], 'variants.*.isDefault' => ['required', 'boolean'], 'variants.*.isActive' => ['required', 'boolean'], 'variants.*.sortOrder' => ['nullable', 'integer']];
        } $data = $request->validate($rules);
        if (! $create) {
            $data = array_replace(['name' => $current->name, 'nameAr' => $current->name_ar, 'nameEn' => $current->name_en, 'description' => $current->description, 'descriptionAr' => $current->description_ar, 'descriptionEn' => $current->description_en, 'imageUrl' => $current->image_url, 'productType' => $current->product_type->value, 'preparationTimeMinutes' => $current->preparation_time_minutes, 'isStockTracked' => $current->is_stock_tracked, 'sortOrder' => $current->sort_order, 'categoryId' => $current->category_id, 'reportingCategoryId' => $current->reporting_category_id, 'kitchenStationId' => $current->kitchen_station_id], $data);
        }

        return $data;
    }

    private function variantData(Request $request, bool $create): array
    {
        return $request->validate(['name' => [$create ? 'required' : 'sometimes', 'string'], 'nameAr' => ['nullable', 'string'], 'nameEn' => ['nullable', 'string'], 'sku' => ['nullable', 'string'], 'barcode' => ['nullable', 'string'], 'basePrice' => [$create ? 'required' : 'sometimes', 'numeric', 'min:0'], 'costPrice' => ['nullable', 'numeric', 'min:0'], 'isDefault' => ['nullable', 'boolean'], 'isActive' => ['nullable', 'boolean'], 'sortOrder' => ['nullable', 'integer']]);
    }

    private function variantCurrent(ProductVariant $v): array
    {
        return ['name' => $v->name, 'nameAr' => $v->name_ar, 'nameEn' => $v->name_en, 'sku' => $v->sku, 'barcode' => $v->barcode, 'basePrice' => $v->base_price, 'costPrice' => $v->cost_price, 'isDefault' => $v->is_default, 'isActive' => $v->is_active, 'sortOrder' => $v->sort_order];
    }
}
