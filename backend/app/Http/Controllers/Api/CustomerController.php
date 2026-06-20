<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CustomerController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        $query = DB::table('customers')
            ->where('tenant_id', $tenantId)
            ->where('is_active', true)
            ->whereNull('deleted_at');

        if ($request->filled('search')) {
            $search = '%'.$request->query('search').'%';
            $query->where(fn ($q) => $q->where('name', 'like', $search)->orWhere('phone', 'like', $search));
        }

        $customers = $query->orderBy('name')->limit(30)->get()
            ->map(function ($customer) {
                $totalSpent = (float) $customer->total_spent;

                return [
                    'id' => $customer->id,
                    'name' => $customer->name,
                    'phone' => $customer->phone,
                    'email' => $customer->email,
                    'totalSpent' => $totalSpent,
                    'visitsCount' => $customer->visits_count,
                    'loyaltyPoints' => (int) round($totalSpent),
                    'tier' => match (true) {
                        $totalSpent >= 1000 => 'vip',
                        $totalSpent >= 250 => 'regular',
                        default => 'new',
                    },
                ];
            });

        return response()->json(['data' => $customers]);
    }
}
