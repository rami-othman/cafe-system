<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\FinancialActor;
use App\Services\TrashRegistry;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** The single trash for every entity. Owner only. */
final class TrashController extends Controller
{
    public function __construct(private readonly TrashRegistry $trash) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $this->assertOwner($request, $tenantId);
        $perPage = min(max((int) $request->query('perPage', 50), 1), 200);
        $result = $this->trash->list($tenantId, $request->query('type'), $request->query('search'), max(1, (int) $request->query('page', 1)), $perPage);

        return response()->json([
            'data' => $result['data'],
            'types' => $this->trash->types($tenantId),
            'meta' => ['total' => $result['total'], 'page' => $result['page'], 'perPage' => $result['perPage'], 'lastPage' => max(1, (int) ceil($result['total'] / $perPage))],
        ]);
    }

    public function restore(Request $request, string $type, int $id): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $actorId = $this->assertOwner($request, $tenantId);
        $this->trash->restore($request, $tenantId, $type, $id, $actorId);

        return response()->json(['restored' => true]);
    }

    private function assertOwner(Request $request, int $tenantId): int
    {
        $actorId = FinancialActor::id($request, $tenantId);
        abort_unless(DB::table('users')->where('tenant_id', $tenantId)->where('id', $actorId)
            ->where('role', 'owner')->whereNull('deleted_at')->exists(), 403, 'Owner access required.');

        return $actorId;
    }
}
