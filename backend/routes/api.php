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
use App\Http\Controllers\Api\BranchController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\DailyReportController;
use App\Http\Controllers\Api\DiscountController;
use App\Http\Controllers\Api\MenuController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\PosMenuSyncController;
use App\Http\Controllers\Api\PosOrderController;
use App\Http\Controllers\Api\PosStateController;
use App\Http\Controllers\Api\ReceiptController;
use App\Http\Controllers\Api\RefundController;
use App\Http\Controllers\Api\ShiftController;
use App\Http\Controllers\Api\TableController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('product-images/{tenant}/{filename}', [ProductCatalogController::class, 'showProductImage'])
        ->whereNumber('tenant');

    Route::prefix('admin/catalog')->group(function (): void {
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

    Route::prefix('admin')->group(function (): void {
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
    Route::get('reports/daily', [DailyReportController::class, 'show']);

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
