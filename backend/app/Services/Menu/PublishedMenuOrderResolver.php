<?php

namespace App\Services\Menu;

use App\Domain\Menu\Enums\PublishedMenuVersionStatus;
use App\Models\Branch;
use App\Models\PublishedMenuVersion;
use Illuminate\Validation\ValidationException;

/**
 * Resolves POS order lines exclusively from one immutable published snapshot.
 *
 * This deliberately owns no live Catalog pricing or membership lookups. The
 * runtime overlay is the sole live input and is limited to operational state.
 */
class PublishedMenuOrderResolver
{
    public function __construct(
        private readonly PublishedMenuPosMapper $mapper,
        private readonly PosMenuRuntimeService $runtime,
    ) {}

    /** Bind a newly-created order only to the authoritative current POS version. */
    public function bindNewOrder(int $tenantId, int $branchId, int $requestedVersionId): array
    {
        $version = $this->version($tenantId, $branchId, $requestedVersionId);
        $current = PublishedMenuVersion::query()
            ->where('tenant_id', $tenantId)
            ->where('branch_id', $branchId)
            ->where('channel', 'pos')
            ->where('status', PublishedMenuVersionStatus::Current->value)
            ->first();

        if ($current === null || $current->id !== $version->id) {
            $this->fail('publishedMenuVersionId', 'MENU_VERSION_STALE: refresh the POS menu and retry.');
        }

        return $this->context($tenantId, $version);
    }

    /** Re-open a previously pinned draft/held order without migrating its version. */
    public function bindPinnedOrder(int $tenantId, int $branchId, int $versionId): array
    {
        return $this->context($tenantId, $this->version($tenantId, $branchId, $versionId));
    }

    /**
     * Validates a snapshot line and returns the immutable values to persist.
     * `$context` is intentionally reused by every item in a request so the
     * payload is parsed and its runtime overlay is loaded once per operation.
     */
    public function priceItem(array $context, array $item): array
    {
        foreach (['productId', 'placementId', 'variantId'] as $field) {
            if (! array_key_exists($field, $item) || $item[$field] === null) {
                $this->fail($field, "{$field} is required for a snapshot-aware order.");
            }
        }

        $productId = (int) $item['productId'];
        $placementId = (int) $item['placementId'];
        $variantId = (int) $item['variantId'];
        $placements = $this->placementsForProduct($context['payload'], $productId);
        if ($placements === []) {
            $this->fail('productId', 'PRODUCT_NOT_IN_MENU_VERSION: the product is not published in this version.');
        }
        $placement = collect($placements)->first(fn (array $candidate) => (int) ($candidate['placementId'] ?? 0) === $placementId);
        if ($placement === null) {
            $this->fail('placementId', 'INVALID_PLACEMENT: the placement is not published for this product.');
        }

        $variant = collect($placement['variants'] ?? [])->first(fn (array $candidate) => (int) ($candidate['id'] ?? 0) === $variantId);
        if ($variant === null) {
            $this->fail('variantId', 'INVALID_VARIANT: the variant is not published for this product.');
        }
        if (! is_numeric($variant['effectivePrice'] ?? null) || (float) $variant['effectivePrice'] < 0) {
            $this->fail('variantId', 'INVALID_PUBLISHED_PRICE: the published variant cannot be sold.');
        }

        $state = $context['runtimeByIdentity'][$this->identity($placementId, $productId, $variantId)] ?? null;
        if ($state === null || ! ($state['isSellable'] ?? false)) {
            $reason = $state['reason'] ?? 'not_sellable';
            $code = match ($reason) {
                'outside_menu_schedule', 'outside_product_schedule' => 'OUTSIDE_PUBLISHED_SCHEDULE',
                'sold_out' => 'SOLD_OUT',
                'temporarily_unavailable' => 'TEMPORARILY_UNAVAILABLE',
                default => 'PRODUCT_NOT_SELLABLE',
            };
            $this->fail('items', "{$code}: the published item is not sellable.");
        }

        $selectedIds = array_map('intval', $item['modifierOptionIds'] ?? []);
        if (count($selectedIds) !== count(array_unique($selectedIds))) {
            $this->fail('modifierOptionIds', 'DUPLICATE_MODIFIER_OPTION: each modifier option may be selected once.');
        }

        $options = [];
        $groups = $placement['modifierGroups'] ?? [];
        foreach ($groups as $group) {
            foreach ($group['options'] ?? [] as $option) {
                $options[(int) ($option['id'] ?? 0)] = ['group' => $group, 'option' => $option];
            }
        }
        $selected = [];
        foreach ($selectedIds as $id) {
            $entry = $options[$id] ?? null;
            if ($entry === null || ! ($entry['option']['isAvailable'] ?? true)) {
                $this->fail('modifierOptionIds', 'INVALID_MODIFIER_OPTION: the option is not published for this product.');
            }
            if (! is_numeric($entry['option']['priceDelta'] ?? null)) {
                $this->fail('modifierOptionIds', 'INVALID_PUBLISHED_MODIFIER_PRICE: the option cannot be sold.');
            }
            $selected[] = $entry;
        }

        $byGroup = collect($selected)->groupBy(fn (array $entry) => (int) $entry['group']['id']);
        foreach ($groups as $group) {
            $count = $byGroup->get((int) $group['id'], collect())->count();
            $minimum = max((bool) ($group['isRequired'] ?? false) ? 1 : 0, (int) ($group['minSelections'] ?? 0));
            $maximum = (int) ($group['maxSelections'] ?? 1);
            $name = $this->name($group['name'] ?? null);
            if ($count < $minimum) {
                $this->fail('modifierOptionIds', "MODIFIER_MIN_SELECTIONS: {$name} requires at least {$minimum} selection(s).");
            }
            if ($count > $maximum || (($group['selectionType'] ?? null) === 'single' && $count > 1)) {
                $this->fail('modifierOptionIds', "MODIFIER_MAX_SELECTIONS: {$name} has too many selections.");
            }
        }

        $unitCents = $this->minorUnits((string) $variant['effectivePrice']);
        $selectedOptions = [];
        foreach ($selected as $entry) {
            $option = $entry['option'];
            $group = $entry['group'];
            $unitCents += $this->minorUnits((string) $option['priceDelta']);
            $selectedOptions[] = [
                'id' => (int) $option['id'],
                'modifierGroupId' => (int) $group['id'],
                'groupName' => $this->name($group['name'] ?? null),
                'optionName' => $this->name($option['name'] ?? null),
                'priceDelta' => round($this->minorUnits((string) $option['priceDelta']) / 100, 2),
            ];
        }
        if ($unitCents < 0) {
            $this->fail('modifierOptionIds', 'INVALID_UNIT_PRICE: selected modifiers result in a negative price.');
        }

        $quantity = (float) $item['quantity'];
        $unitPrice = round($unitCents / 100, 2);

        return [
            'productId' => $productId,
            'categoryId' => isset($placement['categoryId']) ? (int) $placement['categoryId'] : null,
            'productName' => $this->name($placement['name'] ?? null),
            'placementId' => $placementId,
            'variantId' => $variantId,
            'variantName' => $this->name($variant['name'] ?? null),
            'quantity' => $quantity,
            'unitPrice' => $unitPrice,
            'lineTotal' => round($unitPrice * $quantity, 2),
            'selectedOptions' => $selectedOptions,
        ];
    }

