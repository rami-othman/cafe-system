<?php

namespace App\Services\Catalog;

use App\Domain\Menu\Enums\OperationalAvailabilityStatus;
use App\Models\ProductOperationalAvailability;
use App\Models\ProductVariantOperationalAvailability;
use Carbon\CarbonImmutable;
use DateTimeInterface;

class OperationalAvailabilityResolver
{
    public function resolve(int $tenantId, int $productId, ?int $variantId, int $branchId, string $channel, DateTimeInterface|string|null $at, string $timezone): array
    {
        $evaluatedAt = $at instanceof DateTimeInterface
            ? CarbonImmutable::instance($at)->setTimezone($timezone)
            : CarbonImmutable::parse($at ?? 'now', $timezone);
        $candidates = [];
        if ($variantId !== null) {
            $candidates[] = ['variant', 'exact_channel', ProductVariantOperationalAvailability::query()->where('tenant_id', $tenantId)->where('product_variant_id', $variantId)->where('branch_id', $branchId)->where('channel', $channel)->first()];
            $candidates[] = ['variant', 'all_channels', ProductVariantOperationalAvailability::query()->where('tenant_id', $tenantId)->where('product_variant_id', $variantId)->where('branch_id', $branchId)->where('channel', 'all')->first()];
        }
        $candidates[] = ['product', 'exact_channel', ProductOperationalAvailability::query()->where('tenant_id', $tenantId)->where('product_id', $productId)->where('branch_id', $branchId)->where('channel', $channel)->first()];
        $candidates[] = ['product', 'all_channels', ProductOperationalAvailability::query()->where('tenant_id', $tenantId)->where('product_id', $productId)->where('branch_id', $branchId)->where('channel', 'all')->first()];

        foreach ($candidates as [$level, $scope, $record]) {
            if ($record && ! $this->expired($record, $evaluatedAt)) {
                return $this->matched($record, $level, $scope, $productId, $variantId, $branchId, $channel, $timezone);
            }
        }

        return ['productId' => $productId, 'productVariantId' => $variantId, 'branchId' => $branchId, 'channel' => $channel,
            'isOperationallyAvailable' => true, 'status' => OperationalAvailabilityStatus::Available->value, 'matchedLevel' => null,
            'matchedScope' => null, 'matchedRecordId' => null, 'remainingQuantity' => null, 'unavailableUntil' => null, 'reason' => 'no_operational_override'];
    }

    private function expired(object $record, CarbonImmutable $at): bool
    {
        return $record->status !== OperationalAvailabilityStatus::Available
            && $record->unavailable_until !== null
            && CarbonImmutable::instance($record->unavailable_until)->lessThanOrEqualTo($at);
    }

    private function matched(object $record, string $level, string $scope, int $productId, ?int $variantId, int $branchId, string $channel, string $timezone): array
    {
        $until = $record->unavailable_until ? CarbonImmutable::instance($record->unavailable_until)->setTimezone($timezone)->toIso8601String() : null;
        $status = $record->status instanceof \BackedEnum ? $record->status->value : $record->status;

        return ['productId' => $productId, 'productVariantId' => $variantId, 'branchId' => $branchId, 'channel' => $channel,
            'isOperationallyAvailable' => $status === OperationalAvailabilityStatus::Available->value, 'status' => $status,
            'matchedLevel' => $level, 'matchedScope' => $scope, 'matchedRecordId' => $record->id,
            'remainingQuantity' => $record->remaining_quantity === null ? null : (float) $record->remaining_quantity,
            'unavailableUntil' => $until, 'reason' => $record->reason];
    }
}
