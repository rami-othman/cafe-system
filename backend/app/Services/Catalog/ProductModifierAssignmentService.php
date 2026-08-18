<?php

namespace App\Services\Catalog;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Models\ModifierGroup;
use App\Models\Product;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ProductModifierAssignmentService
{
    public function __construct(private readonly CatalogAuditService $audit) {}

    public function sync(Product $product, array $groups): void
    {
        DB::transaction(function () use ($product, $groups): void {
            $ids = collect($groups)->pluck('modifierGroupId')->map(fn ($id) => (int) $id);
            if ($ids->unique()->count() !== $ids->count()) {
                throw ValidationException::withMessages(['groups' => 'Duplicate modifier groups are not allowed.']);
            }
            $models = ModifierGroup::query()->where('tenant_id', $product->tenant_id)->where('is_active', true)->whereIn('id', $ids)->withCount(['options as active_options_count' => fn ($query) => $query->where('is_active', true)])->get()->keyBy('id');
            if ($models->count() !== $ids->count()) {
                throw ValidationException::withMessages(['groups' => 'One or more modifier groups are invalid.']);
            }
            foreach ($groups as $group) {
                $this->validateEffective($models[$group['modifierGroupId']], $group);
            }
            $before = $product->modifierGroups()->get()->map->getKey()->all();
            $payload = [];
            foreach ($groups as $group) {
                $payload[$group['modifierGroupId']] = ['tenant_id' => $product->tenant_id, 'sort_order' => $group['sortOrder'], 'is_required_override' => $group['isRequiredOverride'] ?? null, 'min_selections_override' => $group['minSelectionsOverride'] ?? null, 'max_selections_override' => $group['maxSelectionsOverride'] ?? null, 'allow_quantity_override' => $group['allowQuantityOverride'] ?? null];
            }
            $product->modifierGroups()->sync($payload);
            $this->audit->log($product->tenant_id, $product, MenuAuditAction::Assigned, ['groupIds' => $before], ['groupIds' => $ids->all()]);
        });
    }

    private function validateEffective(ModifierGroup $model, array $data): void
    {
        $min = $data['minSelectionsOverride'] ?? $model->min_selections;
        $max = $data['maxSelectionsOverride'] ?? $model->max_selections;
        $required = $data['isRequiredOverride'] ?? $model->is_required;
        $allowQuantity = $data['allowQuantityOverride'] ?? $model->allow_quantity;
        if ($min < 0 || $max < $min || ($max > $model->active_options_count && ! $allowQuantity) || ($model->selection_type === 'single' && $max > 1) || ($required && $min < 1)) {
            throw ValidationException::withMessages(['groups' => 'A modifier group override is invalid.']);
        }
    }
}
