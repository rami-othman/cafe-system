<?php

use App\Http\Controllers\Api\SuperAdmin\V1\DashboardController;
use App\Http\Controllers\Api\SuperAdmin\V1\PlatformAuthController;
use App\Http\Controllers\Api\SuperAdmin\V1\PlatformManagementController;
use App\Http\Controllers\Api\SuperAdmin\V1\TenantController;
use Illuminate\Support\Facades\Route;

Route::get('auth/csrf', [PlatformAuthController::class, 'csrf']);
Route::post('auth/login', [PlatformAuthController::class, 'login'])->middleware('throttle:super-admin-login');
Route::middleware('platform.admin')->group(function (): void {
    Route::post('auth/logout', [PlatformAuthController::class, 'logout']);
    Route::get('auth/me', [PlatformAuthController::class, 'me']);
    Route::get('dashboard', [DashboardController::class, 'show'])->middleware('platform.permission:dashboard.view');
    Route::get('tenants', [TenantController::class, 'index'])->middleware('platform.permission:tenants.view');
    Route::post('tenants', [TenantController::class, 'store'])->middleware(['platform.permission:tenants.create', 'throttle:super-admin-mutation']);
    Route::get('tenants/{tenant}', [TenantController::class, 'show'])->middleware('platform.permission:tenants.view');
    Route::put('tenants/{tenant}/status', [TenantController::class, 'status'])->middleware(['platform.permission:tenants.suspend', 'throttle:super-admin-mutation']);
    Route::get('branches', [PlatformManagementController::class, 'branches'])->middleware('platform.permission:branches.manage');
    Route::put('branches/{branch}', [PlatformManagementController::class, 'updateBranch'])->middleware(['platform.permission:branches.manage', 'throttle:super-admin-mutation']);
    Route::get('tenant-users', [PlatformManagementController::class, 'tenantUsers'])->middleware('platform.permission:tenant_users.manage');
    Route::put('tenant-users/{user}', [PlatformManagementController::class, 'updateTenantUser'])->middleware(['platform.permission:tenant_users.manage', 'throttle:super-admin-mutation']);
    Route::get('plans', [PlatformManagementController::class, 'plans'])->middleware('platform.permission:plans.manage');
    Route::post('plans', [PlatformManagementController::class, 'storePlan'])->middleware(['platform.permission:plans.manage', 'throttle:super-admin-mutation']);
    Route::put('plans/{plan}', [PlatformManagementController::class, 'updatePlan'])->middleware(['platform.permission:plans.manage', 'throttle:super-admin-mutation']);
    Route::get('subscriptions', [PlatformManagementController::class, 'subscriptions'])->middleware('platform.permission:subscriptions.manage');
    Route::put('subscriptions/{subscription}', [PlatformManagementController::class, 'updateSubscription'])->middleware(['platform.permission:subscriptions.manage', 'throttle:super-admin-mutation']);
    Route::get('analytics/overview', [PlatformManagementController::class, 'analytics'])->middleware('platform.permission:analytics.view');
    Route::get('audit-logs', [PlatformManagementController::class, 'auditLogs'])->middleware('platform.permission:audit_logs.view');
    Route::get('announcements', [PlatformManagementController::class, 'announcements'])->middleware('platform.permission:announcements.manage');
    Route::post('announcements', [PlatformManagementController::class, 'storeAnnouncement'])->middleware(['platform.permission:announcements.manage', 'throttle:super-admin-mutation']);
    Route::put('announcements/{announcement}', [PlatformManagementController::class, 'updateAnnouncement'])->middleware(['platform.permission:announcements.manage', 'throttle:super-admin-mutation']);
    Route::get('system/health', [PlatformManagementController::class, 'health'])->middleware('platform.permission:system_health.view');
    Route::get('settings', [PlatformManagementController::class, 'settings'])->middleware('platform.permission:platform_settings.manage');
    Route::put('settings/{setting}', [PlatformManagementController::class, 'updateSetting'])->middleware(['platform.permission:platform_settings.manage', 'throttle:super-admin-mutation']);
    Route::get('platform-admins', [PlatformManagementController::class, 'platformAdmins'])->middleware('platform.permission:platform_admins.manage');
    Route::get('exports/tenants', [PlatformManagementController::class, 'exportTenants'])->middleware('platform.permission:exports.create');
});
