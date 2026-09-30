<?php

namespace App\Services\Menu;

use App\Domain\Menu\MenuPricingException;
use App\Models\MenuPriceAdjustment;
use App\Models\MenuPriceAdjustmentItem;
use App\Models\MenuVariantPrice;
use App\Models\ProductVariantPriceOverride;
use Brick\Math\BigDecimal;
use Brick\Math\RoundingMode;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class MenuPriceAdjustmentService
{
    private const MAX_PRICE = '9999999999.99';

    public function __construct(private readonly MenuPricingQueryService $query, private readonly MenuVariantPriceResolver $resolver) {}

    public function preview(int $tenantId, int $actorId, int $menuId, array $input): array
    {
        $input = $this->normalizeSettings($input);
        $context = $this->query->context($tenantId, $menuId, $input['branchId'], $input['channel']);
        $rows = $this->query->resolved($tenantId, $menuId, $context['branch']->id, $input['channel']);
        $operation = $input['operation'];
        $this->validateSettings($operation, $input);
        $targets = $operation === 'manual_changes' ? $this->manualTargets($rows, $input['items']) : $rows->where('adjustable', true)->values();
        if ($targets->isEmpty()) throw new MenuPricingException('MENU_PRICING_NO_ELIGIBLE_VARIANTS');
        $items = $targets->map(fn (array $row) => $this->item($row, $operation, $input, $operation === 'manual_changes' ? $this->manualAction($input['items'], $row['variant']->id) : null));
        $dependency = $this->query->fingerprint($operation === 'manual_changes' ? $targets : $rows);
        $summary = $this->summary($rows, $items, $operation, $input, $context);
        $expiresAt = now()->addMinutes(30);
        $summary['expiresAt'] = $expiresAt->toIso8601String();
        return DB::transaction(function () use ($tenantId, $actorId, $menuId, $input, $context, $operation, $dependency, $summary, $items, $expiresAt): array {
        $adjustment = MenuPriceAdjustment::query()->create(['tenant_id' => $tenantId, 'menu_id' => $menuId, 'branch_id' => $context['branch']->id, 'channel' => $input['channel'], 'actor_id' => $actorId,
            'operation' => $operation, 'amount' => $operation === 'manual_changes' ? null : $this->canonical($input['amount']), 'rounding_mode' => $operation === 'manual_changes' ? 'no_rounding' : $input['roundingMode'], 'rounding_step' => $operation === 'manual_changes' ? null : ($input['roundingStep'] ?? null),
            'status' => 'previewed', 'fingerprint' => hash('sha256', $tenantId.'|'.$menuId.'|'.microtime(true).'|'.random_bytes(16)), 'dependency_fingerprint' => $dependency, 'summary' => $summary, 'expires_at' => $expiresAt]);
        foreach ($items as $item) MenuPriceAdjustmentItem::query()->create(['tenant_id' => $tenantId, 'menu_price_adjustment_id' => $adjustment->id] + $item);
        return $this->present($adjustment->load('items'));
        });
    }

    public function show(int $tenantId, int $actorId, int $menuId, int $id): array
    {
        $adjustment = MenuPriceAdjustment::query()->where('tenant_id', $tenantId)->where('menu_id', $menuId)->with('items.variant.product')->findOrFail($id);
        if ((int) $adjustment->actor_id !== $actorId) throw new MenuPricingException('MENU_PRICING_ADJUSTMENT_ACTOR_MISMATCH', 409);
        return $this->present($adjustment);
    }

    public function apply(int $tenantId, int $actorId, int $menuId, int $id, array $input): array
    {
        return DB::transaction(function () use ($tenantId, $actorId, $menuId, $id, $input): array {
            DB::select('SELECT pg_advisory_xact_lock(hashtext(?))', ["menu-pricing:$tenantId:$menuId"]);
            $adjustment = MenuPriceAdjustment::query()->where('tenant_id', $tenantId)->where('menu_id', $menuId)->with('items.variant.product')->lockForUpdate()->findOrFail($id);
            if ((int) $adjustment->actor_id !== $actorId) throw new MenuPricingException('MENU_PRICING_ADJUSTMENT_ACTOR_MISMATCH', 409);
            if ($adjustment->status === 'applied') return $this->present($adjustment);
            if ($adjustment->status !== 'previewed' || $adjustment->expires_at->isPast()) throw new MenuPricingException('MENU_PRICING_PREVIEW_EXPIRED', 409);
            if (! hash_equals($adjustment->fingerprint, (string) $input['previewFingerprint'])) throw new MenuPricingException('MENU_PRICING_PREVIEW_FINGERPRINT_MISMATCH', 409);
            if (! $input['confirmReviewedResults']) throw new MenuPricingException('MENU_PRICING_REVIEW_CONFIRMATION_REQUIRED');
            if (($adjustment->summary['oppositeDirectionCount'] ?? 0) > 0 && ! ($input['acknowledgeOppositeDirection'] ?? false)) throw new MenuPricingException('MENU_PRICING_OPPOSITE_DIRECTION_ACKNOWLEDGEMENT_REQUIRED');
            $this->query->lockApplyContext($tenantId, $menuId, $adjustment->branch_id, $adjustment->channel);
            $this->lockDependencies($tenantId, $adjustment);
            $rows = $this->query->resolved($tenantId, $menuId, $adjustment->branch_id, $adjustment->channel);
            $scope = $adjustment->operation === 'manual_changes'
                ? $rows->filter(fn (array $row) => $adjustment->items->contains('product_variant_id', $row['variant']->id))->values()
                : $rows;
            if (! hash_equals($adjustment->dependency_fingerprint, $this->query->fingerprint($scope))) throw new MenuPricingException('MENU_PRICING_PREVIEW_STALE', 409);
            $byVariant = $rows->keyBy(fn (array $row) => $row['variant']->id);
            foreach ($adjustment->items as $item) {
                $row = $byVariant->get($item->product_variant_id);
                if (! $row || (! $row['adjustable'] && $item->action !== 'reset')) throw new MenuPricingException('MENU_PRICING_TARGET_NO_LONGER_ELIGIBLE', 409);
                if ($item->action === 'reset') {
                    // A reset must still resolve to a positive inherited price at apply time.
                    if ($this->decimal($row['resolved']['inherited']['effectivePrice'])->isLessThanOrEqualTo(BigDecimal::zero())) throw new MenuPricingException('MENU_PRICING_INVALID_INHERITED_PRICE');
                    MenuVariantPrice::query()->where('tenant_id', $tenantId)->where('menu_id', $menuId)->where('product_variant_id', $item->product_variant_id)->where('branch_id', $adjustment->branch_id)->where('channel', $adjustment->channel)->delete();
                } elseif ($item->configuration_effect !== 'unchanged_existing_override') {
                    MenuVariantPrice::query()->updateOrCreate(['tenant_id' => $tenantId, 'menu_id' => $menuId, 'product_variant_id' => $item->product_variant_id, 'branch_id' => $adjustment->branch_id, 'channel' => $adjustment->channel], ['price' => $item->final_new_price, 'updated_by' => $actorId]);
                }
            }
            $adjustment->update(['status' => 'applied', 'confirmed_reviewed_results' => true, 'acknowledged_opposite_direction' => (bool) ($input['acknowledgeOppositeDirection'] ?? false), 'applied_at' => now()]);
            return $this->present($adjustment->fresh('items.variant.product'));
        });
    }

    private function manualTargets(Collection $rows, array $actions): Collection
    {
        $ids = collect($actions)->pluck('variantId');
        if ($ids->count() !== $ids->unique()->count()) throw new MenuPricingException('MENU_PRICING_DUPLICATE_VARIANT');
        $targets = $rows->filter(fn (array $row) => $ids->contains($row['variant']->id))->values();
        if ($targets->count() !== $ids->count()) throw new MenuPricingException('MENU_PRICING_INVALID_VARIANT');
        foreach ($targets as $row) if (! $row['adjustable']) throw new MenuPricingException('MENU_PRICING_OPEN_PRICE_READ_ONLY');
        return $targets;
    }

    private function manualAction(array $actions, int $variantId): array { return collect($actions)->firstWhere('variantId', $variantId); }

    private function item(array $row, string $operation, array $input, ?array $manual): array
    {
        $r = $row['resolved']; $original = $this->decimal($r['effectivePrice']); $had = $r['menuOverrideId'] !== null;
        $action = $operation === 'manual_changes' ? $manual['action'] : 'set';
        if ($action === 'reset') {
            $final = $this->decimal($r['inherited']['effectivePrice']); if ($final->isLessThanOrEqualTo(BigDecimal::zero())) throw new MenuPricingException('MENU_PRICING_INVALID_INHERITED_PRICE');
            return $this->record($row, $action, $original, $final, null, $had, $had ? 'remove_override' : 'already_inherited', $r['inherited']['matchedScope'], false);
        }
        $raw = $operation === 'manual_changes' ? $this->decimal($manual['price']) : $this->calculate($original, $operation, $this->decimal($input['amount']));
        if ($raw->isLessThanOrEqualTo(BigDecimal::zero())) throw new MenuPricingException('MENU_PRICING_RAW_RESULT_INVALID');
        $final = $operation === 'manual_changes' ? $raw->toScale(2, RoundingMode::HALF_UP) : $this->round($raw, $input['roundingMode'], $input['roundingStep'] ?? null);
        if ($final->isLessThanOrEqualTo(BigDecimal::zero()) || $final->isGreaterThan($this->decimal(self::MAX_PRICE))) throw new MenuPricingException('MENU_PRICING_FINAL_RESULT_INVALID');
        $opposite = ($operation === 'percentage_increase' || $operation === 'fixed_increase') ? $final->isLessThan($original) : (($operation === 'percentage_decrease' || $operation === 'fixed_decrease') ? $final->isGreaterThan($original) : false);
        $effect = ! $had ? 'create_override' : ($final->isEqualTo($original) ? 'unchanged_existing_override' : 'update_override');
        return $this->record($row, $action, $original, $final, $raw, $had, $effect, 'menu', $opposite);
    }

    private function record(array $row, string $action, BigDecimal $original, BigDecimal $final, ?BigDecimal $raw, bool $had, string $effect, string $finalSource, bool $opposite): array
    {
        $difference = $final->minus($original); $movement = $difference->isGreaterThan(0) ? 'increase' : ($difference->isLessThan(0) ? 'decrease' : 'unchanged'); $r = $row['resolved'];
        $variant = $row['variant'];
        return ['product_variant_id' => $variant->id, 'product_id' => $variant->product_id, 'product_name' => $variant->product_name, 'product_name_ar' => $variant->product_name_ar, 'product_name_en' => $variant->product_name_en,
            'variant_name' => $variant->name, 'variant_name_ar' => $variant->name_ar, 'variant_name_en' => $variant->name_en, 'is_default' => (bool) $variant->is_default,
            'action' => $action, 'original_effective_price' => $this->money($original), 'original_source' => $r['matchedScope'], 'had_menu_override' => $had,
            'previous_override_price' => $had ? $this->money($original) : null, 'previous_override_revision' => $had ? ($r['menuOverrideUpdatedAt'] ?? null) : null, 'raw_calculated_price' => $raw ? $this->canonical($raw) : null,
            'final_new_price' => $this->money($final), 'final_source' => $finalSource, 'difference' => $this->money($difference), 'final_movement' => $movement, 'opposite_direction' => $opposite, 'configuration_effect' => $effect,
            'dependency_fingerprint' => hash('sha256', $row['variant']->id.'|'.$r['effectivePrice'].'|'.$r['matchedScope'].'|'.$r['inherited']['effectivePrice'].'|'.$r['inherited']['matchedScope'].'|'.$r['menuOverrideUpdatedAt'])];
    }

    private function summary(Collection $all, Collection $items, string $operation, array $input, array $context): array
    {
        return ['eligibleVariantCount' => $all->where('adjustable', true)->count(), 'inheritedVariantCount' => $items->where('had_menu_override', false)->count(), 'menuOverrideVariantCount' => $items->where('had_menu_override', true)->count(),
            'overridesToCreateCount' => $items->where('configuration_effect', 'create_override')->count(), 'overridesToUpdateCount' => $items->where('configuration_effect', 'update_override')->count(), 'overridesToRemoveCount' => $items->where('configuration_effect', 'remove_override')->count(),
            'finalIncreaseCount' => $items->where('final_movement', 'increase')->count(), 'finalDecreaseCount' => $items->where('final_movement', 'decrease')->count(), 'unchangedPriceCount' => $items->where('final_movement', 'unchanged')->count(),
            'configurationChangedCount' => $items->whereIn('configuration_effect', ['create_override', 'update_override', 'remove_override'])->count(), 'oppositeDirectionCount' => $items->where('opposite_direction', true)->count(),
            'excludedVariantCount' => $all->where('adjustable', false)->count(), 'context' => ['menuId' => $context['menu']->id, 'branchId' => $context['branch']->id, 'channel' => $context['channel']], 'operation' => $operation, 'amount' => $operation === 'manual_changes' ? null : $this->canonical($input['amount']),
            'roundingMode' => $operation === 'manual_changes' ? 'no_rounding' : $input['roundingMode'], 'roundingStep' => $operation === 'manual_changes' ? null : ($input['roundingStep'] ?? null), 'expiresAt' => now()->addMinutes(30)->toIso8601String()];
    }

    private function validateSettings(string $operation, array $input): void
    {
        if ($operation === 'manual_changes') return;
        $amount = $this->decimal($input['amount']); if ($amount->isLessThanOrEqualTo(BigDecimal::zero()) || $amount->isGreaterThan($this->decimal(self::MAX_PRICE))) throw new MenuPricingException('MENU_PRICING_AMOUNT_INVALID');
        if ($operation === 'percentage_decrease' && $amount->isGreaterThanOrEqualTo(100)) throw new MenuPricingException('MENU_PRICING_PERCENTAGE_DECREASE_INVALID');
        if (! in_array($input['roundingMode'], ['no_rounding', 'round_up', 'round_down'], true)) throw new MenuPricingException('MENU_PRICING_ROUNDING_MODE_INVALID');
        if ($input['roundingMode'] === 'no_rounding' && (! array_key_exists('roundingStep', $input) || $input['roundingStep'] !== null)) throw new MenuPricingException('MENU_PRICING_ROUNDING_STEP_INVALID');
        if ($input['roundingMode'] !== 'no_rounding') { if (! isset($input['roundingStep'])) throw new MenuPricingException('MENU_PRICING_ROUNDING_STEP_REQUIRED'); $step = $this->decimal($input['roundingStep']); if ($step->isLessThanOrEqualTo(BigDecimal::zero()) || $step->isGreaterThan($this->decimal(self::MAX_PRICE)) || $step->getScale() > 2 || strlen($this->canonical($step)) > 64) throw new MenuPricingException('MENU_PRICING_ROUNDING_STEP_INVALID'); }
    }

    private function calculate(BigDecimal $original, string $operation, BigDecimal $amount): BigDecimal
    {
        $fraction = $amount->withPointMovedLeft(2);
        return match ($operation) { 'percentage_increase' => $original->multipliedBy(BigDecimal::one()->plus($fraction)), 'fixed_increase' => $original->plus($amount), 'percentage_decrease' => $original->multipliedBy(BigDecimal::one()->minus($fraction)), 'fixed_decrease' => $original->minus($amount), default => throw new MenuPricingException('MENU_PRICING_OPERATION_INVALID') };
    }

    private function round(BigDecimal $raw, string $mode, ?string $step): BigDecimal
    {
        if ($mode === 'no_rounding') return $raw->toScale(2, RoundingMode::HALF_UP);
        $units = $raw->dividedBy($this->decimal($step), 0, $mode === 'round_up' ? RoundingMode::CEILING : RoundingMode::FLOOR);
        return $units->multipliedBy($this->decimal($step))->toScale(2, RoundingMode::HALF_UP);
    }

    private function lockDependencies(int $tenantId, MenuPriceAdjustment $a): void
    {
        // Parent-to-child order matches catalog lifecycle writers: context,
        // menu composition, products, variants, shared overrides, prices.
        DB::table('menu_sections')->where('tenant_id', $tenantId)->where('menu_id', $a->menu_id)->orderBy('id')->lockForUpdate()->get();
        $placements = DB::table('menu_item_placements')->join('menu_sections', 'menu_sections.id', '=', 'menu_item_placements.menu_section_id')
            ->where('menu_sections.tenant_id', $tenantId)->where('menu_sections.menu_id', $a->menu_id)->orderBy('menu_item_placements.id')->lockForUpdate()
            ->select('menu_item_placements.id', 'menu_item_placements.product_id')->get();
        $productIds = $placements->pluck('product_id')->unique()->sort()->values()->all();
        if ($productIds !== []) DB::table('products')->where('tenant_id', $tenantId)->whereIn('id', $productIds)->orderBy('id')->lockForUpdate()->get();
        $variantIds = $productIds === [] ? [] : DB::table('product_variants')->where('tenant_id', $tenantId)->whereIn('product_id', $productIds)->orderBy('id')->lockForUpdate()->pluck('id')->all();
        if ($variantIds !== []) DB::table('product_variant_price_overrides')->where('tenant_id', $tenantId)->whereIn('product_variant_id', $variantIds)->orderBy('id')->lockForUpdate()->get();
        DB::table('menu_variant_prices')->where('tenant_id', $tenantId)->where('menu_id', $a->menu_id)->where('branch_id', $a->branch_id)->where('channel', $a->channel)->orderBy('id')->lockForUpdate()->get();
    }

    private function decimal(mixed $value): BigDecimal
    {
        try { $text = trim((string) $value); if (! preg_match('/^-?\d+(?:\.\d+)?$/', $text)) throw new \InvalidArgumentException(); return BigDecimal::of($text); } catch (\Throwable) { throw new MenuPricingException('MENU_PRICING_DECIMAL_INVALID'); }
    }
    private function money(BigDecimal $v): string { return $v->toScale(2, RoundingMode::HALF_UP)->__toString(); }
    private function canonical(BigDecimal|string $v): string { $value = $v instanceof BigDecimal ? $v : $this->decimal($v); return $value->__toString(); }
    private function normalizeSettings(array $input): array
    {
        if (($input['operation'] ?? null) !== 'manual_changes' && isset($input['amount'])) $input['amount'] = $this->canonical($input['amount']);
        if (($input['roundingMode'] ?? null) !== 'no_rounding' && isset($input['roundingStep'])) $input['roundingStep'] = $this->canonical($input['roundingStep']);
        return $input;
    }
    private function present(MenuPriceAdjustment $a): array { $status = $a->status === 'previewed' && $a->expires_at?->isPast() ? 'expired' : $a->status; return ['id' => $a->id, 'status' => $status, 'fingerprint' => $a->fingerprint, 'expiresAt' => $a->expires_at?->toIso8601String(), 'appliedAt' => $a->applied_at?->toIso8601String(), 'context' => ['menuId' => $a->menu_id, 'branchId' => $a->branch_id, 'channel' => $a->channel], 'operation' => $a->operation, 'amount' => $a->amount, 'roundingMode' => $a->rounding_mode, 'roundingStep' => $a->rounding_step, 'summary' => $a->summary, 'confirmedReviewedResults' => $a->confirmed_reviewed_results, 'acknowledgedOppositeDirection' => $a->acknowledged_opposite_direction, 'items' => $a->items->map(function ($i): array { $variant = $i->variant; $product = $variant?->product; return ['productId' => $i->product_id ?? $variant?->product_id, 'productName' => $i->product_name ?? $product?->name, 'productNameAr' => $i->product_name_ar ?? $product?->name_ar, 'productNameEn' => $i->product_name_en ?? $product?->name_en, 'variantId' => $i->product_variant_id, 'variantName' => $i->variant_name ?? $variant?->name, 'variantNameAr' => $i->variant_name_ar ?? $variant?->name_ar, 'variantNameEn' => $i->variant_name_en ?? $variant?->name_en, 'isDefault' => $i->is_default ?? $variant?->is_default, 'action' => $i->action, 'hadMenuOverride' => $i->had_menu_override, 'originalEffectivePrice' => $i->original_effective_price, 'originalSource' => $i->original_source, 'previousOverridePrice' => $i->previous_override_price, 'rawCalculatedPrice' => $i->raw_calculated_price, 'finalNewPrice' => $i->final_new_price, 'finalSource' => $i->final_source, 'difference' => $i->difference, 'finalMovement' => $i->final_movement, 'oppositeDirection' => $i->opposite_direction, 'configurationEffect' => $i->configuration_effect]; })->values()->all()]; }
}
