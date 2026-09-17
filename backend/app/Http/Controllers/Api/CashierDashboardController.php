<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\BranchAccessService;
use App\Services\CashierDashboardService;
use App\Services\CashierInventoryQueryService;
use App\Support\CashierAccess;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * The Cashier's operational surface: one aggregate read for the dashboard and
 * one quantity-only stock list, so the client does not fan out across a dozen
 * unrelated endpoints to render a till screen.
 *
 * A supplied branchId is never trusted: it is authorized through
 * BranchAccessService before any scoping decision, and the services below
 * additionally constrain every query to the caller's own open shift and to
 * branches that service already allows.
 */
class CashierDashboardController extends Controller
{
    public function __construct(
        private readonly CashierDashboardService $dashboard,
        private readonly CashierInventoryQueryService $inventory,
        private readonly BranchAccessService $branches,
    ) {}

    public function show(Request $request): JsonResponse
    {
        $data = $request->validate(['branchId' => ['nullable', 'integer', 'min:1']]);
        $actor = CashierAccess::actor($request);
        $branchId = $this->authorizedBranchId($request, $data);

        return response()->json(['data' => $this->dashboard->build($request, $actor, $branchId)]);
    }

    public function inventory(Request $request): JsonResponse
    {
        $data = $request->validate([
            'branchId' => ['nullable', 'integer', 'min:1'],
            'search' => ['nullable', 'string', 'max:120'],
            'state' => ['nullable', 'in:normal,low,zero,negative'],
            'page' => ['nullable', 'integer', 'min:1'],
            'perPage' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);
        $actor = CashierAccess::actor($request);
        $branchId = $this->authorizedBranchId($request, $data);

        return response()->json(['data' => $this->inventory->list(
            $actor,
            $branchId,
            $data['search'] ?? null,
            $data['state'] ?? null,
            (int) ($data['page'] ?? 1),
            (int) ($data['perPage'] ?? 50),
        )]);
    }

    /** @param array<string, mixed> $data */
    private function authorizedBranchId(Request $request, array $data): ?int
    {
        if (! isset($data['branchId'])) {
            return null;
        }

        // Aborts 404 for a foreign-tenant branch and 403 for an unassigned one,
        // matching the rest of the operational API.
        return (int) $this->branches->authorizeRequestBranch($request, (int) $data['branchId'])->id;
    }
}
