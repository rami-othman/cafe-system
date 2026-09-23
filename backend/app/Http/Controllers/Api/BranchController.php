<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\BranchAccessService;
use App\Services\TenantTaxService;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class BranchController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        $taxRate = app(TenantTaxService::class)->rateFor($tenantId);
        $branches = DB::table('branches')
            ->where('tenant_id', $tenantId)
            ->whereIn('id', app(BranchAccessService::class)->accessibleBranchIds($request->attributes->get('auth_user')))
            ->whereNull('deleted_at')
            ->orderBy('id')
            ->get()
            ->map(fn ($branch) => [
                'id' => $branch->id,
                'name' => $branch->name,
                'currency' => $branch->currency,
                'timezone' => $branch->timezone,
                'isActive' => (bool) $branch->is_active,
                'taxRate' => $taxRate,
                'printerConfig' => [
                    'name' => $branch->default_printer_name ?? '',
                    'ipAddress' => $branch->default_printer_ip ?? '',
                    'port' => $branch->default_printer_port ?? 9100,
                    'paperWidth' => $branch->default_paper_width ?? '80mm',
                    'enabled' => (bool) ($branch->receipt_printing_enabled ?? false),
                ],
            ]);

        return response()->json(['data' => $branches]);
    }
}