    private function context(int $tenantId, PublishedMenuVersion $version): array
    {
        // This is also the v2/v3 compatibility and unknown-schema guard.
        $this->mapper->sourceSchemaVersion($version->payload_json);
        $branch = Branch::query()->where('tenant_id', $tenantId)->whereKey($version->branch_id)->firstOrFail();
        $runtime = $this->runtime->resolve($tenantId, $branch, $version->payload_json);
        $runtimeByIdentity = [];
        foreach ($runtime['variants'] as $state) {
            $runtimeByIdentity[$this->identity((int) $state['placementId'], (int) $state['productId'], (int) $state['variantId'])] = $state;
        }

        return ['version' => $version, 'payload' => $version->payload_json, 'runtimeByIdentity' => $runtimeByIdentity];
    }

    private function version(int $tenantId, int $branchId, int $versionId): PublishedMenuVersion
    {
        $version = PublishedMenuVersion::query()
            ->where('tenant_id', $tenantId)
            ->where('branch_id', $branchId)
            ->where('channel', 'pos')
            ->whereKey($versionId)
            ->first();
        if ($version === null) {
            $this->fail('publishedMenuVersionId', 'INVALID_MENU_VERSION: the version is unavailable for this Branch POS channel.');
        }

        return $version;
    }

    private function placementsForProduct(array $payload, int $productId): array
    {
        $placements = [];
        foreach ($payload['menus'] ?? [] as $menu) {
            foreach ($menu['sections'] ?? [] as $section) {
                foreach ($section['products'] ?? [] as $product) {
                    if ((int) ($product['productId'] ?? 0) === $productId) {
                        $placements[] = $product;
                    }
                }
            }
        }

        return $placements;
    }

    private function identity(int $placementId, int $productId, int $variantId): string
    {
        return "{$placementId}:{$productId}:{$variantId}";
    }

    private function name(mixed $value): string
    {
        return is_array($value) ? (string) ($value['default'] ?? $value['en'] ?? $value['ar'] ?? 'Modifier') : (string) ($value ?? 'Modifier');
    }

    private function minorUnits(string $value): int
    {
        $negative = str_starts_with($value, '-');
        $value = ltrim($value, '+-');
        [$whole, $fraction] = array_pad(explode('.', $value, 2), 2, '');
        $cents = ((int) $whole * 100) + (int) str_pad(substr($fraction, 0, 2), 2, '0');

        return $negative ? -$cents : $cents;
    }

    private function fail(string $field, string $message): never
    {
        throw ValidationException::withMessages([$field => $message]);
    }
}
