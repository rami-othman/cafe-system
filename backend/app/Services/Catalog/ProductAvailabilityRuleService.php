<?php

namespace App\Services\Catalog;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Models\Branch;
use App\Models\Product;
use App\Models\ProductAvailabilityRule;
use App\Models\ProductVariant;
use DateTimeInterface;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ProductAvailabilityRuleService
{
    public function __construct(private readonly CatalogAuditService $audit) {}

    public function product(int $tenantId, int $productId): Product
    {
        return Product::query()->where('tenant_id', $tenantId)->findOrFail($productId);
    }

    public function rules(Product $product): array
    {
        return ProductAvailabilityRule::query()
            ->where('tenant_id', $product->tenant_id)
            ->where('product_id', $product->id)
            ->orderByRaw('product_variant_id NULLS FIRST')
            ->orderBy('priority')
            ->orderBy('id')
            ->get()
            ->all();
    }

    public function sync(int $tenantId, int $productId, array $items): array
    {
        $product = $this->product($tenantId, $productId);
        $this->validateReferences($product, $items);

        return DB::transaction(function () use ($product, $items): array {
            $lockedProduct = Product::query()->whereKey($product->id)->lockForUpdate()->firstOrFail();
            $existing = ProductAvailabilityRule::withTrashed()
                ->where('tenant_id', $lockedProduct->tenant_id)
                ->where('product_id', $lockedProduct->id)
                ->lockForUpdate()
                ->get()
                ->keyBy(fn (ProductAvailabilityRule $rule) => $this->canonicalKey($this->attributes($rule)));
            $submitted = [];
            $changes = ['created' => 0, 'updated' => 0, 'restored' => 0, 'archived' => 0];

            foreach ($items as $item) {
                $key = $this->canonicalKey($item);
                $submitted[] = $key;
                $payload = $this->payload($item);
                $rule = $existing->get($key);
                if (! $rule) {
                    $rule = ProductAvailabilityRule::query()->create([
                        'tenant_id' => $lockedProduct->tenant_id,
                        'product_id' => $lockedProduct->id,
                    ] + $payload);
                    $changes['created']++;
                    $this->audit->log($lockedProduct->tenant_id, $rule, MenuAuditAction::Created, null, $this->auditData($rule));

                    continue;
                }

                $before = $this->auditData($rule);
                if ($rule->trashed()) {
                    $rule->restore();
                    $rule->update($payload);
                    $changes['restored']++;
                    $this->audit->log($lockedProduct->tenant_id, $rule, MenuAuditAction::Restored, $before, $this->auditData($rule));
                } else {
                    $rule->update($payload);
                    $changes['updated']++;
                    $this->audit->log($lockedProduct->tenant_id, $rule, MenuAuditAction::Updated, $before, $this->auditData($rule));
                }
            }

            $existing->filter(fn (ProductAvailabilityRule $rule) => ! $rule->trashed() && ! in_array($this->canonicalKey($this->attributes($rule)), $submitted, true))
                ->each(function (ProductAvailabilityRule $rule) use ($lockedProduct, &$changes): void {
                    $before = $this->auditData($rule);
                    $rule->delete();
                    $changes['archived']++;
                    $this->audit->log($lockedProduct->tenant_id, $rule, MenuAuditAction::Archived, $before, null);
                });

            $this->audit->log($lockedProduct->tenant_id, $lockedProduct, MenuAuditAction::Synchronized, null, [
                'productId' => $lockedProduct->id,
                'created' => $changes['created'],
                'updated' => $changes['updated'],
                'restored' => $changes['restored'],
                'archived' => $changes['archived'],
            ]);

            return $this->rules($lockedProduct);
        });
    }

    public function branch(int $tenantId, ?int $branchId): ?Branch
    {
        if ($branchId === null) {
            return null;
        }
        $branch = Branch::query()->where('tenant_id', $tenantId)->where('is_active', true)->find($branchId);
        if (! $branch) {
            throw ValidationException::withMessages(['branchId' => 'The selected branch is invalid or archived.']);
        }

        return $branch;
    }

    private function validateReferences(Product $product, array $items): void
    {
        foreach ($items as $index => $item) {
            if (isset($item['productVariantId'])) {
                $variant = ProductVariant::query()
                    ->where('tenant_id', $product->tenant_id)
                    ->where('product_id', $product->id)
                    ->find($item['productVariantId']);
                if (! $variant) {
                    throw ValidationException::withMessages(["rules.$index.productVariantId" => 'The selected variant is invalid.']);
                }
            }
            if (isset($item['branchId'])) {
                $branch = Branch::query()->where('tenant_id', $product->tenant_id)->where('is_active', true)->find($item['branchId']);
                if (! $branch) {
                    throw ValidationException::withMessages(["rules.$index.branchId" => 'The selected branch is invalid or archived.']);
                }
            }
        }
    }

    private function payload(array $item): array
    {
        return [
            'product_variant_id' => $item['productVariantId'] ?? null,
            'branch_id' => $item['branchId'] ?? null,
            'channel' => $item['channel'] ?? null,
            'day_of_week' => $item['dayOfWeek'] ?? null,
            'start_time' => $item['startTime'] ?? null,
            'end_time' => $item['endTime'] ?? null,
            'start_date' => $item['startDate'] ?? null,
            'end_date' => $item['endDate'] ?? null,
            'priority' => $item['priority'] ?? 0,
            'is_active' => $item['isActive'] ?? true,
        ];
    }

    private function attributes(ProductAvailabilityRule $rule): array
    {
        return [
            'productVariantId' => $rule->product_variant_id,
            'branchId' => $rule->branch_id,
            'channel' => $rule->channel instanceof \BackedEnum ? $rule->channel->value : $rule->channel,
            'dayOfWeek' => $rule->day_of_week,
            'startTime' => $this->time($rule->start_time),
            'endTime' => $this->time($rule->end_time),
            'startDate' => $rule->start_date?->toDateString(),
            'endDate' => $rule->end_date?->toDateString(),
        ];
    }

    private function canonicalKey(array $rule): string
    {
        return implode('|', [
            $rule['productVariantId'] ?? '*', $rule['branchId'] ?? '*', $rule['channel'] ?? '*',
            $rule['dayOfWeek'] ?? '*', $rule['startTime'] ?? '*', $rule['endTime'] ?? '*',
            $rule['startDate'] ?? '*', $rule['endDate'] ?? '*',
        ]);
    }

    private function auditData(ProductAvailabilityRule $rule): array
    {
        return ['productId' => $rule->product_id] + $this->attributes($rule) + ['priority' => $rule->priority, 'isActive' => (bool) $rule->is_active];
    }

    private function time(mixed $value): ?string
    {
        if ($value instanceof DateTimeInterface) {
            return $value->format('H:i');
        }

        return $value === null ? null : substr((string) $value, 0, 5);
    }
}
