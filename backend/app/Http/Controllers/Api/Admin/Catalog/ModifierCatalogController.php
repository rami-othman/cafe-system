<?php

namespace App\Http\Controllers\Api\Admin\Catalog;

use App\Http\Controllers\Controller;
use App\Http\Resources\Catalog\ModifierGroupResource;
use App\Http\Resources\Catalog\ModifierOptionResource;
use App\Models\ModifierGroup;
use App\Models\ModifierOption;
use App\Services\Catalog\ModifierGroupService;
use App\Support\TenantContext;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ModifierCatalogController extends Controller
{
    public function __construct(private readonly ModifierGroupService $groups) {}

    public function index(Request $request): JsonResponse
    {
        $tenant = TenantContext::id($request);
        $query = ModifierGroup::query()->where('tenant_id', $tenant)->with([
            'optionPreview' => fn ($q) => $q
                ->where('tenant_id', $tenant)
                ->orderBy('sort_order')
                ->orderBy('id')
                ->limit(3),
        ])->withCount([
            'options' => fn ($q) => $q->where('tenant_id', $tenant),
            'options as active_options_count' => fn ($q) => $q->where('tenant_id', $tenant)->where('is_active', true),
        ]);
        $status = $request->query('status', 'active');
        if ($status === 'all') {
            $query->withTrashed();
        } elseif ($status === 'archived') {
            $query->onlyTrashed();
        } elseif ($status === 'inactive') {
            $query->where('is_active', false);
        } else {
            $query->where('is_active', true);
        }
        if ($request->filled('search')) {
            $search = '%'.strtolower($request->query('search')).'%';
            $query->where(fn (Builder $q) => $q->whereRaw('LOWER(name) LIKE ?', [$search])->orWhereRaw('LOWER(COALESCE(code, \'\')) LIKE ?', [$search]));
        }
        foreach (['groupType' => 'group_type', 'selectionType' => 'selection_type'] as $key => $column) {
            if ($request->filled($key)) {
                $query->where($column, $request->query($key));
            }
        } if ($request->filled('usedByProductId')) {
            $query->whereHas('products', fn ($q) => $q->where('products.id', $request->query('usedByProductId')));
        }
        $sort = in_array($request->query('sort'), ['name', 'sort_order', 'created_at'], true) ? $request->query('sort') : 'sort_order';
        $page = $query->orderBy($sort)->orderBy('id')->paginate(min((int) $request->query('perPage', 20), 100));

        return response()->json(['data' => collect($page->items())->map(fn ($group) => (new ModifierGroupResource($group))->resolve($request)), 'meta' => ['currentPage' => $page->currentPage(), 'lastPage' => $page->lastPage(), 'perPage' => $page->perPage(), 'total' => $page->total()]]);
    }

    public function show(Request $request, int $modifierGroup): JsonResponse
    {
        $data = $request->validate([
            'includeArchived' => ['nullable', Rule::in(['true', 'false', '1', '0', true, false, 1, 0])],
        ]);
        $includeArchived = array_key_exists('includeArchived', $data)
            && $request->boolean('includeArchived');

        return response()->json(['data' => (new ModifierGroupResource($this->findGroup(TenantContext::id($request), $modifierGroup, $includeArchived)))->resolve($request)]);
    }

    public function store(Request $request): JsonResponse
    {
        $group = $this->groups->create(TenantContext::id($request), $this->groupData($request, true));

        return response()->json(['data' => (new ModifierGroupResource($group))->resolve($request)], 201);
    }

    public function update(Request $request, int $modifierGroup): JsonResponse
    {
        $group = $this->findGroup(TenantContext::id($request), $modifierGroup);
        $data = array_replace($this->groupCurrent($group), $this->groupData($request, false));

        return response()->json(['data' => (new ModifierGroupResource($this->groups->update($group, $data)))->resolve($request)]);
    }

    public function archive(Request $request, int $modifierGroup): JsonResponse
    {
        $group = $this->groups->archive($this->findGroup(TenantContext::id($request), $modifierGroup));

        return response()->json(['message' => 'Modifier group archived successfully.', 'data' => (new ModifierGroupResource($group))->resolve($request)]);
    }

    public function restore(Request $request, int $modifierGroup): JsonResponse
    {
        $group = $this->groups->restore($this->findGroup(TenantContext::id($request), $modifierGroup, true));

        return response()->json(['message' => 'Modifier group restored successfully.', 'data' => (new ModifierGroupResource($group))->resolve($request)]);
    }

    public function reorder(Request $request): JsonResponse
    {
        $data = $request->validate(['items' => ['required', 'array', 'min:1'], 'items.*.id' => ['required', 'integer'], 'items.*.sortOrder' => ['required', 'integer', 'min:0']]);
        $this->groups->reorderGroups(TenantContext::id($request), $data['items']);

        return response()->json(['message' => 'Modifier groups reordered successfully.', 'data' => $data['items']]);
    }

    public function storeOption(Request $request, int $modifierGroup): JsonResponse
    {
        $option = $this->groups->createOption($this->findGroup(TenantContext::id($request), $modifierGroup), $this->optionData($request, true));

        return response()->json(['data' => (new ModifierOptionResource($option))->resolve($request)], 201);
    }

    public function updateOption(Request $request, int $modifierOption): JsonResponse
    {
        $option = $this->findOption(TenantContext::id($request), $modifierOption);
        $data = array_replace($this->optionCurrent($option), $this->optionData($request, false));

        return response()->json(['data' => (new ModifierOptionResource($this->groups->updateOption($option, $data)))->resolve($request)]);
    }

    public function archiveOption(Request $request, int $modifierOption): JsonResponse
    {
        $option = $this->groups->archiveOption($this->findOption(TenantContext::id($request), $modifierOption));

        return response()->json(['message' => 'Modifier option archived successfully.', 'data' => (new ModifierOptionResource($option))->resolve($request)]);
    }

    public function restoreOption(Request $request, int $modifierOption): JsonResponse
    {
        $option = $this->groups->restoreOption($this->findOption(TenantContext::id($request), $modifierOption, true));

        return response()->json(['message' => 'Modifier option restored successfully.', 'data' => (new ModifierOptionResource($option))->resolve($request)]);
    }

    public function reorderOptions(Request $request, int $modifierGroup): JsonResponse
    {
        $data = $request->validate(['items' => ['required', 'array'], 'items.*.id' => ['required', 'integer'], 'items.*.sortOrder' => ['required', 'integer']]);
        $this->groups->reorder($this->findGroup(TenantContext::id($request), $modifierGroup), $data['items']);

        return response()->json(['message' => 'Modifier options reordered successfully.', 'data' => $data['items']]);
    }

    private function findGroup(int $tenant, int $id, bool $includeArchived = false): ModifierGroup
    {
        return ModifierGroup::query()
            ->when($includeArchived, fn ($q) => $q->withTrashed())
            ->where('tenant_id', $tenant)
            ->with(['options' => fn ($q) => $q
                ->where('tenant_id', $tenant)
                ->when($includeArchived, fn ($options) => $options->withTrashed())
                ->orderBy('sort_order')
                ->orderBy('id')])
            ->withCount([
                'options' => fn ($q) => $q->where('tenant_id', $tenant),
                'options as active_options_count' => fn ($q) => $q->where('tenant_id', $tenant)->where('is_active', true),
            ])
            ->findOrFail($id);
    }

    private function findOption(int $tenant, int $id, bool $trashed = false): ModifierOption
    {
        return ModifierOption::query()->when($trashed, fn ($q) => $q->withTrashed())->where('tenant_id', $tenant)->with('modifierGroup')->findOrFail($id);
    }

    private function groupData(Request $request, bool $create): array
    {
        $rules = ['name' => [$create ? 'required' : 'sometimes', 'string'], 'nameAr' => ['nullable', 'string'], 'nameEn' => ['nullable', 'string'], 'code' => ['nullable', 'string'], 'groupType' => ['nullable', Rule::in(['choice', 'add_on', 'preparation_instruction'])], 'selectionType' => ['nullable', Rule::in(['single', 'multiple'])], 'isRequired' => ['nullable', 'boolean'], 'minSelections' => ['nullable', 'integer', 'min:0'], 'maxSelections' => ['nullable', 'integer', 'min:0'], 'allowQuantity' => ['nullable', 'boolean'], 'sortOrder' => ['nullable', 'integer'], 'isActive' => ['nullable', 'boolean']];
        if ($create) {
            $rules += ['options' => ['required', 'array', 'min:1'], 'options.*.name' => ['required', 'string'], 'options.*.nameAr' => ['nullable', 'string'], 'options.*.nameEn' => ['nullable', 'string'], 'options.*.priceDelta' => ['nullable', 'decimal:0,2'], 'options.*.costDelta' => ['nullable', 'numeric', 'min:0'], 'options.*.isDefault' => ['nullable', 'boolean'], 'options.*.isActive' => ['nullable', 'boolean'], 'options.*.isAvailable' => ['nullable', 'boolean'], 'options.*.sortOrder' => ['nullable', 'integer']];
        }

        return $request->validate($rules);
    }

    private function optionData(Request $request, bool $create): array
    {
        return $request->validate(['name' => [$create ? 'required' : 'sometimes', 'string'], 'nameAr' => ['nullable', 'string'], 'nameEn' => ['nullable', 'string'], 'priceDelta' => ['nullable', 'decimal:0,2'], 'costDelta' => ['nullable', 'numeric', 'min:0'], 'isDefault' => ['nullable', 'boolean'], 'isActive' => ['nullable', 'boolean'], 'isAvailable' => ['nullable', 'boolean'], 'sortOrder' => ['nullable', 'integer']]);
    }

    private function groupCurrent(ModifierGroup $g): array
    {
        return ['name' => $g->name, 'nameAr' => $g->name_ar, 'nameEn' => $g->name_en, 'code' => $g->code, 'groupType' => $g->group_type->value, 'selectionType' => $g->selection_type, 'isRequired' => $g->is_required, 'minSelections' => $g->min_selections, 'maxSelections' => $g->max_selections, 'allowQuantity' => $g->allow_quantity, 'sortOrder' => $g->sort_order, 'isActive' => $g->is_active];
    }

    private function optionCurrent(ModifierOption $o): array
    {
        return ['name' => $o->name, 'nameAr' => $o->name_ar, 'nameEn' => $o->name_en, 'priceDelta' => $o->price_delta, 'costDelta' => $o->cost_delta, 'isDefault' => $o->is_default, 'isActive' => $o->is_active, 'isAvailable' => $o->is_available, 'sortOrder' => $o->sort_order];
    }
}
