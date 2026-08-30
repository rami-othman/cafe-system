<?php

namespace App\Services\Menu;

use App\Exceptions\UnsupportedMenuSnapshotSchemaException;

/** Maps a v2/v3 immutable source snapshot to POS runtime contract v1. */
class PublishedMenuPosMapper
{
    public const RUNTIME_CONTRACT_VERSION = 1;

    public function sourceSchemaVersion(array $payload): int
    {
        $schema = $payload['context']['schemaVersion'] ?? 2;
        if (! in_array($schema, [2, 3], true)) {
            throw new UnsupportedMenuSnapshotSchemaException($schema);
        }

        return $schema;
    }

    public function menu(array $payload): array
    {
        $this->sourceSchemaVersion($payload);

        return ['menus' => array_values(array_map(fn (array $menu, int $scopeOrder) => $this->menuEntry($menu, $scopeOrder), $payload['menus'] ?? [], array_keys($payload['menus'] ?? [])))];
    }

    private function menuEntry(array $menu, int $scopeOrder): array
    {
        return [
            'id' => $menu['id'], 'scopeOrder' => $menu['scopeOrder'] ?? $scopeOrder,
            'name' => $this->localized($menu['name'] ?? null), 'description' => $this->localized($menu['description'] ?? null),
            'coverImageUrl' => $menu['coverImageUrl'] ?? null,
            'sections' => array_values(array_map(fn (array $section) => $this->section($section), $menu['sections'] ?? [])),
        ];
    }

    private function section(array $section): array
    {
        return [
            'id' => $section['id'], 'name' => $this->localized($section['name'] ?? null), 'description' => $this->localized($section['description'] ?? null),
            'imageUrl' => $section['imageUrl'] ?? null, 'sortOrder' => $section['sortOrder'] ?? 0,
            'products' => array_values(array_map(fn (array $product) => $this->product($product), $section['products'] ?? [])),
        ];
    }

    private function product(array $product): array
    {
        return [
            'placementId' => $product['placementId'], 'productId' => $product['productId'],
            'name' => $this->localized($product['name'] ?? null), 'description' => $this->localized($product['description'] ?? null),
            'imageUrl' => $product['imageUrl'] ?? null, 'sortOrder' => $product['sortOrder'] ?? 0,
            'isFeatured' => (bool) ($product['isFeatured'] ?? false), 'isVisible' => (bool) ($product['isVisible'] ?? true),
            'variants' => array_values(array_map(fn (array $variant) => $this->variant($variant), $product['variants'] ?? [])),
            'modifierGroups' => array_values(array_map(fn (array $group) => $this->modifierGroup($group), $product['modifierGroups'] ?? [])),
        ];
    }

    private function variant(array $variant): array
    {
        return ['id' => $variant['id'], 'name' => $this->localized($variant['name'] ?? null), 'sku' => $variant['sku'] ?? null,
            'barcode' => $variant['barcode'] ?? null, 'sortOrder' => $variant['sortOrder'] ?? 0, 'isDefault' => (bool) ($variant['isDefault'] ?? false),
            'basePrice' => $variant['basePrice'] ?? null, 'effectivePrice' => $variant['effectivePrice'] ?? null];
    }

    private function modifierGroup(array $group): array
    {
        return ['id' => $group['id'], 'name' => $this->localized($group['name'] ?? null), 'selectionType' => $group['selectionType'] ?? null,
            'isRequired' => (bool) ($group['isRequired'] ?? false), 'minSelections' => $group['minSelections'] ?? null, 'maxSelections' => $group['maxSelections'] ?? null,
            'allowQuantity' => (bool) ($group['allowQuantity'] ?? false), 'sortOrder' => $group['sortOrder'] ?? 0,
            'options' => array_values(array_map(fn (array $option) => ['id' => $option['id'], 'name' => $this->localized($option['name'] ?? null), 'priceDelta' => $option['priceDelta'] ?? null, 'isDefault' => (bool) ($option['isDefault'] ?? false), 'isAvailable' => (bool) ($option['isAvailable'] ?? true), 'sortOrder' => $option['sortOrder'] ?? 0], $group['options'] ?? []))];
    }

    private function localized(mixed $value): array
    {
        return is_array($value) ? ['default' => $value['default'] ?? null, 'ar' => $value['ar'] ?? null, 'en' => $value['en'] ?? null] : ['default' => $value, 'ar' => null, 'en' => null];
    }
}
