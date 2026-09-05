<?php

namespace App\Http\Middleware;

use App\Services\CafeConfigurationPolicy;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CanManageCafeConfiguration
{
    public function __construct(private readonly CafeConfigurationPolicy $policy) {}

    public function handle(Request $request, Closure $next): Response
    {
        $this->policy->assertCanManageBranches($request->attributes->get('auth_user'));

        return $next($request);
    }
}
