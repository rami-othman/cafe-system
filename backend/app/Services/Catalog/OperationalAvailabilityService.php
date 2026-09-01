<?php

namespace App\Services\Catalog;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Domain\Menu\Enums\OperationalAvailabilityStatus;
use App\Models\Branch;
use App\Models\Product;
use App\Models\ProductOperationalAvailability;
use App\Models\ProductVariant;
use App\Models\ProductVariantOperationalAvailability;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class OperationalAvailabilityService
{
    public function __construct(private readonly CatalogAuditService $audit) {}

    public function product(int $tenantId, int $productId): Product
    {
        return Product::query()->where('tenant_id', $tenantId)->where('is_active', true)->findOrFail($productId);
    }

    public function variant(int $tenantId, int $variantId): ProductVariant
    {
        return ProductVariant::query()->where('tenant_id', $tenantId)->where('is_active', true)
            ->whereHas('product', fn (Builder $query) => $query->where('tenant_id', $tenantId)->where('is_active', true))
            ->with('product')->findOrFail($variantId);
    }

    public function branch(int $tenantId, int $branchId): Branch
    {
        $branch = Branch::query()->where('tenant_id', $tenantId)->where('is_active', true)->find($branchId);
        if (! $branch) {
            throw ValidationException::withMessages(['branchId' => 'The selected branch is invalid or archived.']);
        }

        return $branch;
    }

    public function upsertProduct(int $tenantId, int $productId, array $data): ProductOperationalAvailability
    {
        $product = $this->product($tenantId, $productId);
        $branch = $this->branch($tenantId, $data['branchId']);
        $this->validateTemporaryExpiration($data, $branch);

        return $this->upsert(ProductOperationalAvailability::class, $tenantId, 'product_id', $product->id, $data, $branch);
    }

    public function upsertVariant(int $tenantId, int $variantId, array $data): ProductVariantOperationalAvailability
    {
        $variant = $this->variant($tenantId, $variantId);
        $branch = $this->branch($tenantId, $data['branchId']);
        $this->validateTemporaryExpiration($data, $branch);

        return $this->upsert(ProductVariantOperationalAvailability::class, $tenantId, 'product_variant_id', $variant->id, $data, $branch);
    }

    public function clearProduct(int $tenantId, int $productId, array $data): bool
    {
        $product = $this->product($tenantId, $productId);
        $this->branch($tenantId, $data['branchId']);

        return $this->clear(ProductOperationalAvailability::class, $tenantId, 'product_id', $product->id, $data);
    }

    public function clearVariant(int $tenantId, int $variantId, array $data): bool
    {
        $variant = $this->variant($tenantId, $variantId);
        $this->branch($tenantId, $data['branchId']);

        return $this->clear(ProductVariantOperationalAvailability::class, $tenantId, 'product_variant_id', $variant->id, $data);
    }

    public function list(int $tenantId, array $filters, ?array $accessibleBranchIds = null): LengthAwarePaginator
    {
        $archived = (bool) ($filters['includeArchived'] ?? false);
        $products = DB::table('product_operational_availabilities as oa')->join('products as p', 'p.id', '=', 'oa.product_id')->join('branches as b', 'b.id', '=', 'oa.branch_id')
            ->where('oa.tenant_id', $tenantId)->when($accessibleBranchIds !== null, fn ($q) => $q->whereIn('oa.branch_id', $accessibleBranchIds))->selectRaw("oa.id, 'product' as level, oa.product_id, p.name as product_name, null as product_variant_id, null as variant_name, oa.branch_id, b.name as branch_name, b.timezone as branch_timezone, oa.channel, oa.status, oa.remaining_quantity, oa.unavailable_until, oa.reason, oa.created_at, oa.updated_at")
            ->when(! $archived, fn ($q) => $q->whereNull('p.deleted_at')->where('p.is_active', true)->whereNull('b.deleted_at')->where('b.is_active', true));
        $variants = DB::table('product_variant_operational_availabilities as oa')->join('product_variants as v', 'v.id', '=', 'oa.product_variant_id')->join('products as p', 'p.id', '=', 'v.product_id')->join('branches as b', 'b.id', '=', 'oa.branch_id')
            ->where('oa.tenant_id', $tenantId)->when($accessibleBranchIds !== null, fn ($q) => $q->whereIn('oa.branch_id', $accessibleBranchIds))->selectRaw("oa.id, 'variant' as level, p.id as product_id, p.name as product_name, oa.product_variant_id, v.name as variant_name, oa.branch_id, b.name as branch_name, b.timezone as branch_timezone, oa.channel, oa.status, oa.remaining_quantity, oa.unavailable_until, oa.reason, oa.created_at, oa.updated_at")
            ->when(! $archived, fn ($q) => $q->whereNull('v.deleted_at')->where('v.is_active', true)->whereNull('p.deleted_at')->where('p.is_active', true)->whereNull('b.deleted_at')->where('b.is_active', true));
        $query = DB::query()->fromSub($products->unionAll($variants), 'operational_availabilities');
        foreach (['branchId' => 'branch_id', 'channel' => 'channel', 'status' => 'status'] as $input => $column) {
            if (isset($filters[$input])) {
                $query->where($column, $filters[$input]);
            }
        }
        if (($filters['level'] ?? 'all') !== 'all') {
            $query->where('level', $filters['level']);
        }
        if (! empty($filters['search'])) {
            $search = '%'.$filters['search'].'%';
            $query->where(fn ($q) => $q->where('product_name', 'like', $search)->orWhere('variant_name', 'like', $search));
        }

        return $query->orderByDesc('updated_at')->orderBy('level')->orderBy('id')->paginate($filters['perPage'] ?? 20)->withQueryString();
    }

    private function upsert(string $class, int $tenantId, string $subjectColumn, int $subjectId, array $data, Branch $branch): Model
    {
        return DB::transaction(function () use ($class, $tenantId, $subjectColumn, $subjectId, $data, $branch): Model {
            $record = $class::query()->where('tenant_id', $tenantId)->where($subjectColumn, $subjectId)->where('branch_id', $data['branchId'])->where('channel', $data['channel'])->lockForUpdate()->first();
            $payload = $this->payload($data, $branch);
            $before = $record ? $this->snapshot($record) : null;
            if ($record) {
                $record->update($payload);
                $this->audit->log($tenantId, $record, MenuAuditAction::AvailabilityChanged, $before, $this->snapshot($record));
            } else {
                $record = $class::query()->create(['tenant_id' => $tenantId, $subjectColumn => $subjectId] + $payload);
                $this->audit->log($tenantId, $record, MenuAuditAction::Created, null, $this->snapshot($record));
            }

            return $record->fresh();
        });
    }

    private function clear(string $class, int $tenantId, string $subjectColumn, int $subjectId, array $data): bool
    {
        return DB::transaction(function () use ($class, $tenantId, $subjectColumn, $subjectId, $data): bool {
            $record = $class::query()->where('tenant_id', $tenantId)->where($subjectColumn, $subjectId)->where('branch_id', $data['branchId'])->where('channel', $data['channel'])->lockForUpdate()->first();
            if (! $record) {
                return false;
            }
            $before = $this->snapshot($record);
            $record->delete();
            $this->audit->log($tenantId, $record, MenuAuditAction::AvailabilityChanged, $before, null);

            return true;
        });
    }

    private function payload(array $data, Branch $branch): array
    {
        $available = $data['status'] === OperationalAvailabilityStatus::Available->value;

        $actor = request()->attributes->get('auth_user');

        return ['branch_id' => $data['branchId'], 'channel' => $data['channel'], 'status' => $data['status'], 'remaining_quantity' => $data['remainingQuantity'] ?? null, 'updated_by' => $actor ? (int) $actor->id : null,
            'unavailable_until' => $available || empty($data['unavailableUntil']) ? null : CarbonImmutable::createFromFormat('Y-m-d\\TH:i:s', $data['unavailableUntil'], $branch->timezone ?: config('app.timezone'))->utc(), 'reason' => $available ? null : ($data['reason'] ?? null)];
    }

    private function validateTemporaryExpiration(array $data, Branch $branch): void
    {
        if (($data['status'] ?? null) !== OperationalAvailabilityStatus::TemporarilyUnavailable->value) {
            return;
        }
        $timezone = $branch->timezone ?: config('app.timezone');
        if (CarbonImmutable::createFromFormat('Y-m-d\\TH:i:s', $data['unavailableUntil'], $timezone)->lessThanOrEqualTo(now($timezone))) {
            throw ValidationException::withMessages(['unavailableUntil' => 'A future unavailable-until time is required for temporarily unavailable status.']);
        }
    }

    private function snapshot(Model $record): array
    {
        return ['level' => $record instanceof ProductVariantOperationalAvailability ? 'variant' : 'product', 'productId' => $record instanceof ProductOperationalAvailability ? $record->product_id : null,
            'productVariantId' => $record instanceof ProductVariantOperationalAvailability ? $record->product_variant_id : null, 'branchId' => $record->branch_id,
            'channel' => $record->channel, 'status' => $record->status instanceof \BackedEnum ? $record->status->value : $record->status,
            'remainingQuantity' => $record->remaining_quantity === null ? null : (float) $record->remaining_quantity,
            'unavailableUntil' => $record->unavailable_until?->toIso8601String(), 'reason' => $record->reason];
    }
}
