<?php

namespace App\Http\Middleware;

use App\Models\User;
use App\Services\DefaultTenantRoleService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\HttpException;

/**
 * Central boundary for the cafe's operational surface (shift, POS orders and
 * payments, discounts): the factory_manager role has no business here at all
 * (Decision 1/6, 26/09/2026). Blocking here — once, at the route-group level
 * — keeps individual controllers (ShiftController, PosOrderController,
 * PaymentController, DiscountController) from each growing their own
 * role check.
 */
class EnsureCafeOperationalAccess
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->attributes->get('auth_user');
        if ($user instanceof User && $user->effectiveRoleCode() === DefaultTenantRoleService::FACTORY_MANAGER) {
            throw new HttpException(403, 'هذه العملية غير متاحة لمستخدم المعمل.');
        }

        return $next($request);
    }
}
