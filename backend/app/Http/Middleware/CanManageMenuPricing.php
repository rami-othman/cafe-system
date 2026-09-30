<?php

namespace App\Http\Middleware;

use App\Services\Menu\MenuPricingPolicy;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CanManageMenuPricing
{
    public function __construct(private readonly MenuPricingPolicy $policy) {}

    public function handle(Request $request, Closure $next): Response
    {
        if (! $this->policy->canManage($request->attributes->get('auth_user'))) {
            return response()->json(['message' => 'Menu pricing access is denied.', 'code' => 'MENU_PRICING_FORBIDDEN'], 403);
        }
        return $next($request);
    }
}
