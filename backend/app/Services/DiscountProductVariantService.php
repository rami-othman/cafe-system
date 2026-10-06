<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Variant rows refine the existing parent product target; they never replace it. */
final class DiscountProductVariantService
{
    public function validate(int $tenantId, array $data): void
    {
        if (! array_key_exists('productVariantSelections', $data)) {
            return;
        }
        $fail = fn () => throw ValidationException::withMessages(['productVariantSelections' => 'Provide one valid variant selection per target product.']);
        $selections = $data['productVariantSelections'];
        if ($data['scope'] !== 'product' || ! is_array($selections) || ! array_is_list($selections)) {
            $fail();
        }
        $products = array_map('intval', $data['targetProductIds'] ?? []);
        $seen = [];
        foreach ($selections as $entry) {
            if (! is_array($entry) || count($entry) !== 3 || ! isset($entry['productId'], $entry['variantMode'], $entry['variantIds'])
                || ! $this->validId($entry['productId'])
                || ! in_array($entry['variantMode'], ['all', 'selected'], true)
                || ! is_array($entry['variantIds']) || ! array_is_list($entry['variantIds'])) {
                $fail();
            }
            $product = (int) $entry['productId'];
            if (! in_array($product, $products, true) || isset($seen[$product])) {
                $fail();
            }
            $seen[$product] = true;
            $ids = [];
            foreach ($entry['variantIds'] as $id) {
                if (! $this->validId($id) || in_array((int) $id, $ids, true)) {
                    $fail();
                }
                $ids[] = (int) $id;
            }
            if (($entry['variantMode'] === 'all' && $ids) || ($entry['variantMode'] === 'selected' && ! $ids)) {
                $fail();
            }
            if ($ids && DB::table('product_variants')->where('tenant_id', $tenantId)->where('product_id', $product)
                ->where('is_active', true)->whereNull('deleted_at')->whereIn('id', $ids)->count() !== count($ids)) {
                $fail();
            }
        }
        if (count($seen) !== count($products)) {
            $fail();
        }
    }

    private function validId(mixed $id): bool
    {
        return (is_int($id) || is_string($id)) && filter_var($id, FILTER_VALIDATE_INT) !== false && (int) $id > 0;
    }

    public function savedIds(int $tenantId, int $discountId): array
    {
        return DB::table('discount_product_target_variants')->where('tenant_id', $tenantId)->where('discount_id', $discountId)
            ->orderBy('product_variant_id')->get()->groupBy('product_id')->map(fn ($rows) => $rows->pluck('product_variant_id')->map(fn ($id) => (int) $id)->all())->all();
    }

    public function persist(int $tenantId, int $discountId, array $data, array $saved): void
    {
        if ($data['scope'] !== 'product') {
            return;
        }
        $idsByProduct = array_key_exists('productVariantSelections', $data)
            ? collect($data['productVariantSelections'])->mapWithKeys(fn ($entry) => [(int) $entry['productId'] => $entry['variantIds']])->all()
            : $saved;
        $parents = DB::table('discount_targets')->where('tenant_id', $tenantId)->where('discount_id', $discountId)->where('target_type', 'product')->get();
        foreach ($parents as $parent) {
            foreach ($idsByProduct[$parent->target_id] ?? [] as $variantId) {
                DB::table('discount_product_target_variants')->insert([
                    'tenant_id' => $tenantId, 'discount_id' => $discountId, 'product_id' => $parent->target_id,
                    'discount_target_id' => $parent->id, 'product_variant_id' => $variantId, 'target_type' => 'product',
                    'created_at' => now(), 'updated_at' => now(),
                ]);
            }
        }
    }

    public function detail(int $tenantId, int $discountId, array $productIds): array
    {
        $saved = $this->savedIds($tenantId, $discountId);
        $products = DB::table('products')->where('tenant_id', $tenantId)->whereIn('id', $productIds)->get()->keyBy('id');
        $variants = DB::table('product_variants')->where('tenant_id', $tenantId)->whereIn('id', collect($saved)->flatten()->all())->get()->keyBy('id');

        return array_map(function ($productId) use ($saved, $variants, $products): array {
            $ids = $saved[$productId] ?? [];

            return ['productId' => $productId, 'variantMode' => $ids ? 'selected' : 'all', 'variantIds' => $ids,
                'product' => isset($products[$productId]) ? self::selector($products[$productId]) : ['id' => $productId, 'name' => null, 'nameAr' => null, 'nameEn' => null, 'isActive' => false, 'archivedAt' => null],
                'variants' => array_map(fn ($id) => self::selector($variants[$id]), $ids)];
        }, $productIds);
    }

    public static function selector(object $row): array
    {
        return ['id' => (int) $row->id, 'name' => $row->name, 'nameAr' => $row->name_ar, 'nameEn' => $row->name_en,
            'isActive' => (bool) $row->is_active, 'archivedAt' => $row->deleted_at];
    }
}
