<?php
namespace App\Http\Middleware;
use App\Support\FinanceAccess;
use Closure; use Illuminate\Http\Request; use Symfony\Component\HttpFoundation\Response;
final class EnsureFinancePermission { public function handle(Request $request, Closure $next, string $permission): Response { FinanceAccess::authorize($request,$permission); return $next($request); } }
