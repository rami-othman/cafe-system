<?php

namespace App\Http\Controllers\Api\Manufacturing;

use App\Domain\Manufacturing\ManufacturingReportService;
use App\Http\Controllers\Controller;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ManufacturingReportController extends Controller
{
    public function __construct(private readonly ManufacturingReportService $reports) {}

    public function overview(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $warehouseId = $request->filled('warehouseId') ? (int) $request->query('warehouseId') : null;

        return response()->json(['data' => $this->reports->overview($tenantId, $warehouseId)]);
    }

    public function reports(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $warehouseId = $request->filled('warehouseId') ? (int) $request->query('warehouseId') : null;

        return response()->json(['data' => $this->reports->reports($tenantId, $warehouseId, $request->query('type'), $request->query('dateFrom'), $request->query('dateTo'))]);
    }
}
