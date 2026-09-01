<?php

use App\Exceptions\OrderLifecycleException;
use App\Http\Middleware\AuthenticateApiToken;
use App\Http\Middleware\AuthenticatePlatformAdmin;
use App\Http\Middleware\CanManageEmployees;
use App\Http\Middleware\CanManageMenuManagement;
use App\Http\Middleware\EnsureBranchAccess;
use App\Http\Middleware\EnsurePlatformPermission;
use App\Http\Middleware\RequireChangedPassword;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        then: function (): void {
            Route::middleware('web')->prefix('api/super-admin/v1')->group(base_path('routes/super_admin.php'));
        },
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'api.token' => AuthenticateApiToken::class,
            'platform.admin' => AuthenticatePlatformAdmin::class,
            'platform.permission' => EnsurePlatformPermission::class,
            'password.changed' => RequireChangedPassword::class,
            'employees.manage' => CanManageEmployees::class,
            'menu.management' => CanManageMenuManagement::class,
            'branch.access' => EnsureBranchAccess::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*'),
        );
        $exceptions->render(function (OrderLifecycleException $exception, Request $request) {
            if ($request->is('api/*')) {
                return response()->json([
                    'message' => $exception->getMessage(),
                    'code' => $exception->domainCode,
                ], 422);
            }
        });
        $exceptions->render(function (DomainException $exception, Request $request) {
            if ($request->is('api/*')) {
                return response()->json(['message' => $exception->getMessage(), 'code' => 'DOMAIN_RULE_VIOLATION'], 422);
            }
        });
    })->create();
