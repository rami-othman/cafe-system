<?php

namespace App\Http\Middleware;

use App\Support\ManufacturingAccess;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureManufacturingPermission
{
    public function handle(Request $request, Closure $next, string $permission): Response
    {
        ManufacturingAccess::authorize($request, $permission);
        $scope = \App\Support\DataScope::resolve($request);
        if ($scope !== null) {
            $request->query->set('branchId', $scope);
            $request->merge(['branchId' => $scope]);
        }

        return $next($request);
    }
}
