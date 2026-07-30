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
        $this->validateGroup($data, $data['options'] ?? []);

        return DB::transaction(function () use ($tenantId, $data): ModifierGroup {
            $group = ModifierGroup::query()->create(['tenant_id' => $tenantId] + $this->payload($data));
            foreach ($data['options'] as $option) {
                $group->options()->create(['tenant_id' => $tenantId] + $this->optionPayload($option));
            }
            $group = $group->fresh('options');
            $this->audit->log($tenantId, $group, MenuAuditAction::Created, null, $group->toArray());

            return $group;
        });
    }

    public function update(ModifierGroup $group, array $data): ModifierGroup
    {
        $merged = array_replace($this->snakeToCamel($group->getAttributes()), $data);
        $this->validateGroup($merged, $group->options()->where('is_active', true)->get()->map(fn ($option) => ['isActive' => $option->is_active, 'isDefault' => $option->is_default, 'name' => $option->name])->all());

        return DB::transaction(function () use ($group, $data): ModifierGroup {
            $before = $group->toArray();
            $group->update($this->payload($data, false));
            $this->audit->log($group->tenant_id, $group, MenuAuditAction::Updated, $before, $group->fresh()->toArray());

            return $group->fresh('options');
        });
    }

    public function archive(ModifierGroup $group): ModifierGroup
    {
        return DB::transaction(function () use ($group): ModifierGroup {
            $before = $group->toArray();
            $group->update(['is_active' => false]);
            $group->delete();
            $this->audit->log($group->tenant_id, $group, MenuAuditAction::Archived, $before, ['isActive' => false]);

            return $group;
        });
    }

    public function restore(ModifierGroup $group): ModifierGroup
    {
        if (! $group->options()->where('is_active', true)->exists()) {
            throw ValidationException::withMessages(['modifierGroup' => 'An active modifier group requires an active option.']);
        }

        return DB::transaction(function () use ($group): ModifierGroup {
            $group->restore();
            $group->update(['is_active' => true]);
            $this->audit->log($group->tenant_id, $group, MenuAuditAction::Restored, null, $group->fresh()->toArray());

            return $group->fresh('options');
        });
    }

    public function createOption(ModifierGroup $group, array $data): ModifierOption
    {
        $this->validateOption($group, $data);

        return DB::transaction(function () use ($group, $data): ModifierOption {
            $option = $group->options()->create(['tenant_id' => $group->tenant_id] + $this->optionPayload($data));
            $this->audit->log($group->tenant_id, $option, MenuAuditAction::Created, null, $option->toArray());

            return $option;
        });
    }

    public function updateOption(ModifierOption $option, array $data): ModifierOption
    {
        $this->validateOption($option->modifierGroup, $data, $option);

        return DB::transaction(function () use ($option, $data): ModifierOption {
            $before = $option->toArray();
            $option->update($this->optionPayload($data));
            $this->audit->log($option->tenant_id, $option, MenuAuditAction::Updated, $before, $option->fresh()->toArray());

            return $option->fresh();
        });
    }

    public function archiveOption(ModifierOption $option): ModifierOption
    {
        $group = $option->modifierGroup;
        $remaining = $group->options()->where('is_active', true)->where('id', '!=', $option->id)->count();
        if ($group->is_active && ($remaining < max(1, $group->min_selections) || ($option->is_default && $group->options()->where('is_active', true)->where('is_default', true)->where('id', '!=', $option->id)->count() > $group->max_selections))) {
            throw ValidationException::withMessages(['modifierOption' => 'This option cannot be archived without invalidating its group.']);
        }

        return DB::transaction(function () use ($option): ModifierOption {
            $option->update(['is_active' => false]);
            $option->delete();
            $this->audit->log($option->tenant_id, $option, MenuAuditAction::Archived, null, ['isActive' => false]);

            return $option;
        });
    }

    public function restoreOption(ModifierOption $option): ModifierOption
    {
        return DB::transaction(function () use ($option): ModifierOption {
            $option->restore();
            $option->update(['is_active' => true]);
            $this->audit->log($option->tenant_id, $option, MenuAuditAction::Restored, null, $option->fresh()->toArray());

            return $option->fresh();
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
        $min = (int) ($data['minSelections'] ?? 0);
        $max = (int) ($data['maxSelections'] ?? 1);
        $required = $data['isRequired'] ?? false;
        if ($min < 0 || $max < $min || $max > $active->count() || ($required && $min < 1) || (($data['selectionType'] ?? 'single') === 'single' && $max > 1) || (($data['isActive'] ?? true) && $active->isEmpty()) || $active->where('isDefault', true)->count() > $max) {
            throw ValidationException::withMessages(['modifierGroup' => 'The modifier group selection rules are invalid.']);
        }
        $names = $active->pluck('name')->map(fn ($name) => strtolower($name));
        if ($names->unique()->count() !== $names->count()) {
            throw ValidationException::withMessages(['options' => 'Option names must be unique within a modifier group.']);
        }
    }

    private function validateOption(ModifierGroup $group, array $data, ?ModifierOption $ignore = null): void
    {
        if (($data['priceDelta'] ?? 0) < 0 || ($data['costDelta'] ?? 0) < 0 || $group->options()->withTrashed()->whereRaw('LOWER(name) = ?', [strtolower($data['name'])])->when($ignore, fn ($query) => $query->where('id', '!=', $ignore->id))->exists()) {
            throw ValidationException::withMessages(['name' => 'The modifier option is invalid or already exists.']);
        }
    }

    private function payload(array $data, bool $create = true): array
    {
        $payload = ['name' => $data['name'], 'name_ar' => $data['nameAr'] ?? null, 'name_en' => $data['nameEn'] ?? null, 'code' => $data['code'] ?? null, 'group_type' => $data['groupType'] ?? 'choice', 'selection_type' => $data['selectionType'] ?? 'single', 'is_required' => $data['isRequired'] ?? false, 'min_selections' => $data['minSelections'] ?? 0, 'max_selections' => $data['maxSelections'] ?? 1, 'allow_quantity' => $data['allowQuantity'] ?? false, 'sort_order' => $data['sortOrder'] ?? 0];

        return $create ? $payload + ['is_active' => $data['isActive'] ?? true] : $payload;
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
