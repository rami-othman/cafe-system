<?php

namespace App\Http\Middleware;

use App\Services\EmployeeAdministrationPolicy;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CanManageEmployees
{
    public function __construct(private readonly EmployeeAdministrationPolicy $policy) {}

    public function handle(Request $request, Closure $next): Response
    {
        $this->policy->assertCanManageEmployees($request->attributes->get('auth_user'));

        return $next($request);
    }
}
