<?php

use App\Http\Controllers\Api\BranchController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\DailyReportController;
use App\Http\Controllers\Api\DiscountController;
use App\Http\Controllers\Api\FinancialAccountController;
use App\Http\Controllers\Api\FinancialSetupStatusController;
use App\Http\Controllers\Api\JournalEntryController;
use App\Http\Controllers\Api\InventoryBalanceController;
use App\Http\Controllers\Api\InventoryItemController;
use App\Http\Controllers\Api\InventoryItemUnitConversionController;
use App\Http\Controllers\Api\MenuController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\PosOrderController;
use App\Http\Controllers\Api\PosStateController;
use App\Http\Controllers\Api\ReceiptController;
use App\Http\Controllers\Api\ReportsOverviewController;
use App\Http\Controllers\Api\RefundController;
use App\Http\Controllers\Api\ShiftController;
use App\Http\Controllers\Api\TableController;
use App\Http\Controllers\Api\StockCountController;
use App\Http\Controllers\Api\StockMovementController;
use App\Http\Controllers\Api\WarehouseController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('branches', [BranchController::class, 'index']);
    Route::get('reports/daily', [DailyReportController::class, 'show']);
    Route::get('reports/overview', [ReportsOverviewController::class, 'show']);

    Route::get('shifts/current', [ShiftController::class, 'current']);
    Route::post('shifts/current', [ShiftController::class, 'open']);
    Route::post('shifts/{shift}/close', [ShiftController::class, 'close']);

    Route::get('menu/categories', [MenuController::class, 'categories']);
    Route::get('menu/products', [MenuController::class, 'products']);
    Route::get('menu/products/{product}', [MenuController::class, 'product']);

    Route::get('customers', [CustomerController::class, 'index']);
    Route::get('tables', [TableController::class, 'index']);
    Route::get('warehouses', [WarehouseController::class, 'index']);
    Route::post('warehouses', [WarehouseController::class, 'store']);
    Route::patch('warehouses/{warehouse}', [WarehouseController::class, 'update']);
    Route::patch('warehouses/{warehouse}/status', [WarehouseController::class, 'status']);

    Route::prefix('inventory')->group(function (): void {
        Route::get('dashboard', [InventoryBalanceController::class, 'dashboard']);
        Route::get('balances', [InventoryBalanceController::class, 'index']);
        Route::get('units', [InventoryItemController::class, 'units']);
        Route::get('conversion-items', [InventoryItemController::class, 'conversionItems']);
        Route::get('items', [InventoryItemController::class, 'index']);
        Route::post('items', [InventoryItemController::class, 'store']);
        Route::get('items/{item}', [InventoryItemController::class, 'show']);
        Route::patch('items/{item}', [InventoryItemController::class, 'update']);
        Route::patch('items/{item}/status', [InventoryItemController::class, 'status']);
        Route::get('items/{item}/stock', [InventoryItemController::class, 'stock']);
        Route::get('items/{item}/movements', [InventoryItemController::class, 'movements']);
        Route::get('items/{item}/unit-conversions', [InventoryItemUnitConversionController::class, 'index']);
        Route::post('items/{item}/unit-conversions', [InventoryItemUnitConversionController::class, 'store']);
        Route::patch('items/{item}/unit-conversions/{conversion}', [InventoryItemUnitConversionController::class, 'update']);
        Route::get('movements', [StockMovementController::class, 'index']);
        Route::post('movements', [StockMovementController::class, 'store']);
        Route::get('movements/{movement}', [StockMovementController::class, 'show']);
        Route::get('counts', [StockCountController::class, 'index']);
        Route::post('counts', [StockCountController::class, 'store']);
        Route::get('counts/{count}', [StockCountController::class, 'show']);
        Route::put('counts/{count}/lines', [StockCountController::class, 'line']);
        Route::post('counts/{count}/{action}', [StockCountController::class, 'action']);
    });

    Route::prefix('finance')->group(function (): void {
        Route::get('setup-status', [FinancialSetupStatusController::class, 'show']);
        Route::get('accounts', [FinancialAccountController::class, 'index']);
        Route::post('accounts', [FinancialAccountController::class, 'store']);
        Route::patch('accounts/{account}', [FinancialAccountController::class, 'update']);
        Route::patch('accounts/{account}/status', [FinancialAccountController::class, 'status']);
        Route::get('journal-entries', [JournalEntryController::class, 'index']);
        Route::post('journal-entries', [JournalEntryController::class, 'store']);
        Route::get('journal-entries/{entry}', [JournalEntryController::class, 'show']);
        Route::post('journal-entries/{entry}/post', [JournalEntryController::class, 'post']);
    });
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
