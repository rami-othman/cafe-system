<?php

namespace App\Http\Middleware;

use App\Services\SuperAdmin\PlatformAccessService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsurePlatformPermission
{
    public function handle(Request $request, Closure $next, string $permission): Response
    {
        if (! app(PlatformAccessService::class)->hasPermission($request->user(), $permission)) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }

        return $next($request);
    }
}
