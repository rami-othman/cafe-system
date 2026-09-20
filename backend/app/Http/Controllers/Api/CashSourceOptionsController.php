<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\CashSourceResolver;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class CashSourceOptionsController extends Controller
{
    public function __invoke(Request $request, CashSourceResolver $sources): JsonResponse
    {
        $data = $request->validate(['branchId' => ['required', 'integer']]);
        $tenant = TenantContext::id($request);
        $actor = FinancialActor::id($request, $tenant);
        $branch = (int) $data['branchId'];
        $mode = $sources->mode($tenant, $actor);
        $resolved = $mode === 'shift' ? $sources->resolve($tenant, $actor, $branch) : null;
        return response()->json(['data' => [
            'cashSourceMode' => $mode,
            'resolvedCashLocation' => $resolved ? [
                'id' => (int) $resolved->location->id,
                'name' => $resolved->location->name,
                'shiftId' => (int) $resolved->shift->id,
            ] : null,
            'allowedCashLocations' => $mode === 'selectable' ? $sources->allowedLocations($tenant, $actor, $branch) : [],
        ]]);
    }
}
