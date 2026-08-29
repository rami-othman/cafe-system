<?php

namespace App\Services\Catalog;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Models\ModifierGroup;
use App\Models\ModifierOption;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ModifierGroupService
{
    public function __construct(private readonly CatalogAuditService $audit) {}

    public function create(int $tenantId, array $data): ModifierGroup
    {
        $options = array_values($data['options'] ?? []);
        $this->validateGroup($data, $options);
        foreach ($options as $option) {
            $this->validateOptionValues($option);
        }

        return DB::transaction(function () use ($tenantId, $data, $options): ModifierGroup {
            $group = ModifierGroup::query()->create(['tenant_id' => $tenantId] + $this->payload($data));
            foreach ($options as $option) {
                $group->options()->create(['tenant_id' => $tenantId] + $this->optionPayload($option));
            }
            $group = $group->fresh('options');
            $this->audit->log($tenantId, $group, MenuAuditAction::Created, null, $group->toArray());

            return $group;
        });
    }

    public function update(ModifierGroup $group, array $data): ModifierGroup
    {
        return DB::transaction(function () use ($group, $data): ModifierGroup {
            $lockedGroup = $this->lockGroup($group);
            $merged = array_replace($this->groupSnapshot($lockedGroup), $data);
            $options = $this->lockOptions($lockedGroup);
            $this->validateGroup($merged, $this->optionSnapshots($options));

            $before = $lockedGroup->toArray();
            $lockedGroup->update($this->payload($merged, false));
            $this->audit->log($lockedGroup->tenant_id, $lockedGroup, MenuAuditAction::Updated, $before, $lockedGroup->fresh()->toArray());

            return $lockedGroup->fresh('options');
        });
    }

    public function archive(ModifierGroup $group): ModifierGroup
    {
        return DB::transaction(function () use ($group): ModifierGroup {
            $lockedGroup = $this->lockGroup($group);
            $before = $lockedGroup->toArray();
            $lockedGroup->update(['is_active' => false]);
            $lockedGroup->delete();
            $this->audit->log($lockedGroup->tenant_id, $lockedGroup, MenuAuditAction::Archived, $before, ['isActive' => false]);

            return $lockedGroup;
        });
    }

    public function restore(ModifierGroup $group): ModifierGroup
    {
        return DB::transaction(function () use ($group): ModifierGroup {
            $lockedGroup = $this->lockGroup($group);
            $options = $this->lockOptions($lockedGroup);
            $this->validateGroup(
                array_replace($this->groupSnapshot($lockedGroup), ['isActive' => true]),
                $this->optionSnapshots($options),
            );
            $lockedGroup->restore();
            $lockedGroup->update(['is_active' => true]);
            $this->audit->log($lockedGroup->tenant_id, $lockedGroup, MenuAuditAction::Restored, null, $lockedGroup->fresh()->toArray());

            return $lockedGroup->fresh('options');
        });
    }

    public function createOption(ModifierGroup $group, array $data): ModifierOption
    {
        return DB::transaction(function () use ($group, $data): ModifierOption {
            $lockedGroup = $this->lockGroup($group);
            $options = $this->lockOptions($lockedGroup);
            $this->validateOption($lockedGroup, $data);
            $this->validateGroup(
                $this->groupSnapshot($lockedGroup),
                [...$this->optionSnapshots($options), $this->optionSnapshot($data)],
            );

            $option = $lockedGroup->options()->create(['tenant_id' => $lockedGroup->tenant_id] + $this->optionPayload($data));
            $this->audit->log($lockedGroup->tenant_id, $option, MenuAuditAction::Created, null, $option->toArray());

            return $option;
        });
    }

    public function updateOption(ModifierOption $option, array $data): ModifierOption
    {
        return DB::transaction(function () use ($option, $data): ModifierOption {
            $lockedGroup = $this->lockGroupById($option->modifier_group_id, $option->tenant_id);
            $lockedOptions = $this->lockOptions($lockedGroup);
            $lockedOption = $lockedOptions->firstWhere('id', $option->id);
            if (! $lockedOption) {
                abort(404);
            }
            $merged = array_replace($this->optionSnapshot($lockedOption), $data);
            $this->validateOption($lockedGroup, $merged, $lockedOption);
            $this->validateGroup(
                $this->groupSnapshot($lockedGroup),
                $this->optionSnapshots($lockedOptions, $lockedOption->id, $merged),
            );

            $before = $lockedOption->toArray();
            $lockedOption->update($this->optionPayload($merged));
            $this->audit->log($lockedOption->tenant_id, $lockedOption, MenuAuditAction::Updated, $before, $lockedOption->fresh()->toArray());

            return $lockedOption->fresh();
        });
    }

    public function archiveOption(ModifierOption $option): ModifierOption
    {
        return DB::transaction(function () use ($option): ModifierOption {
            $lockedGroup = $this->lockGroupById($option->modifier_group_id, $option->tenant_id);
            $lockedOptions = $this->lockOptions($lockedGroup);
            $lockedOption = $lockedOptions->firstWhere('id', $option->id);
            if (! $lockedOption) {
                abort(404);
            }
            $this->validateGroup(
                $this->groupSnapshot($lockedGroup),
                $this->optionSnapshots($lockedOptions, $lockedOption->id, ['isActive' => false]),
            );

            $lockedOption->update(['is_active' => false]);
            $lockedOption->delete();
            $this->audit->log($lockedOption->tenant_id, $lockedOption, MenuAuditAction::Archived, null, ['isActive' => false]);

            return $lockedOption;
        });
    }

    public function restoreOption(ModifierOption $option): ModifierOption
    {
        return DB::transaction(function () use ($option): ModifierOption {
            $lockedGroup = $this->lockGroupById($option->modifier_group_id, $option->tenant_id);
            $lockedOptions = $this->lockOptions($lockedGroup);
            $lockedOption = $lockedOptions->firstWhere('id', $option->id);
            if (! $lockedOption) {
                abort(404);
            }
            $this->validateGroup(
                $this->groupSnapshot($lockedGroup),
                $this->optionSnapshots($lockedOptions, $lockedOption->id, ['isActive' => true]),
            );

            $lockedOption->restore();
            $lockedOption->update(['is_active' => true]);
            $this->audit->log($lockedOption->tenant_id, $lockedOption, MenuAuditAction::Restored, null, $lockedOption->fresh()->toArray());

            return $lockedOption->fresh();
        });
    }

    public function reorderGroups(int $tenantId, array $items): void
    {
        DB::transaction(function () use ($tenantId, $items): void {
            $groups = ModifierGroup::query()
                ->where('tenant_id', $tenantId)
                ->where('is_active', true)
                ->lockForUpdate()
                ->orderBy('sort_order')
                ->orderBy('id')
                ->get();
            $ids = collect($items)->pluck('id');
            $expectedIds = $groups->pluck('id');
            $orders = collect($items)->pluck('sortOrder')->map(fn ($order) => (int) $order)->sort()->values()->all();
            $expectedOrders = range(0, max(0, $groups->count() - 1));

            if ($groups->isEmpty() || $ids->count() !== $expectedIds->count() || $ids->unique()->count() !== $ids->count() || $ids->diff($expectedIds)->isNotEmpty() || $expectedIds->diff($ids)->isNotEmpty()) {
                throw ValidationException::withMessages(['items' => 'Reorder must include every active modifier group exactly once.']);
            }
            if ($orders !== $expectedOrders) {
                throw ValidationException::withMessages(['items' => 'Modifier group order must use contiguous positions.']);
            }

            foreach ($items as $item) {
                $groups->firstWhere('id', $item['id'])->update(['sort_order' => $item['sortOrder']]);
            }
            $this->audit->log($tenantId, ModifierGroup::class, MenuAuditAction::Reordered, null, ['items' => $items]);
        });
    }

    public function reorder(ModifierGroup $group, array $items): void
    {
        DB::transaction(function () use ($group, $items): void {
            $ids = collect($items)->pluck('id');
            if ($ids->unique()->count() !== $ids->count() || $group->options()->whereIn('id', $ids)->count() !== $ids->count()) {
                throw ValidationException::withMessages(['items' => 'Every option must belong to this modifier group.']);
            } foreach ($items as $item) {
                $group->options()->whereKey($item['id'])->update(['sort_order' => $item['sortOrder']]);
            } $this->audit->log($group->tenant_id, $group, MenuAuditAction::Reordered, null, ['options' => $items]);
        });
    }

    private function validateGroup(array $data, array $options): void
    {
        $active = collect($options)->filter(fn ($option) => $option['isActive'] ?? true);
        $defaults = collect($options)->filter(fn ($option) => $option['isDefault'] ?? false);
        $min = (int) ($data['minSelections'] ?? 0);
        $max = (int) ($data['maxSelections'] ?? 1);
        $required = $data['isRequired'] ?? false;
        $allowQuantity = (bool) ($data['allowQuantity'] ?? false);
        if ($min < 0 || $max < $min || ($max > $active->count() && ! $allowQuantity) || ($required && $min < 1) || (($data['selectionType'] ?? 'single') === 'single' && $max > 1) || (($data['isActive'] ?? true) && $active->isEmpty()) || $defaults->contains(fn ($option) => ! ($option['isActive'] ?? true)) || $active->where('isDefault', true)->count() > $max) {
            throw ValidationException::withMessages(['modifierGroup' => 'The modifier group selection rules are invalid.']);
        }
        $names = $active->pluck('name')->map(fn ($name) => strtolower($name));
        if ($names->unique()->count() !== $names->count()) {
            throw ValidationException::withMessages(['options' => 'Option names must be unique within a modifier group.']);
        }
    }

    private function validateOption(ModifierGroup $group, array $data, ?ModifierOption $ignore = null): void
    {
        $this->validateOptionValues($data);
        if ($group->options()->withTrashed()->whereRaw('LOWER(name) = ?', [strtolower($data['name'])])->when($ignore, fn ($query) => $query->where('id', '!=', $ignore->id))->exists()) {
            throw ValidationException::withMessages(['name' => 'The modifier option is invalid or already exists.']);
        }
    }

    private function validateOptionValues(array $data): void
    {
        if (($data['costDelta'] ?? 0) < 0 || trim((string) ($data['name'] ?? '')) === '') {
            throw ValidationException::withMessages(['name' => 'The modifier option is invalid.']);
        }
    }

    private function lockGroup(ModifierGroup $group): ModifierGroup
    {
        return $this->lockGroupById($group->id, $group->tenant_id);
    }

    private function lockGroupById(int $id, int $tenantId): ModifierGroup
    {
        return ModifierGroup::query()->withTrashed()->where('tenant_id', $tenantId)->whereKey($id)->lockForUpdate()->firstOrFail();
    }

    private function lockOptions(ModifierGroup $group)
    {
        return ModifierOption::query()->withTrashed()->where('tenant_id', $group->tenant_id)->where('modifier_group_id', $group->id)->lockForUpdate()->get();
    }

    private function groupSnapshot(ModifierGroup $group): array
    {
        return ['name' => $group->name, 'nameAr' => $group->name_ar, 'nameEn' => $group->name_en, 'code' => $group->code, 'groupType' => $group->group_type->value, 'selectionType' => $group->selection_type, 'isRequired' => $group->is_required, 'minSelections' => $group->min_selections, 'maxSelections' => $group->max_selections, 'allowQuantity' => $group->allow_quantity, 'isActive' => $group->is_active, 'sortOrder' => $group->sort_order];
    }

    private function optionSnapshots($options, ?int $replaceId = null, array $replacement = []): array
    {
        return $options->map(fn ($option) => $option->id === $replaceId ? $this->optionSnapshot(array_replace($this->optionSnapshot($option), $replacement)) : $this->optionSnapshot($option))->all();
    }

    private function optionSnapshot(ModifierOption|array $option): array
    {
        if ($option instanceof ModifierOption) {
            return ['name' => $option->name, 'nameAr' => $option->name_ar, 'nameEn' => $option->name_en, 'priceDelta' => $option->price_delta, 'costDelta' => $option->cost_delta, 'isDefault' => $option->is_default, 'isActive' => $option->is_active, 'isAvailable' => $option->is_available, 'sortOrder' => $option->sort_order];
        }

        return $option + ['nameAr' => null, 'nameEn' => null, 'priceDelta' => 0, 'costDelta' => 0, 'isDefault' => false, 'isActive' => true, 'isAvailable' => true, 'sortOrder' => 0];
    }

    private function payload(array $data, bool $create = true): array
    {
        $payload = ['name' => $data['name'], 'name_ar' => $data['nameAr'] ?? null, 'name_en' => $data['nameEn'] ?? null, 'code' => $data['code'] ?? null, 'group_type' => $data['groupType'] ?? 'choice', 'selection_type' => $data['selectionType'] ?? 'single', 'is_required' => $data['isRequired'] ?? false, 'min_selections' => $data['minSelections'] ?? 0, 'max_selections' => $data['maxSelections'] ?? 1, 'allow_quantity' => $data['allowQuantity'] ?? false, 'sort_order' => $data['sortOrder'] ?? 0];

        // The controller accepts isActive for both create and patch. Keep the
        // persisted value in sync rather than silently discarding it on patch.
        return $payload + ['is_active' => $data['isActive'] ?? true];
    }

    private function optionPayload(array $data): array
    {
        return ['name' => $data['name'], 'name_ar' => $data['nameAr'] ?? null, 'name_en' => $data['nameEn'] ?? null, 'price_delta' => $data['priceDelta'] ?? 0, 'cost_delta' => $data['costDelta'] ?? 0, 'is_default' => $data['isDefault'] ?? false, 'is_active' => $data['isActive'] ?? true, 'is_available' => $data['isAvailable'] ?? true, 'sort_order' => $data['sortOrder'] ?? 0];
    }

    private function snakeToCamel(array $values): array
    {
        $result = [];
        foreach ($values as $key => $value) {
            $result[lcfirst(str_replace(' ', '', ucwords(str_replace('_', ' ', $key))))] = $value;
        }

        return $result;
    }
}
