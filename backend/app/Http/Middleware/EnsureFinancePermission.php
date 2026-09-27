<?php
namespace App\Http\Middleware;
use App\Support\FinanceAccess;
use Closure; use Illuminate\Http\Request; use Symfony\Component\HttpFoundation\Response;
final class EnsureFinancePermission { public function handle(Request $request, Closure $next, string $permission): Response { FinanceAccess::authorize($request,$permission); if (FinanceAccess::actor($request)->effectiveRoleCode() === 'factory_manager') { $branch = \App\Support\DataScope::resolve($request); $request->query->set('branchId', $branch); $request->merge(['branchId' => $branch]); } return $next($request); } }
