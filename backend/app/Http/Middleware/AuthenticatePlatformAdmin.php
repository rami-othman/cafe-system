<?php

namespace App\Http\Middleware;

use App\Services\SuperAdmin\PlatformAccessService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AuthenticatePlatformAdmin
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        if (! $user || ! app(PlatformAccessService::class)->isPlatformAdmin($user)) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        return $next($request);
    }
}
