<?php

namespace App\Services\Menu;

use App\Domain\Menu\Enums\OperationalAvailabilityStatus;
use App\Models\Branch;
use App\Models\ProductOperationalAvailability;
use App\Models\ProductVariantOperationalAvailability;
use Carbon\CarbonImmutable;

/** Builds the dynamic, request-time overlay for one immutable published version. */
class PosMenuRuntimeService
{
    public function __construct(private readonly SnapshotScheduleResolver $schedules) {}

    public function resolve(int $tenantId, Branch $branch, array $payload): array
    {
        $timezone = $branch->timezone ?: config('app.timezone');
        $at = CarbonImmutable::now($timezone);
        $identities = $this->identities($payload);
        $availability = $this->operational($tenantId, $branch->id, $identities['productIds'], $identities['variantIds'], $at, $timezone);
        $menus = [];
        $placements = [];
        $variants = [];

        foreach ($payload['menus'] ?? [] as $menu) {
            $menuSchedule = $this->schedules->menu($menu['availabilityRules'] ?? [], $branch->id, 'pos', $at);
            $menus[] = ['menuId' => $menu['id'], ...$menuSchedule];
            foreach ($menu['sections'] ?? [] as $section) {
                foreach ($section['products'] ?? [] as $product) {
                    $variantStates = [];
                    foreach ($product['variants'] ?? [] as $variant) {
                        $scheduled = $this->schedules->product($product['productAvailabilityRules'] ?? [], $variant['id'], $branch->id, 'pos', $at);
                        $scheduledAvailable = $menuSchedule['isScheduledAvailable'] && $scheduled['isScheduledAvailable'];
                        $operational = $availability['variants'][$variant['id']] ?? $availability['products'][$product['productId']] ?? $this->available($product['productId'], $variant['id']);
                        $priceIsValid = is_numeric($variant['effectivePrice'] ?? null) && (float) $variant['effectivePrice'] >= 0;
                        $reason = ! $menuSchedule['isScheduledAvailable'] ? 'outside_menu_schedule' : (! $scheduled['isScheduledAvailable'] ? 'outside_product_schedule' : (! $operational['isOperationallyAvailable'] ? $operational['status'] : (! $priceIsValid ? 'invalid_price' : null)));
                        $state = ['placementId' => $product['placementId'], 'productId' => $product['productId'], 'variantId' => $variant['id'],
                            'isScheduledAvailable' => $scheduledAvailable, 'isOperationallyAvailable' => $operational['isOperationallyAvailable'],
                            'isSellable' => (bool) ($product['isVisible'] ?? true) && $scheduledAvailable && $operational['isOperationallyAvailable'] && $priceIsValid,
                            'reason' => $reason, 'operationalStatus' => $operational['status'], 'remainingQuantity' => $operational['remainingQuantity'], 'unavailableUntil' => $operational['unavailableUntil']];
                        $variants[] = $state;
                        $variantStates[] = $state;
                    }
                    $placements[] = ['placementId' => $product['placementId'], 'productId' => $product['productId'],
                        'isScheduledAvailable' => collect($variantStates)->contains('isScheduledAvailable', true),
                        'isOperationallyAvailable' => collect($variantStates)->contains('isOperationallyAvailable', true),
                        'isSellable' => collect($variantStates)->contains('isSellable', true),
                        'reason' => collect($variantStates)->firstWhere('isSellable', true)['reason'] ?? (collect($variantStates)->first()['reason'] ?? 'no_variant')];
                }
            }
        }

        return ['evaluatedAt' => $at->toIso8601String(), 'menus' => $menus, 'placements' => $placements, 'variants' => $variants];
    }

    private function identities(array $payload): array
    {
        $products = [];
        $variants = [];
        foreach ($payload['menus'] ?? [] as $menu) {
            foreach ($menu['sections'] ?? [] as $section) {
                foreach ($section['products'] ?? [] as $product) {
                    $products[] = $product['productId'];
                    foreach ($product['variants'] ?? [] as $variant) {
                        $variants[] = $variant['id'];
                    }
                }
            }
        }

        return ['productIds' => array_values(array_unique($products)), 'variantIds' => array_values(array_unique($variants))];
    }

    private function operational(int $tenantId, int $branchId, array $productIds, array $variantIds, CarbonImmutable $at, string $timezone): array
    {
        $products = ProductOperationalAvailability::query()->where('tenant_id', $tenantId)->where('branch_id', $branchId)->whereIn('channel', ['pos', 'all'])->when($productIds !== [], fn ($query) => $query->whereIn('product_id', $productIds), fn ($query) => $query->whereRaw('1 = 0'))->get();
        $variants = ProductVariantOperationalAvailability::query()->where('tenant_id', $tenantId)->where('branch_id', $branchId)->whereIn('channel', ['pos', 'all'])->when($variantIds !== [], fn ($query) => $query->whereIn('product_variant_id', $variantIds), fn ($query) => $query->whereRaw('1 = 0'))->get();

        return ['products' => $this->indexOperational($products, 'product_id', $at, $timezone), 'variants' => $this->indexOperational($variants, 'product_variant_id', $at, $timezone)];
    }

    private function indexOperational(iterable $records, string $subject, CarbonImmutable $at, string $timezone): array
    {
        $indexed = [];
        foreach ($records as $record) {
            if ($this->expired($record, $at)) {
                continue;
            }
            $id = $record->{$subject};
            if (! isset($indexed[$id]) || $record->channel === 'pos') {
                $status = $record->status instanceof \BackedEnum ? $record->status->value : $record->status;
                $indexed[$id] = ['isOperationallyAvailable' => $status === OperationalAvailabilityStatus::Available->value, 'status' => $status,
                    'remainingQuantity' => $record->remaining_quantity === null ? null : (float) $record->remaining_quantity,
                    'unavailableUntil' => $record->unavailable_until?->setTimezone($timezone)->toIso8601String(), 'reason' => $record->reason];
            }
        }

        return $indexed;
    }

    private function expired(object $record, CarbonImmutable $at): bool
    {
        $status = $record->status instanceof \BackedEnum ? $record->status->value : $record->status;

        return $status !== OperationalAvailabilityStatus::Available->value
            && $record->unavailable_until !== null
            && CarbonImmutable::instance($record->unavailable_until)->lessThanOrEqualTo($at);
    }

    private function available(int $productId, int $variantId): array
    {
        return ['productId' => $productId, 'variantId' => $variantId, 'isOperationallyAvailable' => true, 'status' => 'available', 'remainingQuantity' => null, 'unavailableUntil' => null, 'reason' => 'no_operational_override'];
    }
}
