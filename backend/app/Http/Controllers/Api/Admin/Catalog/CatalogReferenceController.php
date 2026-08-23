<?php

namespace App\Http\Controllers\Api\Admin\Catalog;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Http\Controllers\Controller;
use App\Http\Resources\Catalog\CatalogCategoryResource;
use App\Http\Resources\Catalog\KitchenStationResource;
use App\Http\Resources\Catalog\ReportingCategoryResource;
use App\Models\Category;
use App\Models\KitchenStation;
use App\Models\ReportingCategory;
use App\Services\Catalog\CatalogAuditService;
use App\Support\TenantContext;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class CatalogReferenceController extends Controller
{
    public function __construct(private readonly CatalogAuditService $audit) {}

    public function categories(Request $request): JsonResponse
    {
        return $this->index($request, 'category');
    }

    public function reportingCategories(Request $request): JsonResponse
    {
        return $this->index($request, 'reporting');
    }

    public function kitchenStations(Request $request): JsonResponse
    {
        return $this->index($request, 'station');
    }

    public function storeCategory(Request $request): JsonResponse
    {
        return $this->store($request, 'category');
    }

    public function storeReportingCategory(Request $request): JsonResponse
    {
        return $this->store($request, 'reporting');
    }

    public function storeKitchenStation(Request $request): JsonResponse
    {
        return $this->store($request, 'station');
    }

    public function showCategory(Request $request, int $category): JsonResponse
    {
        return $this->show($request, 'category', $category);
    }

    public function showReportingCategory(Request $request, int $reportingCategory): JsonResponse
    {
        return $this->show($request, 'reporting', $reportingCategory);
    }

    public function showKitchenStation(Request $request, int $kitchenStation): JsonResponse
    {
        return $this->show($request, 'station', $kitchenStation);
    }

    public function updateCategory(Request $request, int $category): JsonResponse
    {
        return $this->update($request, 'category', $category);
    }

    public function updateReportingCategory(Request $request, int $reportingCategory): JsonResponse
    {
        return $this->update($request, 'reporting', $reportingCategory);
    }

    public function updateKitchenStation(Request $request, int $kitchenStation): JsonResponse
    {
        return $this->update($request, 'station', $kitchenStation);
    }

    public function archiveCategory(Request $request, int $category): JsonResponse
    {
        return $this->archive($request, 'category', $category);
    }

    public function archiveReportingCategory(Request $request, int $reportingCategory): JsonResponse
    {
        return $this->archive($request, 'reporting', $reportingCategory);
    }

    public function archiveKitchenStation(Request $request, int $kitchenStation): JsonResponse
    {
        return $this->archive($request, 'station', $kitchenStation);
    }

    public function restoreCategory(Request $request, int $category): JsonResponse
    {
        return $this->restore($request, 'category', $category);
    }

    public function restoreReportingCategory(Request $request, int $reportingCategory): JsonResponse
    {
        return $this->restore($request, 'reporting', $reportingCategory);
    }

    public function restoreKitchenStation(Request $request, int $kitchenStation): JsonResponse
    {
        return $this->restore($request, 'station', $kitchenStation);
    }

    public function reorderCategories(Request $request): JsonResponse
    {
        return $this->reorder($request, 'category');
    }

    public function reorderReportingCategories(Request $request): JsonResponse
    {
        return $this->reorder($request, 'reporting');
    }

    public function reorderKitchenStations(Request $request): JsonResponse
    {
        return $this->reorder($request, 'station');
    }

    private function index(Request $request, string $kind): JsonResponse
    {
        $model = $this->model($kind);
        $tenantId = TenantContext::id($request);
        $query = $model::query()->where('tenant_id', $tenantId)->withCount('products');
        $this->status($query, $request->query('status', 'active'));
        if ($request->filled('search')) {
            $search = '%'.strtolower($request->query('search')).'%';
            $query->where(function (Builder $q) use ($search, $kind): void {
                $q->whereRaw('LOWER(name) LIKE ?', [$search])
                    ->orWhereRaw('LOWER(COALESCE(name_ar, \'\')) LIKE ?', [$search])
                    ->orWhereRaw('LOWER(COALESCE(name_en, \'\')) LIKE ?', [$search]);
                if ($kind !== 'category') {
                    $q->orWhereRaw('LOWER(COALESCE(code, \'\')) LIKE ?', [$search]);
                }
            });
        }
        $sort = in_array($request->query('sort'), ['name', 'sort_order', 'created_at'], true) ? $request->query('sort') : 'sort_order';
        $query->orderBy($sort, $request->query('direction') === 'desc' ? 'desc' : 'asc')->orderBy('id');

        return $this->paginated($request, $query->paginate(min((int) $request->query('perPage', 20), 100)), $kind);
    }

    private function store(Request $request, string $kind): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $this->validate($request, $kind);
        $model = $this->model($kind);
        $this->validateUnique($model, $tenantId, $data);
        $record = DB::transaction(function () use ($model, $tenantId, $data, $kind) {
            $record = $model::query()->create(['tenant_id' => $tenantId] + $this->payload($kind, $data));
            $this->audit->log($tenantId, $record, MenuAuditAction::Created, null, $record->toArray());

            return $record;
        });

        return response()->json(['data' => $this->resource($kind, $record)->resolve($request)], 201);
    }

    private function show(Request $request, string $kind, int $id): JsonResponse
    {
        return response()->json(['data' => $this->resource($kind, $this->find($kind, TenantContext::id($request), $id, $request->boolean('includeArchived')))->resolve($request)]);
    }

    private function update(Request $request, string $kind, int $id): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $record = $this->find($kind, $tenantId, $id);
        $data = $this->validate($request, $kind, false);
        $this->validateUnique($this->model($kind), $tenantId, $data, $record->id);
        DB::transaction(function () use ($record, $data, $kind, $tenantId) {
            $before = $record->toArray();
            $record->update($this->payload($kind, $data, $record));
            $this->audit->log($tenantId, $record, MenuAuditAction::Updated, $before, $record->fresh()->toArray());
        });

        return response()->json(['data' => $this->resource($kind, $record->fresh())->resolve($request)]);
    }

    private function archive(Request $request, string $kind, int $id): JsonResponse
    {
        $record = $this->find($kind, TenantContext::id($request), $id);
        $active = $record->products()->where('is_active', true)->count();
        if (in_array($kind, ['category', 'station'], true) && $active) {
            throw ValidationException::withMessages([$kind => "Move or archive the {$active} active products before archiving this {$kind}."]);
        }
        DB::transaction(function () use ($record) {
            $before = $record->toArray();
            $record->update(['is_active' => false]);
            $record->delete();
            $this->audit->log($record->tenant_id, $record, MenuAuditAction::Archived, $before, ['isActive' => false]);
        });

        return response()->json(['message' => ucfirst($kind).' archived successfully.', 'data' => $this->resource($kind, $record)->resolve($request)]);
    }

    private function restore(Request $request, string $kind, int $id): JsonResponse
    {
        $record = $this->find($kind, TenantContext::id($request), $id, true);
        if (! $record->trashed()) {
            return response()->json(['data' => $this->resource($kind, $record)->resolve($request)]);
        }
        DB::transaction(function () use ($record) {
            $record->restore();
            $record->update(['is_active' => true]);
            $this->audit->log($record->tenant_id, $record, MenuAuditAction::Restored, null, $record->fresh()->toArray());
        });

        return response()->json(['message' => ucfirst($kind).' restored successfully.', 'data' => $this->resource($kind, $record->fresh())->resolve($request)]);
    }

    private function reorder(Request $request, string $kind): JsonResponse
    {
        $data = $request->validate(['items' => ['required', 'array'], 'items.*.id' => ['required', 'integer'], 'items.*.sortOrder' => ['required', 'integer']]);
        $tenantId = TenantContext::id($request);
        $model = $this->model($kind);
        $ids = collect($data['items'])->pluck('id');
        DB::transaction(function () use ($model, $tenantId, $ids, $data) {
            if ($ids->unique()->count() !== $ids->count() || $model::query()->where('tenant_id', $tenantId)->whereIn('id', $ids)->count() !== $ids->count()) {
                throw ValidationException::withMessages(['items' => 'One or more IDs are invalid.']);
            } foreach ($data['items'] as $item) {
                $model::query()->where('tenant_id', $tenantId)->where('id', $item['id'])->update(['sort_order' => $item['sortOrder']]);
            } $this->audit->log($tenantId, $model, MenuAuditAction::Reordered, null, ['items' => $data['items']]);
        });

        return response()->json(['message' => ucfirst($kind).' order updated successfully.', 'data' => $data['items']]);
    }

    private function validate(Request $request, string $kind, bool $create = true): array
    {
        $rules = [
            'name' => [$create ? 'required' : 'sometimes', 'string', 'max:255'],
            'sortOrder' => ['nullable', 'integer'],
            'isActive' => ['nullable', 'boolean'],
        ];
        $rules += [
            'nameAr' => ['nullable', 'string', 'max:255'],
            'nameEn' => ['nullable', 'string', 'max:255'],
        ];
        if ($kind === 'category') {
            $rules += ['description' => ['nullable', 'string']];
        } else {
            $rules += [
                'code' => ['nullable', 'string', 'max:255'],
            ];
        }
        if ($kind === 'reporting') {
            $rules += ['description' => ['nullable', 'string']];
        }
        if ($kind === 'station') {
            $rules += ['branchId' => ['nullable', 'integer', Rule::exists('branches', 'id')->where(fn ($q) => $q->where('tenant_id', TenantContext::id($request))->whereNull('deleted_at'))], 'printerName' => ['nullable', 'string', 'max:255']];
        }

        return $request->validate($rules);
    }

    private function validateUnique(string $model, int $tenantId, array $data, ?int $ignore = null): void
    {
        foreach (($model === Category::class ? ['name'] : ['code']) as $field) {
            if (! empty($data[$field]) && $model::query()->where('tenant_id', $tenantId)->whereRaw('LOWER('.$field.') = ?', [strtolower($data[$field])])->when($ignore, fn ($q) => $q->where('id', '!=', $ignore))->exists()) {
                throw ValidationException::withMessages([$field => 'This value has already been taken.']);
            }
        }
    }

    private function payload(string $kind, array $data, ?object $current = null): array
    {
        $value = fn (string $field, string $column, mixed $fallback = null): mixed => array_key_exists($field, $data) ? $data[$field] : ($current?->{$column} ?? $fallback);
        $payload = ['name' => $value('name', 'name'), 'sort_order' => $value('sortOrder', 'sort_order', 0), 'is_active' => $value('isActive', 'is_active', true)];
        $payload += ['name_ar' => $value('nameAr', 'name_ar'), 'name_en' => $value('nameEn', 'name_en')];
        if ($kind !== 'category') {
            $payload += ['code' => $value('code', 'code')];
            if ($kind === 'reporting') {
                $payload['description'] = $value('description', 'description');
            }
        } else {
            $payload['description'] = $value('description', 'description');
        } if ($kind === 'station') {
            $payload += ['branch_id' => $value('branchId', 'branch_id'), 'printer_name' => $value('printerName', 'printer_name')];
        }

        return $payload;
    }

    private function find(string $kind, int $tenantId, int $id, bool $trashed = false): object
    {
        $model = $this->model($kind);

        return $model::query()->when($trashed, fn ($q) => $q->withTrashed())->where('tenant_id', $tenantId)->findOrFail($id);
    }

    private function model(string $kind): string
    {
        return ['category' => Category::class, 'reporting' => ReportingCategory::class, 'station' => KitchenStation::class][$kind];
    }

    private function resource(string $kind, object $record): object
    {
        $resource = ['category' => CatalogCategoryResource::class, 'reporting' => ReportingCategoryResource::class, 'station' => KitchenStationResource::class][$kind];

        return new $resource($record);
    }

    private function status(Builder $query, string $status): void
    {
        if ($status === 'all') {
            $query->withTrashed();
        } elseif ($status === 'archived') {
            $query->onlyTrashed();
        } else {
            $query->where('is_active', true);
        }
    }

    private function paginated(Request $request, $page, string $kind): JsonResponse
    {
        return response()->json(['data' => collect($page->items())->map(fn ($item) => $this->resource($kind, $item)->resolve($request))->values(), 'meta' => ['currentPage' => $page->currentPage(), 'lastPage' => $page->lastPage(), 'perPage' => $page->perPage(), 'total' => $page->total()]]);
    }
}
