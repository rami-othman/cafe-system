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
        $entries = ['menusAdded' => $m['added'], 'menusRemoved' => $m['removed'], 'menusChanged' => $m['changed'], 'sectionsAdded' => $s['added'], 'sectionsRemoved' => $s['removed'], 'productsAdded' => $p['added'], 'productsRemoved' => $p['removed'], 'productsChanged' => $p['changed'], 'priceChanges' => $prices, 'modifierChanges' => $g['changed'], 'scheduleChanges' => $r['changed']];
        $count = array_sum(array_map('count', $entries));
        foreach ($entries as &$entry) {
            $entry = array_slice($entry, 0, $limit);
        } unset($entry);

        return ['fromVersion' => ['id' => $from->id, 'versionNumber' => $from->version_number], 'toVersion' => ['id' => $to->id, 'versionNumber' => $to->version_number], 'sameChecksum' => hash_equals($from->checksum, $to->checksum), 'truncated' => $count > $limit, 'changes' => $entries];
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
