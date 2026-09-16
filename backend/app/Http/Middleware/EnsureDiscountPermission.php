<?php

namespace App\Http\Middleware;

use App\Domain\Discount\DiscountAccess;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class EnsureDiscountPermission
{
    public function __construct(private readonly DiscountAccess $access) {}

    public function handle(Request $request, Closure $next, string $permission): Response
    {
        $this->access->authorize($request, $permission);

        return $next($request);
    }
}
