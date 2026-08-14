<?php

namespace App\Services\Catalog;

use App\Models\ModifierOption;
use App\Models\ProductVariant;
use Brick\Math\BigDecimal;
use Illuminate\Validation\ValidationException;

class RecipeResolver
{
    public function __construct(private readonly RecipeConfigurationService $configuration, private readonly MaterialCatalogService $materials, private readonly RecipeUnitRegistry $units) {}

    public function resolve(ProductVariant $variant, array $selected): array
    {
        if (! $variant->is_active || $variant->trashed() || ! $variant->product || ! $variant->product->is_active || $variant->product->trashed()) {
            throw ValidationException::withMessages(['variant' => 'Variant is unavailable.']);
        }
        $groups = $variant->product->modifierGroups()->with('options')->get()->keyBy('id');
        $base = $this->configuration->recipe($variant)['components'];
        $amounts = [];
        $meta = [];
        foreach ($base as $c) {
            $material = $this->materials->material($variant->tenant_id, $c['materialId']);
            if (! $material || ! $material->is_active || $material->deleted_at || ! $this->units->inventoryUnit($material->unit)) {
                throw ValidationException::withMessages(['recipe' => 'Base recipe material is unavailable or has an unmapped unit.']);
            }
            if (! $this->units->compatible($this->units->inventoryUnit($material->unit), $c['unitCode'])) {
                throw ValidationException::withMessages(['recipe' => 'Base recipe unit is incompatible with its material.']);
            }
            $n = $this->units->normalize($c['quantity'], $c['unitCode']);
            $amounts[$c['materialId']] = BigDecimal::of($n['quantity']);
            $meta[$c['materialId']] = [$n['unitCode'], $n['family']];
        }
        $seen = [];
        $selectedByGroup = [];
        $effects = [];
        foreach ($selected as $pick) {
            $id = (int) ($pick['optionId'] ?? 0);
            if (isset($seen[$id])) {
                throw ValidationException::withMessages(['selectedOptions' => 'Duplicate modifier option.']);
            }$seen[$id] = true;
            $o = ModifierOption::query()->with('modifierGroup')->where('tenant_id', $variant->tenant_id)->find($id);
            $group = $o ? $groups->get($o->modifier_group_id) : null;
            if (! $o || ! $o->is_active || ! $o->is_available || $o->trashed() || ! $group || ! $group->is_active || $group->trashed()) {
                throw ValidationException::withMessages(['selectedOptions' => 'Selected modifier option is invalid.']);
            }
            $selectedByGroup[$group->id] = ($selectedByGroup[$group->id] ?? 0) + 1;
            $q = (int) ($pick['quantity'] ?? 1);
            $allow = (bool) ($group->pivot->allow_quantity_override ?? $group->allow_quantity);
            if ($q < 1 || (! $allow && $q !== 1)) {
                throw ValidationException::withMessages(['selectedOptions' => 'Modifier quantity is invalid.']);
            }$profile = $this->configuration->effective($o, $variant->product_id, $variant->id);
            foreach ($profile?->components ?? [] as $c) {
                $material = $this->materials->material($variant->tenant_id, $c->inventory_item_id);
                if (! $material || ! $material->is_active || $material->deleted_at || ! $this->units->inventoryUnit($material->unit)) {
                    throw ValidationException::withMessages(['recipe' => 'Modifier recipe material is unavailable or has an unmapped unit.']);
                }
                $n = $this->units->normalize($c->quantity, $c->unit_code);
                if (! $this->units->compatible($this->units->inventoryUnit($material->unit), $c->unit_code)) {
                    throw ValidationException::withMessages(['recipe' => 'Modifier recipe unit is incompatible with its material.']);
                }
                if ($c->operation === 'remove' && $q !== 1) {
                    throw ValidationException::withMessages(['selectedOptions' => 'REMOVE cannot be repeated.']);
                }$value = BigDecimal::of($n['quantity'])->multipliedBy($q);
                $effects[] = ['materialId' => $c->inventory_item_id, 'operation' => $c->operation, 'value' => $value];
                $meta[$c->inventory_item_id] = [$n['unitCode'], $n['family']];
            }
        }
        foreach ($groups as $group) {
            $count = $selectedByGroup[$group->id] ?? 0;
            $minimum = (int) ($group->pivot->min_selections_override ?? $group->min_selections);
            $maximum = (int) ($group->pivot->max_selections_override ?? $group->max_selections);
            if ($group->selection_type === 'single') {
                $maximum = min(1, $maximum);
            }
            if ($count > $maximum || ($group->pivot->is_required_override ?? $group->is_required) && $count < $minimum) {
                throw ValidationException::withMessages(['selectedOptions' => 'Modifier group selection constraints are not satisfied.']);
            }
        }
        // Check aggregate removes against Base before applying ADD effects.
        // This keeps the contract independent of the client selection order.
        $removes = [];
        $adds = [];
        foreach ($effects as $effect) {
            $bucket = $effect['operation'] === 'remove' ? 'removes' : 'adds';
            ${$bucket}[$effect['materialId']] = (${$bucket}[$effect['materialId']] ?? BigDecimal::zero())->plus($effect['value']);
        }
        foreach ($removes as $materialId => $value) {
            if ($value->isGreaterThan($amounts[$materialId] ?? BigDecimal::zero())) {
                throw ValidationException::withMessages(['selectedOptions' => 'Modifier REMOVE exceeds the Variant base recipe.']);
            }
            $amounts[$materialId] = ($amounts[$materialId] ?? BigDecimal::zero())->minus($value);
        }
        foreach ($adds as $materialId => $value) {
            $amounts[$materialId] = ($amounts[$materialId] ?? BigDecimal::zero())->plus($value);
        }
        ksort($amounts);
        $rows = [];
        foreach ($amounts as $id => $amount) {
            if (! $amount->isZero()) {
                $m = $this->materials->material($variant->tenant_id, $id);
                if (! $m || ! $m->is_active || $m->deleted_at) {
                    throw ValidationException::withMessages(['recipe' => 'Recipe material is unavailable.']);
                }$rows[] = ['materialId' => $id, 'name' => $m->name, 'sku' => $m->sku, 'quantity' => $this->units->quantityString($amount), 'unitCode' => $meta[$id][0]];
            }
        }

        return ['variantId' => $variant->id, 'components' => $rows];
    }
}
