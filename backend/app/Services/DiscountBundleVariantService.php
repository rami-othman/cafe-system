<?php

namespace App\Services;

use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Variant refinement of a Package / Bundle requirement. Mirrors
 * DiscountProductVariantService: a requirement without stored variant rows
 * means "all variants", so legacy requirements need no backfill.
 */
final class DiscountBundleVariantService
{
    public const MODES = ['all', 'selected'];

    /** @param array<string, mixed> $data validated management payload */
    public function validate(int $tenantId, array $data): void
    {
        foreach (array_values($data['bundleRequirements'] ?? []) as $index => $entry) {
            $key = "bundleRequirements.$index.variantIds";
            $fail = fn (string $message) => throw ValidationException::withMessages([$key => $message]);
            $hasMode = array_key_exists('variantMode', $entry);
            $hasIds = array_key_exists('variantIds', $entry);
            if (! $hasMode && ! $hasIds) {
                continue; // Legacy client: saved selection is preserved on update.
            }
            if (! $hasMode || ! in_array($entry['variantMode'], self::MODES, true)) {
                $fail('Provide variantMode as all or selected.');
            }
            $rawIds = $hasIds ? $entry['variantIds'] : [];
            if (! is_array($rawIds) || ! array_is_list($rawIds)) {
                $fail('variantIds must be a list.');
            }
            $ids = [];
            foreach ($rawIds as $id) {
                if (! $this->validId($id)) {
                    $fail('Variant ids must be positive integers.');
                }
                if (in_array((int) $id, $ids, true)) {
                    $fail('Variant ids must not repeat.');
                }
                $ids[] = (int) $id;
            }
            if ($entry['variantMode'] === 'all' && $ids) {
                $fail('All-variant requirements cannot list variant ids.');
            }
            if ($entry['variantMode'] === 'selected' && ! $ids) {
                $fail('Selected-variant requirements need at least one variant.');
            }
            if ($ids && DB::table('product_variants')->where('tenant_id', $tenantId)->where('product_id', (int) $entry['productId'])
                ->where('is_active', true)->whereNull('deleted_at')->whereIn('id', $ids)->count() !== count($ids)) {
                $fail('One or more variants are inactive, archived or do not belong to the required product of this tenant.');
            }
        }
    }

    /** @return array<int, int[]> saved variant ids keyed by required product id */
    public function savedIds(int $tenantId, int $discountId): array
    {
        return DB::table('discount_bundle_requirement_variants')->where('tenant_id', $tenantId)->where('discount_id', $discountId)
            ->orderBy('product_variant_id')->get()->groupBy('product_id')
            ->map(fn ($rows) => $rows->pluck('product_variant_id')->map(fn ($id) => (int) $id)->all())->all();
    }

    /** Whether an order line's variant satisfies a requirement's saved selection. */
    public static function accepts(array $selectedIds, mixed $variantId): bool
    {
        return $selectedIds === [] || ($variantId !== null && in_array((int) $variantId, $selectedIds, true));
    }

    /**
     * Inserts the requirement rows and their variant refinements. $saved is the
     * selection captured before the rows were replaced; it is kept for entries
     * from clients that do not send variant fields.
     *
     * @param  array<int, int[]>  $saved
     */
    public function persist(int $tenantId, int $discountId, array $data, array $saved): void
    {
        $now = now();
        foreach ($data['bundleRequirements'] ?? [] as $entry) {
            $productId = (int) $entry['productId'];
            $requirementId = DB::table('discount_bundle_requirements')->insertGetId([
                'tenant_id' => $tenantId, 'discount_id' => $discountId, 'product_id' => $productId,
                'quantity' => $entry['quantity'], 'created_at' => $now, 'updated_at' => $now,
            ]);
            $ids = array_key_exists('variantMode', $entry)
                ? array_map('intval', $entry['variantIds'] ?? [])
                : ($saved[$productId] ?? []);
            foreach ($ids as $variantId) {
                DB::table('discount_bundle_requirement_variants')->insert([
                    'tenant_id' => $tenantId, 'discount_id' => $discountId, 'product_id' => $productId,
                    'product_variant_id' => $variantId, 'discount_bundle_requirement_id' => $requirementId,
                    'created_at' => $now, 'updated_at' => $now,
                ]);
            }
        }
    }

    /** @return array{variantMode: string, variantIds: int[], variants: array<int, array<string, mixed>>} */
    public function detail(array $saved, int $productId, Collection $variantRows): array
    {
        $ids = $saved[$productId] ?? [];

        return [
            'variantMode' => $ids ? 'selected' : 'all',
            'variantIds' => $ids,
            'variants' => array_map(fn ($id) => $variantRows->has($id) ? DiscountProductVariantService::selector($variantRows[$id]) : ['id' => $id, 'name' => null, 'nameAr' => null, 'nameEn' => null, 'isActive' => false, 'archivedAt' => null], $ids),
        ];
    }

    /** @param array<int, int[]> $saved */
    public function variantRows(int $tenantId, array $saved): Collection
    {
        return DB::table('product_variants')->where('tenant_id', $tenantId)->whereIn('id', collect($saved)->flatten()->all())->get()->keyBy('id');
    }

    private function validId(mixed $id): bool
    {
        return (is_int($id) || is_string($id)) && filter_var($id, FILTER_VALIDATE_INT) !== false && (int) $id > 0;
    }
}
