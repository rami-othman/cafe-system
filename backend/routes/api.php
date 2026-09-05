<?php

use App\Http\Controllers\Api\Admin\Catalog\CatalogReferenceController;
use App\Http\Controllers\Api\Admin\Catalog\ModifierCatalogController;
use App\Http\Controllers\Api\Admin\Catalog\OperationalAvailabilityController;
use App\Http\Controllers\Api\Admin\Catalog\ProductAvailabilityRuleController;
use App\Http\Controllers\Api\Admin\Catalog\ProductCatalogController;
use App\Http\Controllers\Api\Admin\Catalog\ProductVariantPriceOverrideController;
use App\Http\Controllers\Api\Admin\Catalog\RecipeConfigurationController;
use App\Http\Controllers\Api\Admin\Menu\MenuAssignmentController as AdminMenuAssignmentController;
use App\Http\Controllers\Api\Admin\Menu\MenuAssignmentScopeController;
use App\Http\Controllers\Api\Admin\Menu\MenuAvailabilityRuleController;
use App\Http\Controllers\Api\Admin\Menu\MenuController as AdminMenuController;
use App\Http\Controllers\Api\Admin\Menu\MenuItemPlacementController;
use App\Http\Controllers\Api\Admin\Menu\MenuPreviewController;
use App\Http\Controllers\Api\Admin\Menu\MenuPublishingController;
use App\Http\Controllers\Api\Admin\Menu\MenuSectionController;
use App\Http\Controllers\Api\Admin\Menu\MenuValidationController;
use App\Http\Controllers\Api\Admin\Menu\ProductMenuUsageController;
use App\Http\Controllers\Api\Admin\Menu\PublishedMenuVersionController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BranchController;
use App\Http\Controllers\Api\AccountingPeriodController;
use App\Http\Controllers\Api\BarCheckController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\DailyReportController;
use App\Http\Controllers\Api\DiscountController;
use App\Http\Controllers\Api\DailyClosingController;
use App\Http\Controllers\Api\ExpenseCategoryController;
use App\Http\Controllers\Api\ExpenseController;
use App\Http\Controllers\Api\FinanceDashboardController;
use App\Http\Controllers\Api\FinancialAccountController;
use App\Http\Controllers\Api\FinancialLocationController;
use App\Http\Controllers\Api\FinancialReconciliationController;
use App\Http\Controllers\Api\FinancialReportController;
use App\Http\Controllers\Api\FinancialSetupStatusController;
use App\Http\Controllers\Api\FinancialTransactionController;
use App\Http\Controllers\Api\FinanceApprovalRuleController;
use App\Http\Controllers\Api\FinanceRolePermissionController;
use App\Http\Controllers\Api\InventoryBalanceController;
use App\Http\Controllers\Api\InventoryItemController;
use App\Http\Controllers\Api\InventoryItemUnitConversionController;
use App\Http\Controllers\Api\JournalEntryController;
use App\Http\Controllers\Api\PaymentMethodController;
use App\Http\Controllers\Api\EmployeeManagementController;
use App\Http\Controllers\Api\MenuController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\PosMenuSyncController;
use App\Http\Controllers\Api\PosOrderController;
use App\Http\Controllers\Api\PosStateController;
use App\Http\Controllers\Api\ReceiptController;
use App\Http\Controllers\Api\RefundController;
use App\Http\Controllers\Api\ReportsOverviewController;
use App\Http\Controllers\Api\ShiftController;
use App\Http\Controllers\Api\StockCountController;
use App\Http\Controllers\Api\StockMovementController;
use App\Http\Controllers\Api\SupplierController;
use App\Http\Controllers\Api\SupplierInvoiceController;
use App\Http\Controllers\Api\SupplierPaymentController;
use App\Http\Controllers\Api\TableController;
use App\Http\Controllers\Api\TenantRoleController;
use App\Http\Controllers\Api\WarehouseController;
use App\Http\Controllers\Api\WarehouseTransferController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::prefix('auth')->group(function (): void {
        Route::post('login', [AuthController::class, 'login']);
        Route::middleware('api.token')->group(function (): void {
            Route::get('me', [AuthController::class, 'me']);
            Route::post('change-password', [AuthController::class, 'changePassword']);
            Route::post('logout', [AuthController::class, 'logout']);
        });
    });

    Route::middleware(['api.token', 'password.changed', 'employees.manage'])->group(function (): void {
        Route::get('roles', [TenantRoleController::class, 'index']);
        Route::controller(EmployeeManagementController::class)->prefix('employees')->group(function (): void {
            Route::get('/', 'index');
            Route::post('/', 'store');
            Route::get('{employee}', 'show');
            Route::put('{employee}', 'update');
            Route::post('{employee}/activate', 'activate');
            Route::post('{employee}/deactivate', 'deactivate');
            Route::post('{employee}/archive', 'archive');
            Route::post('{employee}/reset-password', 'resetPassword');
        });
    });

    Route::get('product-images/{tenant}/{filename}', [ProductCatalogController::class, 'showProductImage'])
        ->whereNumber('tenant');

    // Tenant operational boundary. Tenant identity comes solely from the
    // opaque bearer token; X-Tenant-Id is legacy-only and is never authority
    // inside this group. The public image endpoint above intentionally stays
    // public because Flutter image widgets cannot attach the API bearer header.
    Route::middleware(['api.token', 'password.changed', 'branch.access'])->group(function (): void {

        Route::middleware('menu.management')->prefix('admin/catalog')->group(function (): void {
            Route::controller(CatalogReferenceController::class)->group(function (): void {
                Route::get('categories', 'categories');
                Route::post('categories', 'storeCategory');
                Route::get('categories/{category}', 'showCategory');
                Route::patch('categories/{category}', 'updateCategory');
                Route::post('categories/{category}/archive', 'archiveCategory');
                Route::post('categories/{category}/restore', 'restoreCategory');
                Route::post('categories/reorder', 'reorderCategories');
                Route::get('reporting-categories', 'reportingCategories');
                Route::post('reporting-categories', 'storeReportingCategory');
                Route::get('reporting-categories/{reportingCategory}', 'showReportingCategory');
                Route::patch('reporting-categories/{reportingCategory}', 'updateReportingCategory');
                Route::post('reporting-categories/{reportingCategory}/archive', 'archiveReportingCategory');
                Route::post('reporting-categories/{reportingCategory}/restore', 'restoreReportingCategory');
                Route::post('reporting-categories/reorder', 'reorderReportingCategories');
                Route::get('kitchen-stations', 'kitchenStations');
                Route::post('kitchen-stations', 'storeKitchenStation');
                Route::get('kitchen-stations/{kitchenStation}', 'showKitchenStation');
                Route::patch('kitchen-stations/{kitchenStation}', 'updateKitchenStation');
                Route::post('kitchen-stations/{kitchenStation}/archive', 'archiveKitchenStation');
                Route::post('kitchen-stations/{kitchenStation}/restore', 'restoreKitchenStation');
                Route::post('kitchen-stations/reorder', 'reorderKitchenStations');
            });
            Route::controller(ProductCatalogController::class)->group(function (): void {
                Route::get('products', 'index');
                Route::post('products', 'store');
                Route::post('product-images', 'uploadProductImage');
                Route::get('products/{product}', 'show');
                Route::patch('products/{product}', 'update');
                Route::post('products/{product}/archive', 'archive');
                Route::post('products/{product}/restore', 'restore');
                Route::post('products/{product}/variants', 'storeVariant');
                Route::post('products/{product}/variants/reorder', 'reorderVariants');
                Route::patch('product-variants/{variant}', 'updateVariant');
                Route::post('product-variants/{variant}/set-default', 'setDefaultVariant');
                Route::post('product-variants/{variant}/archive', 'archiveVariant');
                Route::post('product-variants/{variant}/restore', 'restoreVariant');
                Route::get('products/{product}/modifier-groups', 'modifierGroups');
                Route::put('products/{product}/modifier-groups', 'syncModifierGroups');
            });
            Route::controller(ProductVariantPriceOverrideController::class)->group(function (): void {
                Route::get('product-variants/{variant}/price-overrides', 'index');
                Route::put('product-variants/{variant}/price-overrides', 'sync');
                Route::get('product-variants/{variant}/effective-price', 'effectivePrice');
            });
            Route::controller(RecipeConfigurationController::class)->group(function (): void {
                Route::get('materials', 'materials');
                Route::get('product-variants/{variant}/recipe', 'recipe');
                Route::put('product-variants/{variant}/recipe', 'putRecipe');
                Route::post('product-variants/{variant}/recipe/resolve', 'resolve');
                Route::get('product-variants/{variant}/recipe-material-effects', 'profileSummary');
                Route::get('modifier-groups/{modifierGroup}/recipe-material-effects', 'modifierGroupProfileSummary');
                Route::get('modifier-options/{option}/recipe-adjustments', 'profile');
                Route::put('modifier-options/{option}/recipe-adjustments', 'putProfile');
                Route::get('products/{product}/modifier-options/{option}/recipe-adjustments', 'profile');
                Route::put('products/{product}/modifier-options/{option}/recipe-adjustments', 'putProfile');
                Route::delete('products/{product}/modifier-options/{option}/recipe-adjustments', 'deleteProfile');
                Route::get('product-variants/{variant}/modifier-options/{option}/recipe-adjustments', 'profile');
                Route::put('product-variants/{variant}/modifier-options/{option}/recipe-adjustments', 'putProfile');
                Route::delete('product-variants/{variant}/modifier-options/{option}/recipe-adjustments', 'deleteProfile');
            });
            Route::controller(ProductAvailabilityRuleController::class)->group(function (): void {
                Route::get('products/{product}/availability-rules', 'index');
                Route::put('products/{product}/availability-rules', 'sync');
                Route::get('products/{product}/availability-preview', 'preview');
            });
            Route::controller(OperationalAvailabilityController::class)->group(function (): void {
                Route::get('operational-availability', 'index');
                Route::put('products/{product}/operational-availability', 'updateProduct');
                Route::delete('products/{product}/operational-availability', 'clearProduct');
                Route::put('product-variants/{variant}/operational-availability', 'updateVariant');
                Route::delete('product-variants/{variant}/operational-availability', 'clearVariant');
                Route::get('products/{product}/operational-availability-preview', 'preview');
            });
            Route::controller(ModifierCatalogController::class)->group(function (): void {
                Route::get('modifier-groups', 'index');
                Route::post('modifier-groups', 'store');
                Route::get('modifier-groups/{modifierGroup}', 'show');
                Route::patch('modifier-groups/{modifierGroup}', 'update');
                Route::post('modifier-groups/{modifierGroup}/archive', 'archive');
                Route::post('modifier-groups/{modifierGroup}/restore', 'restore');
                Route::post('modifier-groups/reorder', 'reorder');
                Route::post('modifier-groups/{modifierGroup}/options', 'storeOption');
                Route::post('modifier-groups/{modifierGroup}/options/reorder', 'reorderOptions');
                Route::patch('modifier-options/{modifierOption}', 'updateOption');
                Route::post('modifier-options/{modifierOption}/archive', 'archiveOption');
                Route::post('modifier-options/{modifierOption}/restore', 'restoreOption');
            });
            Route::get('products/{product}/menu-usage', [ProductMenuUsageController::class, 'show']);
        });

        Route::middleware('menu.management')->prefix('admin')->group(function (): void {
            Route::controller(AdminMenuController::class)->prefix('menus')->group(function (): void {
                Route::get('/', 'index');
                Route::post('/', 'store');
                Route::post('reorder', 'reorder');
                Route::get('{menu}', 'show');
                Route::patch('{menu}', 'update');
                Route::post('{menu}/archive', 'archive');
                Route::post('{menu}/restore', 'restore');
            });
            Route::controller(MenuValidationController::class)->group(function (): void {
                Route::post('menus/{menu}/validate', 'validateMenu');
                Route::post('menu-management/validate', 'validateCollection');
            });
            Route::controller(MenuPreviewController::class)->group(function (): void {
                Route::post('menus/{menu}/preview', 'previewMenu');
                Route::post('menu-management/preview', 'previewCollection');
            });
            Route::controller(MenuPublishingController::class)->group(function (): void {
                Route::post('menu-management/publish', 'publish');
                Route::get('menu-management/current-version', 'current');
            });
            Route::controller(PublishedMenuVersionController::class)->group(function (): void {
                Route::get('menu-management/versions', 'index');
                Route::get('menu-management/versions/{version}', 'show');
                Route::get('menu-management/versions/{version}/compare', 'compare');
                Route::post('menu-management/versions/{version}/rollback', 'rollback');
            });
            Route::controller(MenuSectionController::class)->group(function (): void {
                Route::get('menus/{menu}/sections', 'index');
                Route::post('menus/{menu}/sections', 'store');
                Route::post('menus/{menu}/sections/reorder', 'reorder');
                Route::patch('menu-sections/{section}', 'update');
                Route::post('menu-sections/{section}/archive', 'archive');
                Route::post('menu-sections/{section}/restore', 'restore');
            });
            Route::controller(MenuItemPlacementController::class)->group(function (): void {
                Route::get('menu-sections/{section}/placements', 'index');
                Route::post('menu-sections/{section}/placements', 'store');
                Route::put('menu-sections/{section}/placements', 'sync');
                Route::post('menu-sections/{section}/placements/reorder', 'reorder');
                Route::patch('menu-item-placements/{placement}', 'update');
                Route::post('menu-item-placements/{placement}/archive', 'archive');
                Route::post('menu-item-placements/{placement}/restore', 'restore');
                Route::post('menu-item-placements/{placement}/move', 'move');
            });
            Route::controller(AdminMenuAssignmentController::class)->group(function (): void {
                Route::get('menus/{menu}/assignments', 'index');
                Route::put('menus/{menu}/assignments', 'sync');
            });
            Route::controller(MenuAssignmentScopeController::class)->group(function (): void {
                Route::get('menu-management/assignments', 'index');
                Route::put('menu-management/assignments', 'sync');
            });
            Route::controller(MenuAvailabilityRuleController::class)->group(function (): void {
                Route::get('menus/{menu}/availability-rules', 'index');
                Route::put('menus/{menu}/availability-rules', 'sync');
            });
        });

        Route::get('branches', [BranchController::class, 'index']);
        Route::get('reports/daily', [DailyReportController::class, 'show'])->middleware('finance.permission:finance.reports.view');
        Route::get('reports/overview', [ReportsOverviewController::class, 'show'])->middleware('finance.permission:finance.reports.view');

        Route::get('shifts/current', [ShiftController::class, 'current']);
        Route::post('shifts/current', [ShiftController::class, 'open']);
        Route::post('shifts/{shift}/close', [ShiftController::class, 'close']);

        // Deprecated compatibility endpoints. Production POS uses pos/menu-sync
        // and snapshot-aware orders; retain these while external consumers migrate.
        Route::get('menu/categories', [MenuController::class, 'categories']);
        Route::get('menu/products', [MenuController::class, 'products']);
        Route::get('menu/products/{product}', [MenuController::class, 'product']);
        Route::get('pos/menu-sync', [PosMenuSyncController::class, 'show']);

        Route::get('customers', [CustomerController::class, 'index']);
        Route::get('tables', [TableController::class, 'index']);
        Route::get('pos/state', [PosStateController::class, 'show']);
        Route::get('discounts/available', [DiscountController::class, 'available']);
        Route::get('discounts', [DiscountController::class, 'index']);
        Route::post('discounts', [DiscountController::class, 'store']);
        Route::get('discounts/{discount}', [DiscountController::class, 'show']);
        Route::put('discounts/{discount}', [DiscountController::class, 'update']);
        Route::patch('discounts/{discount}', [DiscountController::class, 'update']);
        Route::patch('discounts/{discount}/status', [DiscountController::class, 'updateStatus']);
        Route::delete('discounts/{discount}', [DiscountController::class, 'destroy']);

        Route::get('orders', [PosOrderController::class, 'index']);
        Route::post('orders', [PosOrderController::class, 'store']);
        Route::get('orders/{order}', [PosOrderController::class, 'show']);
        Route::patch('orders/{order}', [PosOrderController::class, 'update']);
        Route::delete('orders/{order}', [PosOrderController::class, 'cancel']);
        Route::post('orders/{order}/items', [PosOrderController::class, 'addItem']);
        Route::patch('orders/{order}/items/{item}', [PosOrderController::class, 'updateItem']);
        Route::delete('orders/{order}/items/{item}', [PosOrderController::class, 'removeItem']);
        Route::post('orders/{order}/hold', [PosOrderController::class, 'hold']);
        Route::put('orders/{order}/discount', [PosOrderController::class, 'discount']);
        Route::delete('orders/{order}/discount', [PosOrderController::class, 'removeDiscount']);
        Route::post('orders/{order}/discounts/apply', [DiscountController::class, 'apply']);
        Route::delete('orders/{order}/discounts', [DiscountController::class, 'remove']);
        Route::get('orders/{order}/payment-summary', [PaymentController::class, 'summary']);
        Route::get('orders/{order}/receipt', [ReceiptController::class, 'show']);
        Route::post('orders/{order}/print', [ReceiptController::class, 'print']);
        Route::post('orders/{order}/pay', [PaymentController::class, 'pay']);
        Route::post('orders/{order}/refunds', [RefundController::class, 'store']);
    });

    // Inventory and Finance extend the authenticated operational boundary;
    // branch.access remains outer policy and feature permissions are additive.
    Route::middleware(['api.token', 'password.changed', 'branch.access'])->group(function (): void {
        Route::get('warehouses', [WarehouseController::class, 'index'])->middleware('inventory.permission:inventory.view');
        Route::post('warehouses', [WarehouseController::class, 'store'])->middleware('inventory.permission:inventory.locations.manage');
        Route::patch('warehouses/{warehouse}', [WarehouseController::class, 'update'])->middleware('inventory.permission:inventory.locations.manage');
        Route::patch('warehouses/{warehouse}/status', [WarehouseController::class, 'status'])->middleware('inventory.permission:inventory.locations.manage');

        Route::prefix('inventory')->group(function (): void {
            Route::get('dashboard', [InventoryBalanceController::class, 'dashboard'])->middleware('inventory.permission:inventory.view');
            Route::get('balances', [InventoryBalanceController::class, 'index'])->middleware('inventory.permission:inventory.view');
            Route::get('items', [InventoryItemController::class, 'index'])->middleware('inventory.permission:inventory.view');
            Route::post('items', [InventoryItemController::class, 'store'])->middleware('inventory.permission:inventory.items.manage');
            Route::get('items/{item}', [InventoryItemController::class, 'show'])->middleware('inventory.permission:inventory.view');
            Route::patch('items/{item}', [InventoryItemController::class, 'update'])->middleware('inventory.permission:inventory.items.manage');
            Route::patch('items/{item}/status', [InventoryItemController::class, 'status'])->middleware('inventory.permission:inventory.items.manage');
            Route::get('items/{item}/stock', [InventoryItemController::class, 'stock'])->middleware('inventory.permission:inventory.view');
            Route::get('items/{item}/movements', [InventoryItemController::class, 'movements'])->middleware('inventory.permission:inventory.view');
            Route::get('items/{item}/unit-conversions', [InventoryItemUnitConversionController::class, 'index'])->middleware('inventory.permission:inventory.view');
            Route::post('items/{item}/unit-conversions', [InventoryItemUnitConversionController::class, 'store'])->middleware('inventory.permission:inventory.items.manage');
            Route::patch('items/{item}/unit-conversions/{conversion}', [InventoryItemUnitConversionController::class, 'update'])->middleware('inventory.permission:inventory.items.manage');
            Route::get('units', [InventoryItemController::class, 'units'])->middleware('inventory.permission:inventory.view');
            Route::get('conversion-items', [InventoryItemController::class, 'conversionItems'])->middleware('inventory.permission:inventory.view');
            Route::get('movements', [StockMovementController::class, 'index'])->middleware('inventory.permission:inventory.view');
            Route::post('movements', [StockMovementController::class, 'store'])->middleware('inventory.permission:inventory.adjustments.create');
            Route::get('movements/{movement}', [StockMovementController::class, 'show'])->middleware('inventory.permission:inventory.view');
            Route::get('counts', [StockCountController::class, 'index'])->middleware('inventory.permission:inventory.counts.view');
            Route::post('counts', [StockCountController::class, 'store'])->middleware('inventory.permission:inventory.counts.create');
            Route::get('counts/{count}', [StockCountController::class, 'show'])->middleware('inventory.permission:inventory.counts.view');
            Route::put('counts/{count}/lines', [StockCountController::class, 'line'])->middleware('inventory.permission:inventory.counts.create');
            Route::post('counts/{count}/lines/{item}/review', [StockCountController::class, 'reviewLine'])->middleware('inventory.permission:inventory.counts.post');
            foreach (['start' => 'inventory.counts.create', 'submit' => 'inventory.counts.create', 'approve' => 'inventory.counts.post', 'post' => 'inventory.counts.post', 'cancel' => 'inventory.counts.create'] as $action => $permission) {
                Route::post("counts/{count}/{$action}", [StockCountController::class, 'action'])->defaults('action', $action)->middleware("inventory.permission:{$permission}");
            }
            Route::get('bar-checks', [BarCheckController::class, 'index'])->middleware('inventory.permission:inventory.counts.view');
            Route::post('bar-checks', [BarCheckController::class, 'start'])->middleware('inventory.permission:inventory.counts.create');
            Route::get('bar-check-templates', [BarCheckController::class, 'templates'])->middleware('inventory.permission:inventory.counts.view');
            Route::post('bar-check-templates', [BarCheckController::class, 'storeTemplate'])->middleware('inventory.permission:inventory.counts.create');
            Route::get('bar-check-templates/{template}', [BarCheckController::class, 'showTemplate'])->middleware('inventory.permission:inventory.counts.view');
            Route::patch('bar-check-templates/{template}', [BarCheckController::class, 'updateTemplate'])->middleware('inventory.permission:inventory.counts.create');
            Route::get('transfers', [WarehouseTransferController::class, 'index'])->middleware('inventory.permission:inventory.transfers.view');
            Route::post('transfers', [WarehouseTransferController::class, 'store'])->middleware('inventory.permission:inventory.transfers.create');
            Route::get('transfers/{transfer}', [WarehouseTransferController::class, 'show'])->middleware('inventory.permission:inventory.transfers.view');
            Route::patch('transfers/{transfer}', [WarehouseTransferController::class, 'update'])->middleware('inventory.permission:inventory.transfers.edit');
            Route::post('transfers/{transfer}/receive', [WarehouseTransferController::class, 'receive'])->middleware('inventory.permission:inventory.transfers.receive');
            foreach (['submit', 'approve', 'reject', 'dispatch', 'cancel'] as $action) {
                Route::post("transfers/{transfer}/{$action}", [WarehouseTransferController::class, 'action'])->defaults('action', $action)->middleware('inventory.permission:inventory.transfers.'.($action === 'reject' ? 'approve' : $action));
            }
            Route::post('transfers/{transfer}/close-shortage', [WarehouseTransferController::class, 'action'])->defaults('action', 'close-shortage')->middleware('inventory.permission:inventory.transfers.receive');
        });

        Route::prefix('finance')->group(function (): void {
            Route::get('dashboard', [FinanceDashboardController::class, 'show'])->middleware('finance.permission:finance.view');
            Route::get('dashboard/trends', [FinanceDashboardController::class, 'trends'])->middleware('finance.permission:finance.view');
            Route::get('dashboard/branches', [FinanceDashboardController::class, 'branches'])->middleware('finance.permission:finance.view');
            Route::get('setup-status', [FinancialSetupStatusController::class, 'show'])->middleware('finance.permission:finance.settings.view');
            Route::get('settings/approval-rules', [FinanceApprovalRuleController::class, 'index'])->middleware('finance.permission:finance.settings.view');
            Route::post('settings/approval-rules', [FinanceApprovalRuleController::class, 'store'])->middleware('finance.permission:finance.settings.manage');
            Route::patch('settings/approval-rules/{rule}', [FinanceApprovalRuleController::class, 'update'])->middleware('finance.permission:finance.settings.manage');
            Route::get('settings/role-permissions', [FinanceRolePermissionController::class, 'index'])->middleware('finance.permission:finance.settings.view');
            Route::get('settings/role-permissions/{role}', [FinanceRolePermissionController::class, 'show'])->middleware('finance.permission:finance.settings.view');
            Route::put('settings/role-permissions/{role}', [FinanceRolePermissionController::class, 'replace'])->middleware('finance.permission:finance.settings.manage');
            Route::get('reports', [FinancialReportController::class, 'index'])->middleware('finance.permission:finance.reports.view');
            Route::get('reports/profit-loss', [FinancialReportController::class, 'profitLoss'])->middleware('finance.permission:finance.reports.view');
            Route::get('reports/balance-sheet', [FinancialReportController::class, 'balanceSheet'])->middleware('finance.permission:finance.reports.view');
            Route::get('reports/cash-flow', [FinancialReportController::class, 'cashFlow'])->middleware('finance.permission:finance.reports.view');
            Route::get('reports/trial-balance', [FinancialReportController::class, 'trialBalance'])->middleware('finance.permission:finance.reports.view');
            Route::get('reports/general-ledger', [FinancialReportController::class, 'generalLedger'])->middleware('finance.permission:finance.reports.view');
            Route::get('reports/supplier-aging', [FinancialReportController::class, 'supplierAging'])->middleware('finance.permission:finance.reports.view');
            Route::get('reports/supplier-statement', [FinancialReportController::class, 'supplierStatement'])->middleware('finance.permission:finance.reports.view');
            Route::get('accounts', [FinancialAccountController::class, 'index'])->middleware('finance.permission:finance.accounts.view');
            Route::post('accounts', [FinancialAccountController::class, 'store'])->middleware('finance.permission:finance.accounts.manage');
            Route::patch('accounts/{account}/status', [FinancialAccountController::class, 'status'])->middleware('finance.permission:finance.accounts.manage');
            Route::patch('accounts/{account}', [FinancialAccountController::class, 'update'])->middleware('finance.permission:finance.accounts.manage');
            Route::get('accounts/{account}', [FinancialAccountController::class, 'show'])->middleware('finance.permission:finance.accounts.view');
            Route::get('journal-entries', [JournalEntryController::class, 'index'])->middleware('finance.permission:finance.journals.view');
            Route::post('journal-entries', [JournalEntryController::class, 'store'])->middleware('finance.permission:finance.journals.create');
            Route::get('journal-entries/{entry}', [JournalEntryController::class, 'show'])->middleware('finance.permission:finance.journals.view');
            Route::post('journal-entries/{entry}/post', [JournalEntryController::class, 'post'])->middleware('finance.permission:finance.journals.post');
            Route::post('journal-entries/{entry}/reverse', [JournalEntryController::class, 'reverse'])->middleware('finance.permission:finance.journals.reverse');
            Route::get('transactions/branches', [FinancialTransactionController::class, 'branches'])->middleware('finance.permission:finance.transactions.view');
            Route::get('transactions/summary', [FinancialTransactionController::class, 'summary'])->middleware('finance.permission:finance.transactions.view');
            Route::get('transactions', [FinancialTransactionController::class, 'index'])->middleware('finance.permission:finance.transactions.view');
            Route::get('transactions/{transaction}', [FinancialTransactionController::class, 'show'])->middleware('finance.permission:finance.transactions.view');
            foreach (['cash' => 'cash-accounts', 'bank' => 'bank-accounts'] as $kind => $uri) {
                Route::get($uri, [FinancialLocationController::class, 'index'])->defaults('kind', $kind)->middleware('finance.permission:finance.cash_accounts.view');
                Route::post($uri, [FinancialLocationController::class, 'store'])->defaults('kind', $kind)->middleware('finance.permission:finance.cash_accounts.manage');
                Route::patch("{$uri}/{location}/status", [FinancialLocationController::class, 'status'])->defaults('kind', $kind)->middleware('finance.permission:finance.cash_accounts.manage');
                Route::patch("{$uri}/{location}", [FinancialLocationController::class, 'update'])->defaults('kind', $kind)->middleware('finance.permission:finance.cash_accounts.manage');
                Route::get("{$uri}/{location}", [FinancialLocationController::class, 'show'])->defaults('kind', $kind)->middleware('finance.permission:finance.cash_accounts.view');
                Route::get("{$uri}/{location}/transactions", [FinancialLocationController::class, 'transactions'])->defaults('kind', $kind)->middleware('finance.permission:finance.cash_accounts.view');
            }
            Route::post('cash-transfers', [FinancialLocationController::class, 'transfer'])->middleware('finance.permission:finance.cash_transfer.create');
            Route::post('cash-transfers/{transfer}/reverse', [FinancialLocationController::class, 'reverseTransfer'])->middleware('finance.permission:finance.cash_transfer.reverse');
            Route::get('reconciliations', [FinancialReconciliationController::class, 'index'])->middleware('finance.permission:finance.reconciliation.view');
            Route::post('reconciliations', [FinancialReconciliationController::class, 'store'])->middleware('finance.permission:finance.reconciliation.manage');
            Route::get('reconciliations/{reconciliation}', [FinancialReconciliationController::class, 'show'])->middleware('finance.permission:finance.reconciliation.view');
            Route::patch('reconciliations/{reconciliation}', [FinancialReconciliationController::class, 'update'])->middleware('finance.permission:finance.reconciliation.manage');
            Route::get('reconciliations/{reconciliation}/system-transactions', [FinancialReconciliationController::class, 'systemTransactions'])->middleware('finance.permission:finance.reconciliation.view');
            Route::get('reconciliations/{reconciliation}/suggestions', [FinancialReconciliationController::class, 'suggestions'])->middleware('finance.permission:finance.reconciliation.view');
            Route::post('reconciliations/{reconciliation}/statement-lines', [FinancialReconciliationController::class, 'addLine'])->middleware('finance.permission:finance.reconciliation.manage');
            Route::patch('reconciliations/{reconciliation}/statement-lines/{line}', [FinancialReconciliationController::class, 'updateLine'])->middleware('finance.permission:finance.reconciliation.manage');
            Route::delete('reconciliations/{reconciliation}/statement-lines/{line}', [FinancialReconciliationController::class, 'deleteLine'])->middleware('finance.permission:finance.reconciliation.manage');
            Route::post('reconciliations/{reconciliation}/matches', [FinancialReconciliationController::class, 'match'])->middleware('finance.permission:finance.reconciliation.manage');
            Route::delete('reconciliations/{reconciliation}/matches/{match}', [FinancialReconciliationController::class, 'unmatch'])->middleware('finance.permission:finance.reconciliation.manage');
            Route::post('reconciliations/{reconciliation}/complete', [FinancialReconciliationController::class, 'complete'])->middleware('finance.permission:finance.reconciliation.complete');
            Route::get('payment-methods', [PaymentMethodController::class, 'index'])->middleware('finance.permission:finance.settings.view');
            Route::post('payment-methods', [PaymentMethodController::class, 'store'])->middleware('finance.permission:finance.settings.manage');
            Route::patch('payment-methods/{method}', [PaymentMethodController::class, 'update'])->middleware('finance.permission:finance.settings.manage');
            Route::patch('payment-methods/{method}/status', [PaymentMethodController::class, 'status'])->middleware('finance.permission:finance.settings.manage');
            Route::get('expense-categories', [ExpenseCategoryController::class, 'index'])->middleware('finance.permission:finance.settings.view');
            Route::post('expense-categories', [ExpenseCategoryController::class, 'store'])->middleware('finance.permission:finance.settings.manage');
            Route::patch('expense-categories/{category}', [ExpenseCategoryController::class, 'update'])->middleware('finance.permission:finance.settings.manage');
            Route::patch('expense-categories/{category}/status', [ExpenseCategoryController::class, 'status'])->middleware('finance.permission:finance.settings.manage');
            Route::get('expenses', [ExpenseController::class, 'index'])->middleware('finance.permission:finance.expenses.view');
            Route::get('expenses/summary', [ExpenseController::class, 'summary'])->middleware('finance.permission:finance.expenses.view');
            Route::get('expenses/branches', [ExpenseController::class, 'branches'])->middleware('finance.permission:finance.expenses.view');
            Route::post('expenses', [ExpenseController::class, 'store'])->middleware('finance.permission:finance.expenses.create');
            Route::get('expenses/{expense}', [ExpenseController::class, 'show'])->middleware('finance.permission:finance.expenses.view');
            Route::patch('expenses/{expense}', [ExpenseController::class, 'update'])->middleware('finance.permission:finance.expenses.edit');
            foreach (['submit', 'approve', 'reject'] as $action) {
                Route::post("expenses/{expense}/{$action}", [ExpenseController::class, 'action'])->defaults('action', $action)->middleware("finance.permission:finance.expenses.{$action}");
            }
            Route::post('expenses/{expense}/pay', [ExpenseController::class, 'pay'])->middleware('finance.permission:finance.expenses.pay');
            Route::post('expenses/{expense}/reverse', [ExpenseController::class, 'reverse'])->middleware('finance.permission:finance.expenses.reverse');
            Route::get('suppliers', [SupplierController::class, 'index'])->middleware('finance.permission:finance.suppliers.view');
            Route::post('suppliers', [SupplierController::class, 'store'])->middleware('finance.permission:finance.suppliers.manage');
            Route::patch('suppliers/{supplier}/status', [SupplierController::class, 'status'])->middleware('finance.permission:finance.suppliers.manage');
            Route::get('suppliers/{supplier}', [SupplierController::class, 'show'])->middleware('finance.permission:finance.suppliers.view');
            Route::patch('suppliers/{supplier}', [SupplierController::class, 'update'])->middleware('finance.permission:finance.suppliers.manage');
            Route::get('suppliers/{supplier}/statement', [SupplierController::class, 'statement'])->middleware('finance.permission:finance.suppliers.view');
            Route::get('supplier-invoices', [SupplierInvoiceController::class, 'index'])->middleware('finance.permission:finance.supplier_invoices.view');
            Route::post('supplier-invoices', [SupplierInvoiceController::class, 'store'])->middleware('finance.permission:finance.supplier_invoices.create');
            Route::get('supplier-invoices/{invoice}', [SupplierInvoiceController::class, 'show'])->middleware('finance.permission:finance.supplier_invoices.view');
            Route::patch('supplier-invoices/{invoice}', [SupplierInvoiceController::class, 'update'])->middleware('finance.permission:finance.supplier_invoices.edit');
            Route::post('supplier-invoices/{invoice}/post', [SupplierInvoiceController::class, 'post'])->middleware('finance.permission:finance.supplier_invoices.post');
            Route::post('supplier-invoices/{invoice}/reverse', [SupplierInvoiceController::class, 'reverse'])->middleware('finance.permission:finance.supplier_invoices.reverse');
            Route::get('supplier-payments', [SupplierPaymentController::class, 'index'])->middleware('finance.permission:finance.supplier_payments.view');
            Route::post('supplier-payments', [SupplierPaymentController::class, 'store'])->middleware('finance.permission:finance.supplier_payments.create');
            Route::get('supplier-payments/{payment}', [SupplierPaymentController::class, 'show'])->middleware('finance.permission:finance.supplier_payments.view');
            Route::post('supplier-payments/{payment}/reverse', [SupplierPaymentController::class, 'reverse'])->middleware('finance.permission:finance.supplier_payments.reverse');
            Route::get('daily-closing', [DailyClosingController::class, 'preview'])->middleware('finance.permission:finance.daily_closing.view');
            Route::get('daily-closings', [DailyClosingController::class, 'index'])->middleware('finance.permission:finance.daily_closing.view');
            Route::get('daily-closings/{closing}', [DailyClosingController::class, 'show'])->middleware('finance.permission:finance.daily_closing.view');
            Route::patch('daily-closings/{closing}', [DailyClosingController::class, 'update'])->middleware('finance.permission:finance.daily_closing.manage');
            Route::post('daily-closings/{closing}/close', [DailyClosingController::class, 'close'])->middleware('finance.permission:finance.daily_closing.close');
            Route::get('accounting-periods', [AccountingPeriodController::class, 'index'])->middleware('finance.permission:finance.periods.view');
            Route::post('accounting-periods', [AccountingPeriodController::class, 'store'])->middleware('finance.permission:finance.periods.manage');
            Route::get('accounting-periods/{period}', [AccountingPeriodController::class, 'show'])->middleware('finance.permission:finance.periods.view');
            Route::patch('accounting-periods/{period}', [AccountingPeriodController::class, 'update'])->middleware('finance.permission:finance.periods.manage');
            Route::post('accounting-periods/{period}/close', [AccountingPeriodController::class, 'close'])->middleware('finance.permission:finance.periods.close');
            Route::post('accounting-periods/{period}/lock', [AccountingPeriodController::class, 'lock'])->middleware('finance.permission:finance.periods.lock');
        });
    });
});
