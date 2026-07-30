<?php

use App\Http\Controllers\Api\Admin\Catalog\CatalogReferenceController;
use App\Http\Controllers\Api\Admin\Catalog\ModifierCatalogController;
use App\Http\Controllers\Api\Admin\Catalog\ProductCatalogController;
use App\Http\Controllers\Api\BranchController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\DailyReportController;
use App\Http\Controllers\Api\DiscountController;
use App\Http\Controllers\Api\MenuController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\PosOrderController;
use App\Http\Controllers\Api\PosStateController;
use App\Http\Controllers\Api\ReceiptController;
use App\Http\Controllers\Api\RefundController;
use App\Http\Controllers\Api\ShiftController;
use App\Http\Controllers\Api\TableController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
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
    });

    Route::get('branches', [BranchController::class, 'index']);
    Route::get('reports/daily', [DailyReportController::class, 'show']);

    Route::get('shifts/current', [ShiftController::class, 'current']);
    Route::post('shifts/current', [ShiftController::class, 'open']);
    Route::post('shifts/{shift}/close', [ShiftController::class, 'close']);

    Route::get('menu/categories', [MenuController::class, 'categories']);
    Route::get('menu/products', [MenuController::class, 'products']);
    Route::get('menu/products/{product}', [MenuController::class, 'product']);

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
