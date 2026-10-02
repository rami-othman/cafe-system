<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\OpeningInventoryService;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class OpeningInventoryController extends Controller
{
    public function __construct(private readonly OpeningInventoryService $openings) {}

    public function store(Request $request, int $period): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $actorId = FinancialActor::id($request, $tenantId);
        abort_unless(DB::table('users')->where('tenant_id', $tenantId)->where('id', $actorId)
            ->where('role', 'owner')->whereNull('deleted_at')->exists(), 403, 'Owner access required.');
        $data = $request->validate([
            'lines' => ['required', 'array', 'min:1', 'max:100'],
            'lines.*.warehouseId' => ['required', 'integer'],
            'lines.*.itemId' => ['required', 'integer'],
            'lines.*.quantity' => ['required', 'regex:/^\d+(\.\d{1,3})?$/'],
            'lines.*.unitCost' => ['required', 'regex:/^\d+(\.\d{1,4})?$/'],
            'lines.*.unit' => ['nullable', 'string', 'max:40'],
        ]);
        $result = $this->openings->create($request, $tenantId, $period, $data['lines'], $actorId);

        return response()->json(['data' => $result], 201);
    }
}
