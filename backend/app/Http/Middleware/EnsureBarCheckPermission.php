<?php

namespace App\Http\Middleware;

use App\Support\BarCheckAccess;
use Closure;
use Illuminate\Http\Request;
use InvalidArgumentException;
use Symfony\Component\HttpFoundation\Response;

/**
 * Gates the bar-check-related inventory routes. Owner/manager behave exactly
 * as under EnsureInventoryPermission; an employee (cashier) is authorized
 * only for their own open shift's shift_check stock count via BarCheckAccess.
 */
class EnsureBarCheckPermission
{
    public function handle(Request $request, Closure $next, string $mode, string $permission): Response
    {
        match ($mode) {
            'templates' => BarCheckAccess::authorizeTemplatesRead($request),
            'index' => BarCheckAccess::authorizeBarChecksIndex($request),
            'start' => BarCheckAccess::authorizeStart($request),
            'count' => BarCheckAccess::authorizeCount($request, $permission),
            default => throw new InvalidArgumentException("Unknown bar check permission mode [{$mode}]."),
        };

        return $next($request);
    }
}
