<?php

namespace App\Http\Controllers\Api\Admin\Menu;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\Menu\ComparePublishedMenuVersionsRequest;
use App\Http\Requests\Admin\Menu\ListPublishedMenuVersionsRequest;
use App\Http\Requests\Admin\Menu\RollbackPublishedMenuVersionRequest;
use App\Http\Requests\Admin\Menu\ShowPublishedMenuVersionRequest;
use App\Services\Menu\PublishedMenuVersionService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;

class PublishedMenuVersionController extends Controller
{
    public function __construct(private readonly PublishedMenuVersionService $versions) {}

    public function index(ListPublishedMenuVersionsRequest $r): JsonResponse
    {
        $p = $this->versions->history(TenantContext::id($r), $r->validated());

        return response()->json(['data' => collect($p->items())->map(fn ($v) => $this->meta($v))->all(), 'meta' => ['currentPage' => $p->currentPage(), 'perPage' => $p->perPage(), 'total' => $p->total()]]);
    }

    public function show(ShowPublishedMenuVersionRequest $r, int $version): JsonResponse
    {
        $v = $this->versions->version(TenantContext::id($r), $version);
        $d = $this->meta($v) + ['branchId' => $v->branch_id, 'channel' => $this->value($v->channel), 'publication' => ['id' => $v->menu_publication_id, 'status' => $this->value($v->menuPublication?->status)], 'snapshotSummary' => $this->summary($v->payload_json)];
        if ($r->validated('includePayload')) {
            $d['payload'] = $v->payload_json;
        }

return response()->json(['data' => $d]);
    }

    public function compare(ComparePublishedMenuVersionsRequest $r, int $version): JsonResponse
    {
        return response()->json(['data' => $this->versions->compare(TenantContext::id($r), $version, $r->validated('againstVersionId'))]);
    }

    public function rollback(RollbackPublishedMenuVersionRequest $r, int $version): JsonResponse
    {
        return response()->json(['data' => $this->versions->rollback(TenantContext::id($r), $version, $r->validated())]);
    }

    private function meta($v): array
    {
        return ['id' => $v->id, 'versionNumber' => $v->version_number, 'checksum' => $v->checksum, 'status' => $this->value($v->status), 'publishedAt' => $v->published_at?->toIso8601String(), 'publicationId' => $v->menu_publication_id, 'publicationStatus' => $this->value($v->menuPublication?->status), 'isCurrent' => $this->value($v->status) === 'current', 'changeSummary' => $v->menuPublication?->change_summary, 'sourcePublicationId' => $v->menuPublication?->source_publication_id];
    }

    private function summary(array $p): array
    {
        $m = $s = $x = $v = $g = 0;
        foreach ($p['menus'] ?? [] as $a) {
            $m++;
            foreach ($a['sections'] ?? [] as $b) {
                $s++;
                foreach ($b['products'] ?? [] as $c) {
                    $x++;
                    $v += count($c['variants'] ?? []);
                    $g += count($c['modifierGroups'] ?? []);
                }
            }
        }

return ['menuCount' => $m, 'sectionCount' => $s, 'productCount' => $x, 'variantCount' => $v, 'modifierGroupCount' => $g];
    }

    private function value(mixed $v): mixed
    {
        return $v instanceof \BackedEnum ? $v->value : $v;
    }
}
