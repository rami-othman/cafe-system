<?php

namespace App\Http\Middleware;

use App\Services\TemporaryMenuManagementPolicy;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CanManageMenuManagement
{
    public function __construct(private readonly TemporaryMenuManagementPolicy $policy) {}

    public function handle(Request $request, Closure $next): Response
    {
        $this->policy->assertCanManage($request->attributes->get('auth_user'));

        return $next($request);
    }
}
