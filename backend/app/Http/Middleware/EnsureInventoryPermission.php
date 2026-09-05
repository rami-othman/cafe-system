<?php

namespace App\Http\Middleware;

use App\Support\InventoryAccess;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureInventoryPermission
{
    public function handle(Request $request, Closure $next, string $permission): Response
    {
        InventoryAccess::authorize($request, $permission);

        return $next($request);
    }
}
