<?php

namespace App\Http\Controllers\Api\Admin\Catalog;

use App\Http\Controllers\Controller;
use App\Models\ModifierOption;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Services\Catalog\MaterialCatalogService;
use App\Services\Catalog\RecipeConfigurationService;
use App\Services\Catalog\RecipeResolver;
use App\Support\TenantContext;
use Illuminate\Http\Request;

class RecipeConfigurationController extends Controller
{
    public function __construct(private readonly MaterialCatalogService $materials, private readonly RecipeConfigurationService $recipes, private readonly RecipeResolver $resolver) {}

    public function materials(Request $r)
    {
        return response()->json(['data' => $this->materials->list(TenantContext::id($r), $r->query('status', 'active'), $r->query('search'))]);
    }

    public function recipe(Request $r, int $variant)
    {
        $v = $this->variant($r, $variant);

        return response()->json(['data' => $this->recipes->recipe($v)]);
    }

    public function putRecipe(Request $r, int $variant)
    {
        $d = $r->validate(['components' => ['present', 'array'], 'components.*.materialId' => ['required', 'integer'], 'components.*.quantity' => ['required'], 'components.*.unitCode' => ['required', 'string'], 'components.*.sortOrder' => ['nullable', 'integer']]);

        return response()->json(['data' => $this->recipes->replaceRecipe($this->variant($r, $variant), $d['components'])]);
    }

    public function resolve(Request $r, int $variant)
    {
        $d = $r->validate(['selectedOptions' => ['present', 'array'], 'selectedOptions.*.optionId' => ['required', 'integer'], 'selectedOptions.*.quantity' => ['nullable', 'integer', 'min:1']]);

        return response()->json(['data' => $this->resolver->resolve($this->variant($r, $variant), $d['selectedOptions'])]);
    }

    public function profile(Request $r)
    {
        return response()->json(['data' => $this->recipes->profile($this->option($r, (int) $r->route('option')), $r->route('product') ? $this->product($r, (int) $r->route('product')) : null, $r->route('variant') ? $this->variant($r, (int) $r->route('variant')) : null)]);
    }

    public function putProfile(Request $r)
    {
        $d = $r->validate(['components' => ['present', 'array'], 'components.*.materialId' => ['required', 'integer'], 'components.*.operation' => ['required', 'in:add,remove'], 'components.*.quantity' => ['required'], 'components.*.unitCode' => ['required', 'string'], 'components.*.sortOrder' => ['nullable', 'integer']]);

        return response()->json(['data' => $this->recipes->replaceProfile($this->option($r, (int) $r->route('option')), $d['components'], $r->route('product') ? $this->product($r, (int) $r->route('product')) : null, $r->route('variant') ? $this->variant($r, (int) $r->route('variant')) : null)]);
    }

    public function deleteProfile(Request $r)
    {
        $this->recipes->deleteProfile($this->option($r, (int) $r->route('option')), $r->route('product') ? $this->product($r, (int) $r->route('product')) : null, $r->route('variant') ? $this->variant($r, (int) $r->route('variant')) : null);

        return response()->json(['message' => 'Recipe adjustment override removed.']);
    }

    private function variant(Request $r, int $id): ProductVariant
    {
        return ProductVariant::query()->where('tenant_id', TenantContext::id($r))->with('product')->findOrFail($id);
    }

    private function product(Request $r, int $id): Product
    {
        return Product::query()->where('tenant_id', TenantContext::id($r))->findOrFail($id);
    }

    private function option(Request $r, int $id): ModifierOption
    {
        return ModifierOption::query()->where('tenant_id', TenantContext::id($r))->with('modifierGroup')->findOrFail($id);
    }
}
