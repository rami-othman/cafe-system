<?php

namespace App\Services\Menu;

use App\Models\PublishedMenuVersion;

class PublishedMenuVersionComparisonService
{
    public function compare(PublishedMenuVersion $from, PublishedMenuVersion $to): array
    {
        $a = $this->index($from->payload_json);
        $b = $this->index($to->payload_json);
        $limit = 100;
        $diff = fn ($key) => ['added' => array_values(array_diff(array_keys($b[$key]), array_keys($a[$key]))), 'removed' => array_values(array_diff(array_keys($a[$key]), array_keys($b[$key]))), 'changed' => array_values(array_filter(array_intersect(array_keys($a[$key]), array_keys($b[$key])), fn ($id) => $a[$key][$id] !== $b[$key][$id]))];
        $m = $diff('menus');
        $s = $diff('sections');
        $p = $diff('products');
        $v = $diff('variants');
        $g = $diff('groups');
        $r = $diff('rules');
        $prices = array_values(array_filter(array_intersect(array_keys($a['variants']), array_keys($b['variants'])), fn ($id) => ($a['variants'][$id]['effectivePrice'] ?? null) !== ($b['variants'][$id]['effectivePrice'] ?? null)));
        $recipes = $this->recipeChanges($a['variants'], $b['variants']);
        $entries = ['menusAdded' => $m['added'], 'menusRemoved' => $m['removed'], 'menusChanged' => $m['changed'], 'sectionsAdded' => $s['added'], 'sectionsRemoved' => $s['removed'], 'productsAdded' => $p['added'], 'productsRemoved' => $p['removed'], 'productsChanged' => $p['changed'], 'priceChanges' => $prices, 'modifierChanges' => $g['changed'], 'recipeChanges' => $recipes, 'scheduleChanges' => $r['changed']];
        // Each response category is independently bounded.  `truncated` must
        // describe an actual omitted row, not merely a large aggregate diff.
        $truncated = collect($entries)->contains(fn (array $entry) => count($entry) > $limit);
        foreach ($entries as &$entry) {
            $entry = array_slice($entry, 0, $limit);
        } unset($entry);

        return ['fromVersion' => ['id' => $from->id, 'versionNumber' => $from->version_number], 'toVersion' => ['id' => $to->id, 'versionNumber' => $to->version_number], 'sameChecksum' => hash_equals($from->checksum, $to->checksum), 'truncated' => $truncated, 'changes' => $entries];
    }

    /**
     * Schema-v1 payloads simply produce no recipe rows. Schema-v2 rows are
     * compared structurally, never by recursively diffing arbitrary JSON.
     */
    private function recipeChanges(array $from, array $to): array
    {
        $changes = [];
        foreach (array_intersect(array_keys($from), array_keys($to)) as $variantId) {
            $a = $this->recipeIndex($from[$variantId]);
            $b = $this->recipeIndex($to[$variantId]);
            foreach (['base' => 'base_component', 'adjustments' => 'modifier_adjustment'] as $bucket => $prefix) {
                foreach (array_diff(array_keys($b[$bucket]), array_keys($a[$bucket])) as $key) {
                    $changes[] = ['variantId' => (int) $variantId, 'type' => $prefix.'_added', 'key' => $key];
                }
                foreach (array_diff(array_keys($a[$bucket]), array_keys($b[$bucket])) as $key) {
                    $changes[] = ['variantId' => (int) $variantId, 'type' => $prefix.'_removed', 'key' => $key];
                }
                foreach (array_intersect(array_keys($a[$bucket]), array_keys($b[$bucket])) as $key) {
                    if ($a[$bucket][$key] !== $b[$bucket][$key]) {
                        $changes[] = ['variantId' => (int) $variantId, 'type' => $prefix.'_changed', 'key' => $key];
                    }
                }
            }
        }

        usort($changes, fn (array $left, array $right) => [$left['variantId'], $left['type'], $left['key']] <=> [$right['variantId'], $right['type'], $right['key']]);

        return $changes;
    }

    private function recipeIndex(array $variant): array
    {
        $base = [];
        foreach ($variant['baseRecipe'] ?? [] as $component) {
            $base[(string) ($component['materialId'] ?? '')] = $component;
        }
        $adjustments = [];
        foreach ($variant['modifierRecipeAdjustments'] ?? [] as $adjustment) {
            foreach ($adjustment['components'] ?? [] as $component) {
                $key = ($adjustment['optionId'] ?? '').':'.($component['operation'] ?? '').':'.($component['materialId'] ?? '');
                $adjustments[$key] = $component;
            }
        }

        return ['base' => $base, 'adjustments' => $adjustments];
    }

    private function index(array $payload): array
    {
        $out = ['menus' => [], 'sections' => [], 'products' => [], 'variants' => [], 'groups' => [], 'rules' => []];
        foreach ($payload['menus'] ?? [] as $m) {
            $out['menus'][$m['id']] = $m;
            foreach ($m['availabilityRules'] ?? [] as $r) {
                $out['rules']['menu:'.$r['id']] = $r;
            }foreach ($m['sections'] ?? [] as $s) {
                $out['sections'][$s['id']] = $s;
                foreach ($s['products'] ?? [] as $p) {
                    $out['products'][$p['placementId']] = $p;
                    foreach ($p['productAvailabilityRules'] ?? [] as $r) {
                        $out['rules']['product:'.$r['id']] = $r;
                    }foreach ($p['variants'] ?? [] as $v) {
                        $out['variants'][$v['id']] = $v;
                    }foreach ($p['modifierGroups'] ?? [] as $g) {
                        $out['groups'][$p['productId'].':'.$g['id']] = $g;
                    }
                }
            }
        }

        return $out;
    }
}
