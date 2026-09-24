<?php

use App\Domain\Customer\CustomerDomainException;
use App\Exceptions\OrderLifecycleException;
use App\Support\DomainErrorMessages;
use App\Support\SafeExceptionResponse;
use App\Support\ValidationErrorPresenter;
use App\Http\Middleware\AuthenticateApiToken;
use App\Http\Middleware\AuthenticatePlatformAdmin;
use App\Http\Middleware\CanAdministerCafePrinting;
use App\Http\Middleware\CanManageCafeConfiguration;
use App\Http\Middleware\CanManageEmployees;
use App\Http\Middleware\CanManageMenuManagement;
use App\Http\Middleware\EnsureBarCheckPermission;
use App\Http\Middleware\EnsureBranchAccess;
use App\Http\Middleware\EnsureCashierPermission;
use App\Http\Middleware\EnsureCustomerPermission;
use App\Http\Middleware\EnsureDiscountPermission;
use App\Http\Middleware\EnsureFinancePermission;
use App\Http\Middleware\EnsureInventoryPermission;
use App\Http\Middleware\EnsurePlatformPermission;
use App\Http\Middleware\MeasurePaymentPerformance;
use App\Http\Middleware\RequireChangedPassword;
use App\Services\Customer\Import\CustomerImportException;
use App\Http\Middleware\SetLocaleFromRequest;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Request as SymfonyRequest;

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
        $middleware->prepend(MeasurePaymentPerformance::class);
        $middleware->prepend(SetLocaleFromRequest::class);
        $middleware->trustProxies(
            // This runs before the configuration repository exists. Render
            // supplies this as a process environment variable, which remains
            // available when Laravel configuration is cached.
            at: env('TRUSTED_PROXIES'),
            headers: SymfonyRequest::HEADER_X_FORWARDED_FOR
                | SymfonyRequest::HEADER_X_FORWARDED_HOST
                | SymfonyRequest::HEADER_X_FORWARDED_PORT
                | SymfonyRequest::HEADER_X_FORWARDED_PROTO,
        );
        $middleware->alias([
            'api.token' => AuthenticateApiToken::class,
            'platform.admin' => AuthenticatePlatformAdmin::class,
            'platform.permission' => EnsurePlatformPermission::class,
            'password.changed' => RequireChangedPassword::class,
            'employees.manage' => CanManageEmployees::class,
            'cafe.configuration' => CanManageCafeConfiguration::class,
            'cafe.configuration.printing' => CanAdministerCafePrinting::class,
            'menu.management' => CanManageMenuManagement::class,
            'branch.access' => EnsureBranchAccess::class,
            'inventory.permission' => EnsureInventoryPermission::class,
            'barcheck.permission' => EnsureBarCheckPermission::class,
            'finance.permission' => EnsureFinancePermission::class,
            'customer.permission' => EnsureCustomerPermission::class,
            'cashier.permission' => EnsureCashierPermission::class,
            'discount.permission' => EnsureDiscountPermission::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*'),
        );
        $exceptions->render(function (OrderLifecycleException $exception, Request $request) {
            if ($request->is('api/*')) {
                return response()->json([
                    'message' => DomainErrorMessages::forCode($exception->domainCode),
                    'code' => $exception->domainCode,
                ], str_ends_with($exception->domainCode, 'IDEMPOTENCY_CONFLICT') ? 409 : 422);
            }
        });
        $exceptions->render(function (CustomerDomainException $exception, Request $request) {
            if ($request->is('api/*')) {
                return response()->json(['message' => DomainErrorMessages::forCode($exception->domainCode), 'code' => $exception->domainCode], $exception->status);
            }
        });
        $exceptions->render(function (CustomerImportException $exception, Request $request) {
            if ($request->is('api/*')) {
                return response()->json(['message' => 'Customer import request could not be completed.', 'code' => $exception->domainCode], $exception->status);
            }
        });
        $exceptions->render(function (DomainException $exception, Request $request) {
            if ($request->is('api/*')) {
                return response()->json(['message' => DomainErrorMessages::forCode('DOMAIN_RULE_VIOLATION'), 'code' => 'DOMAIN_RULE_VIOLATION'], 422);
            }
        });
        $exceptions->render(function (ValidationException $exception, Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }

            $errors = ValidationErrorPresenter::present($exception->errors());

            if ($request->is('api/v1/orders/*/pay')) {
                $code = match (true) {
                    isset($errors['shiftId']) => 'NO_OPEN_SHIFT',
                    isset($errors['paymentMethodId']) => 'PAYMENT_METHOD_INVALID',
                    isset($errors['lines']) => 'ACCOUNTING_CONFIGURATION_MISSING',
                    isset($errors['quantity']), isset($errors['warehouseId']) => 'INSUFFICIENT_STOCK',
                    default => 'PAYMENT_VALIDATION_FAILED',
                };

                return response()->json(['message' => DomainErrorMessages::forCode($code), 'code' => $code, 'errors' => $errors], 422);
            }

            return response()->json(['message' => 'يرجى تصحيح البيانات المدخلة.', 'errors' => $errors], 422);
        });
        // Unexpected server failures must never leak SQL, file paths, or class
        // names to the client — the real exception is still logged normally
        // (this render callback only changes the response body).
        $exceptions->render(function (\Throwable $exception, Request $request) {
            if (! $request->is('api/*') || ! SafeExceptionResponse::shouldReplace($exception, (bool) config('app.debug'))) {
                return null;
            }

            return response()->json(SafeExceptionResponse::body(), 500);
        });
    })->create();
