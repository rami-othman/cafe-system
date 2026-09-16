<?php

namespace App\Http\Middleware;

use App\Domain\Customer\CustomerAccess;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class EnsureCustomerPermission
{
    public function __construct(private readonly CustomerAccess $access) {}

    public function handle(Request $request, Closure $next, string $permission): Response
    {
        $this->access->allows($request, $permission) || abort(403, 'Customer permission denied.');

        return $next($request);
    }
}
