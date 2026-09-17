<?php

namespace App\Http\Middleware;

use App\Support\CashierAccess;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureCashierPermission
{
    public function handle(Request $request, Closure $next, string $permission): Response
    {
        CashierAccess::authorize($request, $permission);

        return $next($request);
    }
}
