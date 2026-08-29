<?php

namespace App\Services\Menu;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Domain\Menu\Enums\MenuStatus;
use App\Models\Branch;
use App\Models\Menu;
use App\Models\MenuAssignment;
use App\Models\MenuItemPlacement;
use App\Models\MenuSection;
use App\Models\Product;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class MenuCompositionService
{
    public function __construct(private readonly MenuCompositionAuditService $audit) {}

    public function list(int $tenantId, array $filters)
    {
        $query = Menu::query()->where('tenant_id', $tenantId)->withCount([
            'sections',
            'assignments',
            'availabilityRules',
        ]);
        $query->addSelect(['visible_placements_count' => MenuItemPlacement::query()
            ->selectRaw('count(*)')
            ->join('menu_sections', 'menu_sections.id', '=', 'menu_item_placements.menu_section_id')
            ->whereColumn('menu_sections.menu_id', 'menus.id')
            ->whereNull('menu_item_placements.deleted_at')
            ->whereNull('menu_sections.deleted_at')
            ->where('menu_item_placements.is_visible', true)
            ->where('menu_sections.is_active', true)]);
        $status = $filters['status'] ?? 'draft';
        if ($status === 'all') {
            $query->withTrashed();
        } elseif ($status === 'archived') {
            $query->onlyTrashed();
        } else {
            $query->where('status', $status);
        }
        if (! empty($filters['search'])) {
            $search = '%'.strtolower($filters['search']).'%';
            $query->where(fn (Builder $q) => $q->whereRaw('LOWER(name) LIKE ?', [$search])->orWhereRaw("LOWER(COALESCE(name_ar, '')) LIKE ?", [$search])->orWhereRaw("LOWER(COALESCE(name_en, '')) LIKE ?", [$search])->orWhereRaw("LOWER(COALESCE(description, '')) LIKE ?", [$search])->orWhereRaw("LOWER(COALESCE(description_ar, '')) LIKE ?", [$search])->orWhereRaw("LOWER(COALESCE(description_en, '')) LIKE ?", [$search]));
        }
        if (isset($filters['branchId'])) {
            $this->branch($tenantId, $filters['branchId']);
            $query->whereHas('assignments', fn (Builder $q) => $q->where('branch_id', $filters['branchId']));
        }
        if (! empty($filters['channel'])) {
            $query->whereHas('assignments', fn (Builder $q) => $q->where('channel', $filters['channel']));
        }
        if (array_key_exists('hasAssignments', $filters)) {
            $filters['hasAssignments'] ? $query->has('assignments') : $query->doesntHave('assignments');
        }
        $sort = in_array($filters['sort'] ?? null, ['name', 'priority', 'created_at', 'updated_at'], true) ? $filters['sort'] : 'priority';

        return $query->orderBy($sort, ($filters['direction'] ?? 'asc') === 'desc' ? 'desc' : 'asc')->orderBy('id')->paginate(min((int) ($filters['perPage'] ?? 20), 100));
    }

    public function menu(int $tenantId, int $id, bool $withTrashed = false): Menu
    {
        return Menu::query()->when($withTrashed, fn (Builder $q) => $q->withTrashed())->where('tenant_id', $tenantId)->with([
            'sections' => fn ($sections) => $sections->where('tenant_id', $tenantId)->when($withTrashed, fn ($sections) => $sections->withTrashed())->withCount(['placements' => fn ($placements) => $placements->where('tenant_id', $tenantId)])->orderBy('sort_order')->orderBy('id')->with(['placements' => fn ($placements) => $placements->where('tenant_id', $tenantId)->orderBy('sort_order')->orderBy('id')->with('product.defaultVariant')]),
            'assignments' => fn ($q) => $q->orderBy('priority')->orderBy('id'),
            'availabilityRules' => fn ($q) => $q->orderBy('priority')->orderBy('id'),
        ])->findOrFail($id);
    }

    public function createMenu(int $tenantId, array $data): Menu
    {
        if (($data['status'] ?? 'draft') === MenuStatus::Active->value) {
            $this->invalid('status', 'A menu cannot be created as active.');
        }
        $this->uniqueMenuName($tenantId, $data['name']);

        return DB::transaction(function () use ($tenantId, $data): Menu {
            $menu = Menu::query()->create(['tenant_id' => $tenantId] + $this->menuPayload($data));
            $this->audit->log($tenantId, $menu, MenuAuditAction::Created, null, $this->snapshot($menu));

            return $this->menu($tenantId, $menu->id);
        });
    }

    public function updateMenu(Menu $menu, array $data): Menu
    {
        if (($data['status'] ?? null) === MenuStatus::Archived->value) {
            $this->invalid('status', 'Use the archive endpoint to archive a menu.');
        }
        if (isset($data['name'])) {
            $this->uniqueMenuName($menu->tenant_id, $data['name'], $menu->id);
        }

        return DB::transaction(function () use ($menu, $data): Menu {
            $locked = Menu::query()->whereKey($menu->id)->lockForUpdate()->firstOrFail();
            $before = $this->snapshot($locked);
            $locked->update($this->menuPayload($data, false));
            $this->audit->log($locked->tenant_id, $locked, MenuAuditAction::Updated, $before, $this->snapshot($locked));

            return $this->menu($locked->tenant_id, $locked->id);
        });
    }

    public function archiveMenu(Menu $menu): Menu
    {
        return DB::transaction(function () use ($menu): Menu {
            $locked = Menu::query()->whereKey($menu->id)->lockForUpdate()->firstOrFail();
            $before = $this->snapshot($locked);
            $locked->update(['status' => MenuStatus::Archived]);
            $locked->delete();
            $this->audit->log($locked->tenant_id, $locked, MenuAuditAction::Archived, $before, ['status' => MenuStatus::Archived->value]);

            return $this->menu($locked->tenant_id, $locked->id, true);
        });
    }

    public function restoreMenu(Menu $menu): Menu
    {
        return DB::transaction(function () use ($menu): Menu {
            $locked = Menu::withTrashed()->whereKey($menu->id)->lockForUpdate()->firstOrFail();
            $before = $this->snapshot($locked);
            $locked->restore();
            $locked->update(['status' => MenuStatus::Draft]);
            $this->audit->log($locked->tenant_id, $locked, MenuAuditAction::Restored, $before, $this->snapshot($locked));

            return $this->menu($locked->tenant_id, $locked->id);
        });
    }

    public function reorderMenus(int $tenantId, array $items): void
    {
        $this->uniqueIds($items);
        DB::transaction(function () use ($tenantId, $items): void {
            $menus = Menu::query()->where('tenant_id', $tenantId)->whereIn('id', collect($items)->pluck('id'))->lockForUpdate()->get()->keyBy('id');
            if ($menus->count() !== count($items)) {
                $this->invalid('items', 'The selected value is invalid.');
            }
            foreach ($items as $item) {
                $menu = $menus[$item['id']];
                $before = $this->snapshot($menu);
                $menu->update(['priority' => $item['priority']]);
                $this->audit->log($tenantId, $menu, MenuAuditAction::Reordered, $before, ['priority' => $menu->priority]);
            }
        });
    }

    public function section(int $tenantId, int $id, bool $withTrashed = false): MenuSection
    {
        $section = MenuSection::query()
            ->when($withTrashed, fn (Builder $q) => $q->withTrashed())
            ->where('tenant_id', $tenantId)
            ->findOrFail($id);
        $menu = Menu::withTrashed()->where('tenant_id', $tenantId)->findOrFail($section->menu_id);
        $section->setRelation('menu', $menu);

        return $section;
    }

    public function sections(Menu $menu)
    {
        return $menu->sections()->where('tenant_id', $menu->tenant_id)->withCount(['placements' => fn ($placements) => $placements->where('tenant_id', $menu->tenant_id)])->with(['placements' => fn ($placements) => $placements->where('tenant_id', $menu->tenant_id)->with('product.defaultVariant')->orderBy('sort_order')->orderBy('id')])->orderBy('sort_order')->orderBy('id')->get();
    }

    public function createSection(Menu $menu, array $data): MenuSection
    {
        $this->assertMenuUsable($menu);
        $this->uniqueSectionName($menu, $data['name']);

        return DB::transaction(function () use ($menu, $data): MenuSection {
            $sort = $data['sortOrder'] ?? ((int) $menu->sections()->max('sort_order') + 1);
            $section = $menu->sections()->create(['tenant_id' => $menu->tenant_id] + $this->sectionPayload($data) + ['sort_order' => $sort]);
            $this->audit->log($menu->tenant_id, $section, MenuAuditAction::Created, null, $this->snapshot($section));

            return $section->fresh('menu');
        });
    }

    public function updateSection(MenuSection $section, array $data): MenuSection
    {
        $this->assertMenuUsable($section->menu);
        if (isset($data['name'])) {
            $this->uniqueSectionName($section->menu, $data['name'], $section->id);
        }

        return DB::transaction(function () use ($section, $data): MenuSection {
            $locked = MenuSection::query()->whereKey($section->id)->lockForUpdate()->firstOrFail();
            $before = $this->snapshot($locked);
            $locked->update($this->sectionPayload($data, false));
            $this->audit->log($locked->tenant_id, $locked, MenuAuditAction::Updated, $before, $this->snapshot($locked));

            return $locked->fresh('menu');
        });
    }

    public function archiveSection(MenuSection $section): MenuSection
    {
        $this->assertMenuUsable($section->menu);

        return DB::transaction(function () use ($section): MenuSection {
            $locked = MenuSection::query()->whereKey($section->id)->lockForUpdate()->firstOrFail();
            $before = $this->snapshot($locked);
            $locked->update(['is_active' => false]);
            $locked->delete();
            $this->audit->log($locked->tenant_id, $locked, MenuAuditAction::Archived, $before, ['isActive' => false]);

            return $locked->fresh('menu');
        });
    }

    public function restoreSection(MenuSection $section): MenuSection
    {
        $menu = $this->menu($section->tenant_id, $section->menu_id, true);
        $this->assertMenuUsable($menu);

        return DB::transaction(function () use ($section): MenuSection {
            $locked = MenuSection::withTrashed()->whereKey($section->id)->lockForUpdate()->firstOrFail();
            $before = $this->snapshot($locked);
            $locked->restore();
            $locked->update(['is_active' => true]);
            $this->audit->log($locked->tenant_id, $locked, MenuAuditAction::Restored, $before, $this->snapshot($locked));

            return $locked->fresh('menu');
        });
    }

    public function reorderSections(Menu $menu, array $items): void
    {
        $this->assertMenuUsable($menu);
        $this->uniqueIds($items);
        DB::transaction(function () use ($menu, $items): void {
            $sections = $menu->sections()->where('tenant_id', $menu->tenant_id)->whereIn('id', collect($items)->pluck('id'))->lockForUpdate()->get()->keyBy('id');
            if ($sections->count() !== count($items)) {
                $this->invalid('items', 'The selected value is invalid.');
            }
            foreach ($items as $item) {
                $section = $sections[$item['id']];
                $before = $this->snapshot($section);
                $section->update(['sort_order' => $item['sortOrder']]);
                $this->audit->log($menu->tenant_id, $section, MenuAuditAction::Reordered, $before, ['sortOrder' => $section->sort_order]);
            }
        });
    }

    public function placement(int $tenantId, int $id, bool $withTrashed = false): MenuItemPlacement
    {
        return MenuItemPlacement::query()->when($withTrashed, fn (Builder $q) => $q->withTrashed())->where('tenant_id', $tenantId)->with(['menuSection' => fn ($q) => $q->withTrashed()->with(['menu' => fn ($menu) => $menu->withTrashed()]), 'product.defaultVariant'])->findOrFail($id);
    }

    public function placements(MenuSection $section, bool $includeArchived = false)
    {
        return $section->placements()->where('tenant_id', $section->tenant_id)->when($includeArchived, fn ($query) => $query->withTrashed())->with('product.defaultVariant')->orderBy('sort_order')->orderBy('id')->get();
    }

    public function createPlacement(MenuSection $section, array $data): MenuItemPlacement
    {
        $this->assertSectionUsable($section);
        $product = $this->validProduct($section->tenant_id, $data['productId']);
        if ($section->placements()->where('product_id', $product->id)->exists()) {
            $this->invalid('productId', 'This product is already placed in this section.');
        }

        return DB::transaction(function () use ($section, $data, $product): MenuItemPlacement {
            $existing = MenuItemPlacement::withTrashed()->where('tenant_id', $section->tenant_id)->where('menu_section_id', $section->id)->where('product_id', $product->id)->lockForUpdate()->first();
            if ($existing?->trashed()) {
                $existing->restore();
                $existing->update($this->placementPayload($data) + ['sort_order' => $data['sortOrder'] ?? ((int) $section->placements()->max('sort_order') + 1)]);
                $this->audit->log($section->tenant_id, $existing, MenuAuditAction::Restored, null, $this->snapshot($existing));

                return $existing->fresh('product.defaultVariant');
            }
            $placement = $section->placements()->create(['tenant_id' => $section->tenant_id, 'product_id' => $product->id] + $this->placementPayload($data) + ['sort_order' => $data['sortOrder'] ?? ((int) $section->placements()->max('sort_order') + 1)]);
            $this->audit->log($section->tenant_id, $placement, MenuAuditAction::Created, null, $this->snapshot($placement));

            return $placement->fresh('product.defaultVariant');
        });
    }

    public function updatePlacement(MenuItemPlacement $placement, array $data): MenuItemPlacement
    {
        $this->assertSectionUsable($placement->menuSection);

        return DB::transaction(function () use ($placement, $data): MenuItemPlacement {
            $locked = MenuItemPlacement::query()->whereKey($placement->id)->lockForUpdate()->firstOrFail();
            $before = $this->snapshot($locked);
            $locked->update($this->placementPayload($data, false));
            $this->audit->log($locked->tenant_id, $locked, MenuAuditAction::Updated, $before, $this->snapshot($locked));

            return $locked->fresh('product.defaultVariant');
        });
    }

    public function archivePlacement(MenuItemPlacement $placement): MenuItemPlacement
    {
        $this->assertSectionUsable($placement->menuSection);

        return DB::transaction(function () use ($placement): MenuItemPlacement {
            $locked = MenuItemPlacement::query()->whereKey($placement->id)->lockForUpdate()->firstOrFail();
            $before = $this->snapshot($locked);
            $locked->delete();
            $this->audit->log($locked->tenant_id, $locked, MenuAuditAction::Archived, $before, null);

            return $locked->fresh('product.defaultVariant');
        });
    }

    public function restorePlacement(MenuItemPlacement $placement): MenuItemPlacement
    {
        $this->assertSectionUsable($this->section($placement->tenant_id, $placement->menu_section_id, true));
        // Restoring placement history must never revive or activate its Product.
        // The Product may legitimately have been archived or deactivated later.
        if (! Product::withTrashed()->where('tenant_id', $placement->tenant_id)->whereKey($placement->product_id)->exists()) {
            $this->invalid('productId', 'The selected value is invalid.');
        }
        if (MenuItemPlacement::query()->where('menu_section_id', $placement->menu_section_id)->where('product_id', $placement->product_id)->exists()) {
            $this->invalid('placement', 'This product is already placed in this section.');
        }

        return DB::transaction(function () use ($placement): MenuItemPlacement {
            $locked = MenuItemPlacement::withTrashed()->whereKey($placement->id)->lockForUpdate()->firstOrFail();
            $locked->restore();
            $this->audit->log($locked->tenant_id, $locked, MenuAuditAction::Restored, null, $this->snapshot($locked));

            return $locked->fresh('product.defaultVariant');
        });
    }

    public function reorderPlacements(MenuSection $section, array $items): void
    {
        $this->assertSectionUsable($section);
        $this->uniqueIds($items);
        DB::transaction(function () use ($section, $items): void {
            $placements = $section->placements()->whereIn('id', collect($items)->pluck('id'))->lockForUpdate()->get()->keyBy('id');
            $activeIds = $section->placements()->lockForUpdate()->pluck('id')->sort()->values()->all();
            $submittedIds = collect($items)->pluck('id')->sort()->values()->all();
            $sortOrders = collect($items)->pluck('sortOrder')->sort()->values()->all();
            if ($placements->count() !== count($items) || $submittedIds !== $activeIds || $sortOrders !== range(0, count($items) - 1)) {
                $this->invalid('items', 'The selected value is invalid.');
            }
            foreach ($items as $item) {
                $placement = $placements[$item['id']];
                $before = $this->snapshot($placement);
                $placement->update(['sort_order' => $item['sortOrder']]);
                $this->audit->log($section->tenant_id, $placement, MenuAuditAction::Reordered, $before, ['sortOrder' => $placement->sort_order]);
            }
        });
    }

    public function movePlacement(MenuItemPlacement $placement, int $targetSectionId, ?int $sortOrder): MenuItemPlacement
    {
        $target = $this->section($placement->tenant_id, $targetSectionId, true);
        $this->assertSectionUsable($placement->menuSection);
        $this->assertSectionUsable($target);
        if ($target->menu_id !== $placement->menuSection->menu_id) {
            $this->invalid('targetSectionId', 'The target section must belong to the same menu.');
        }
        if ($target->id !== $placement->menu_section_id && $target->placements()->where('product_id', $placement->product_id)->exists()) {
            $this->invalid('targetSectionId', 'This product is already placed in the target section.');
        }

        return DB::transaction(function () use ($placement, $target, $sortOrder): MenuItemPlacement {
            $locked = MenuItemPlacement::query()->whereKey($placement->id)->lockForUpdate()->firstOrFail();
            $before = $this->snapshot($locked);
            $locked->update(['menu_section_id' => $target->id, 'sort_order' => $sortOrder ?? ((int) $target->placements()->max('sort_order') + 1)]);
            $this->normalizePlacements($before['menuSectionId']);
            $this->normalizePlacements($target->id);
            $this->audit->log($locked->tenant_id, $locked, MenuAuditAction::Moved, $before, $this->snapshot($locked));

            return $locked->fresh('product.defaultVariant');
        });
    }

    public function syncPlacements(MenuSection $section, array $items): array
    {
        $this->assertSectionUsable($section);
        $productIds = collect($items)->pluck('productId');
        if ($productIds->unique()->count() !== $productIds->count()) {
            $this->invalid('placements', 'Product IDs must be unique.');
        }
        foreach ($items as $item) {
            $this->validProduct($section->tenant_id, $item['productId']);
        }

        return DB::transaction(function () use ($section, $items): array {
            $existing = MenuItemPlacement::withTrashed()->where('menu_section_id', $section->id)->lockForUpdate()->get()->keyBy('id');
            $activeIds = [];
            foreach ($items as $index => $item) {
                $payload = $this->placementPayload($item) + ['sort_order' => $item['sortOrder'] ?? $index];
                if (isset($item['id'])) {
                    $placement = $existing->get($item['id']);
                    if (! $placement || $placement->product_id !== $item['productId']) {
                        $this->invalid('placements', 'The selected value is invalid.');
                    }
                    $before = $this->snapshot($placement);
                    if ($placement->trashed()) {
                        $placement->restore();
                        $action = MenuAuditAction::Restored;
                    } else {
                        $action = MenuAuditAction::Updated;
                    }
                    $placement->update($payload);
                    $activeIds[] = $placement->id;
                    $this->audit->log($section->tenant_id, $placement, $action, $before, $this->snapshot($placement));
                } else {
                    $placement = MenuItemPlacement::withTrashed()->where('menu_section_id', $section->id)->where('product_id', $item['productId'])->first();
                    if ($placement) {
                        $before = $this->snapshot($placement);
                        $placement->restore();
                        $placement->update($payload);
                        $this->audit->log($section->tenant_id, $placement, MenuAuditAction::Restored, $before, $this->snapshot($placement));
                    } else {
                        $placement = $section->placements()->create(['tenant_id' => $section->tenant_id, 'product_id' => $item['productId']] + $payload);
                        $this->audit->log($section->tenant_id, $placement, MenuAuditAction::Created, null, $this->snapshot($placement));
                    }
                    $activeIds[] = $placement->id;
                }
            }
            $section->placements()->whereNotIn('id', $activeIds)->get()->each(function (MenuItemPlacement $placement) use ($section): void {
                $before = $this->snapshot($placement);
                $placement->delete();
                $this->audit->log($section->tenant_id, $placement, MenuAuditAction::Archived, $before, null);
            });

            return $this->placements($section)->all();
        });
    }

    public function assignments(Menu $menu)
    {
        return $menu->assignments()->orderBy('priority')->orderBy('id')->get();
    }

    /**
     * Returns the authoritative assignment set for one active Branch/Channel
     * scope.  The scope endpoint is intentionally separate from per-menu sync
     * so desktop clients can reorder a whole scope atomically.
     */
    public function assignmentsForScope(int $tenantId, int $branchId, string $channel)
    {
        $this->branch($tenantId, $branchId);

        return MenuAssignment::query()->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('channel', $channel)
            ->with(['menu' => fn ($query) => $query->withTrashed()->withCount(['sections', 'assignments', 'availabilityRules'])])
            ->orderBy('priority')->orderBy('id')->get();
    }

    public function syncAssignmentsForScope(int $tenantId, int $branchId, string $channel, array $items): array
    {
        $this->branch($tenantId, $branchId);
        $menuIds = collect($items)->pluck('menuId');
        if ($menuIds->unique()->count() !== $menuIds->count()) {
            $this->invalid('assignments', 'Menu IDs must be unique.');
        }
        $menus = Menu::query()->withTrashed()->where('tenant_id', $tenantId)->whereIn('id', $menuIds)->get()->keyBy('id');
        if ($menus->count() !== $menuIds->count()) {
            $this->invalid('assignments', 'One or more menus are invalid.');
        }
        foreach ($menus as $menu) {
            $this->assertMenuUsable($menu);
        }

        return DB::transaction(function () use ($tenantId, $branchId, $channel, $items): array {
            $existing = MenuAssignment::query()->where('tenant_id', $tenantId)->where('branch_id', $branchId)->where('channel', $channel)->lockForUpdate()->get()->keyBy('menu_id');
            $kept = [];
            foreach ($items as $index => $item) {
                $menuId = $item['menuId'];
                $kept[] = $menuId;
                // The submitted complete list is the intended scope order.
                // Normalize it here so a scope can never retain sparse or
                // duplicate priorities after a successful sync.
                $payload = ['priority' => $index, 'is_active' => $item['isActive'] ?? true];
                $assignment = $existing->get($menuId);
                if ($assignment) {
                    $before = $this->snapshot($assignment);
                    $assignment->update($payload);
                    $this->audit->log($tenantId, $assignment, MenuAuditAction::Assigned, $before, $this->snapshot($assignment));
                } else {
                    $assignment = MenuAssignment::query()->create(['tenant_id' => $tenantId, 'menu_id' => $menuId, 'branch_id' => $branchId, 'channel' => $channel] + $payload);
                    $this->audit->log($tenantId, $assignment, MenuAuditAction::Assigned, null, $this->snapshot($assignment));
                }
            }
            $existing->filter(fn (MenuAssignment $assignment) => ! in_array((int) $assignment->menu_id, $kept, true))->each(function (MenuAssignment $assignment) use ($tenantId): void {
                $this->audit->log($tenantId, $assignment, MenuAuditAction::Unassigned, $this->snapshot($assignment));
                $assignment->delete();
            });

            return $this->assignmentsForScope($tenantId, $branchId, $channel)->all();
        });
    }

    public function syncAssignments(Menu $menu, array $items): array
    {
        $this->assertMenuUsable($menu);
        $keys = collect($items)->map(fn ($item) => $item['branchId'].'|'.$item['channel']);
        if ($keys->unique()->count() !== $keys->count()) {
            $this->invalid('assignments', 'Branch and channel combinations must be unique.');
        }
        foreach ($items as $item) {
            $this->branch($menu->tenant_id, $item['branchId']);
        }

        return DB::transaction(function () use ($menu, $items): array {
            $existing = $menu->assignments()->lockForUpdate()->get()->keyBy(fn ($a) => $a->branch_id.'|'.($a->channel instanceof \BackedEnum ? $a->channel->value : $a->channel));
            $keys = [];
            foreach ($items as $item) {
                $key = $item['branchId'].'|'.$item['channel'];
                $keys[] = $key;
                $assignment = $existing->get($key);
                $payload = ['branch_id' => $item['branchId'], 'channel' => $item['channel'], 'priority' => $item['priority'] ?? 0, 'is_active' => $item['isActive'] ?? true];
                if ($assignment) {
                    $before = $this->snapshot($assignment);
                    $assignment->update($payload);
                    $this->audit->log($menu->tenant_id, $assignment, MenuAuditAction::Assigned, $before, $this->snapshot($assignment));
                } else {
                    $assignment = $menu->assignments()->create(['tenant_id' => $menu->tenant_id] + $payload);
                    $this->audit->log($menu->tenant_id, $assignment, MenuAuditAction::Assigned, null, $this->snapshot($assignment));
                }
            }
            $existing->except($keys)->each(function (MenuAssignment $assignment) use ($menu): void {
                $this->audit->log($menu->tenant_id, $assignment, MenuAuditAction::Unassigned, $this->snapshot($assignment));
                $assignment->delete();
            });

            return $this->assignments($menu)->all();
        });
    }

    public function availabilityRules(Menu $menu)
    {
        return $menu->availabilityRules()->orderBy('priority')->orderBy('id')->get();
    }

    public function syncAvailabilityRules(Menu $menu, array $items): array
    {
        $this->assertMenuUsable($menu);
        $canonical = [];
        foreach ($items as $item) {
            if (isset($item['branchId'])) {
                $this->branch($menu->tenant_id, $item['branchId']);
            }
            $key = implode('|', [$item['branchId'] ?? '', $item['channel'] ?? '', $item['dayOfWeek'] ?? '', $item['startTime'] ?? '', $item['endTime'] ?? '', $item['startDate'] ?? '', $item['endDate'] ?? '', $item['priority'] ?? 0]);
            if (in_array($key, $canonical, true)) {
                $this->invalid('rules', 'Duplicate availability rules are not allowed.');
            }
            $canonical[] = $key;
        }

        return DB::transaction(function () use ($menu, $items): array {
            $old = $menu->availabilityRules()->lockForUpdate()->get();
            foreach ($old as $rule) {
                $this->audit->log($menu->tenant_id, $rule, MenuAuditAction::AvailabilityChanged, $this->snapshot($rule));
                $rule->delete();
            }
            foreach ($items as $item) {
                $rule = $menu->availabilityRules()->create(['tenant_id' => $menu->tenant_id] + $this->rulePayload($item));
                $this->audit->log($menu->tenant_id, $rule, MenuAuditAction::AvailabilityChanged, null, $this->snapshot($rule));
            }

            return $this->availabilityRules($menu)->all();
        });
    }

    public function usage(Product $product, bool $includeArchived): array
    {
        $query = MenuItemPlacement::query()->where('tenant_id', $product->tenant_id)->where('product_id', $product->id)->with(['menuSection.menu']);
        if ($includeArchived) {
            $query->withTrashed()->with(['menuSection' => fn ($q) => $q->withTrashed()->with(['menu' => fn ($m) => $m->withTrashed()])]);
        } else {
            $query->whereHas('menuSection', fn ($section) => $section->where('is_active', true)->whereHas('menu', fn ($menu) => $menu->where('status', '!=', MenuStatus::Archived)));
        }
        $placements = $query->orderBy('sort_order')->orderBy('id')->get();

        return ['productId' => $product->id, 'activePlacementCount' => $placements->filter(fn ($p) => ! $p->trashed() && ! $p->menuSection->trashed() && ! $p->menuSection->menu->trashed())->count(), 'menus' => $placements->map(fn ($p) => ['menuId' => $p->menuSection->menu_id, 'menuName' => $p->menuSection->menu->name, 'sectionId' => $p->menu_section_id, 'sectionName' => $p->menuSection->name, 'placementId' => $p->id, 'isVisible' => (bool) $p->is_visible, 'isFeatured' => (bool) $p->is_featured, 'sortOrder' => $p->sort_order])->values()->all()];
    }

    private function menuPayload(array $data, bool $create = true): array
    {
        $map = ['name' => 'name', 'nameAr' => 'name_ar', 'nameEn' => 'name_en', 'description' => 'description', 'descriptionAr' => 'description_ar', 'descriptionEn' => 'description_en', 'coverImageUrl' => 'cover_image_url', 'status' => 'status', 'priority' => 'priority'];
        $payload = [];
        foreach ($map as $input => $column) {
            if (array_key_exists($input, $data)) {
                $payload[$column] = $data[$input];
            }
        }

        return $create ? ['status' => $payload['status'] ?? MenuStatus::Draft->value, 'priority' => $payload['priority'] ?? 0] + $payload : $payload;
    }

    private function sectionPayload(array $data, bool $create = true): array
    {
        $map = ['name' => 'name', 'nameAr' => 'name_ar', 'nameEn' => 'name_en', 'description' => 'description', 'imageUrl' => 'image_url', 'sortOrder' => 'sort_order', 'isActive' => 'is_active'];
        $payload = [];
        foreach ($map as $input => $column) {
            if (array_key_exists($input, $data)) {
                $payload[$column] = $data[$input];
            }
        }

        return $create ? ['is_active' => $payload['is_active'] ?? true] + $payload : $payload;
    }

    private function placementPayload(array $data, bool $create = true): array
    {
        $map = ['displayNameOverride' => 'display_name_override', 'displayDescriptionOverride' => 'display_description_override', 'displayImageOverride' => 'display_image_override', 'sortOrder' => 'sort_order', 'isFeatured' => 'is_featured', 'isVisible' => 'is_visible'];
        $payload = [];
        foreach ($map as $input => $column) {
            if (array_key_exists($input, $data)) {
                $payload[$column] = $data[$input];
            }
        }

        return $create ? ['is_featured' => $payload['is_featured'] ?? false, 'is_visible' => $payload['is_visible'] ?? true] + $payload : $payload;
    }

    private function rulePayload(array $data): array
    {
        return ['branch_id' => $data['branchId'] ?? null, 'channel' => $data['channel'] ?? null, 'day_of_week' => $data['dayOfWeek'] ?? null, 'start_time' => $data['startTime'] ?? null, 'end_time' => $data['endTime'] ?? null, 'start_date' => $data['startDate'] ?? null, 'end_date' => $data['endDate'] ?? null, 'priority' => $data['priority'] ?? 0, 'is_active' => $data['isActive'] ?? true];
    }

    private function branch(int $tenantId, int $id): Branch
    {
        $branch = Branch::query()->where('tenant_id', $tenantId)->where('is_active', true)->find($id);
        if (! $branch) {
            $this->invalid('branchId', 'The selected value is invalid.');
        }

        return $branch;
    }

    private function validProduct(int $tenantId, int $id): Product
    {
        $product = Product::query()->where('tenant_id', $tenantId)->whereHas('variants', fn ($q) => $q->where('is_active', true))->find($id);
        if (! $product) {
            $this->invalid('productId', 'The selected value is invalid.');
        }

        return $product;
    }

    private function assertMenuUsable(Menu $menu): void
    {
        if ($menu->trashed() || $menu->status === MenuStatus::Archived) {
            $this->invalid('menu', 'The selected value is invalid.');
        }
    }

    private function assertSectionUsable(MenuSection $section): void
    {
        $menu = $section->menu;
        if ($section->trashed() || ! $section->is_active || ! $menu || $menu->trashed() || $menu->status === MenuStatus::Archived) {
            $this->invalid('section', 'The selected value is invalid.');
        }
    }

    private function uniqueMenuName(int $tenantId, string $name, ?int $ignore = null): void
    {
        if (Menu::query()->where('tenant_id', $tenantId)->whereRaw('LOWER(name) = ?', [strtolower($name)])->when($ignore, fn ($q) => $q->whereKeyNot($ignore))->exists()) {
            $this->invalid('name', 'The name has already been taken.');
        }
    }

    private function uniqueSectionName(Menu $menu, string $name, ?int $ignore = null): void
    {
        if ($menu->sections()->whereRaw('LOWER(name) = ?', [strtolower($name)])->when($ignore, fn ($q) => $q->whereKeyNot($ignore))->exists()) {
            $this->invalid('name', 'The name has already been taken.');
        }
    }

    private function uniqueIds(array $items): void
    {
        $ids = collect($items)->pluck('id');
        if ($ids->unique()->count() !== $ids->count()) {
            $this->invalid('items', 'Duplicate IDs are not allowed.');
        }
    }

    private function normalizePlacements(int $sectionId): void
    {
        MenuItemPlacement::query()->where('menu_section_id', $sectionId)->orderBy('sort_order')->orderBy('id')->lockForUpdate()->get()->each(fn (MenuItemPlacement $p, int $index) => $p->update(['sort_order' => $index]));
    }

    private function snapshot($model): array
    {
        $data = $model->getAttributes();
        unset($data['tenant_id'], $data['deleted_at']);

        return collect($data)->mapWithKeys(fn ($value, $key) => [str($key)->camel()->toString() => $value instanceof \BackedEnum ? $value->value : $value])->all();
    }

    private function invalid(string $field, string $message): never
    {
        throw ValidationException::withMessages([$field => $message]);
    }
}
