<?php

namespace App\Http\Middleware;

use App\Support\InventoryAccess;
use App\Support\FinanceAccess;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureInventoryPermission
{
    public function handle(Request $request, Closure $next, string $permission, string $purchaseReference = ''): Response
    {
        // Only explicitly marked read routes supply purchase reference data.
        // This does not grant access to stock reports or inventory mutations.
        if ($purchaseReference === 'purchase-reference' && $request->isMethod('GET')
            && (FinanceAccess::allows($request, 'finance.purchases.create')
                || FinanceAccess::allows($request, 'finance.purchases.edit'))) {
            return $next($request);
        }
        InventoryAccess::authorize($request, $permission);

        return $next($request);
    }
}
