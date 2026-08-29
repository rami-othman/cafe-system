<?php

use App\Http\Controllers\Api\BranchController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BarCheckController;
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
use App\Http\Controllers\Api\WarehouseTransferController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::post('auth/login', [AuthController::class, 'login'])->middleware('throttle:6,1');
    Route::middleware('api.token')->group(function (): void {
        Route::get('auth/me', [AuthController::class, 'me']);
        Route::post('auth/logout', [AuthController::class, 'logout']);
    });

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
    Route::middleware('api.token')->group(function (): void {
        Route::get('warehouses', [WarehouseController::class, 'index'])->middleware('inventory.permission:inventory.view');
        Route::post('warehouses', [WarehouseController::class, 'store'])->middleware('inventory.permission:inventory.locations.manage');
        Route::patch('warehouses/{warehouse}', [WarehouseController::class, 'update'])->middleware('inventory.permission:inventory.locations.manage');
        Route::patch('warehouses/{warehouse}/status', [WarehouseController::class, 'status'])->middleware('inventory.permission:inventory.locations.manage');
    });

    Route::prefix('inventory')->middleware('api.token')->group(function (): void {
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
        Route::post('transfers/{transfer}/submit', [WarehouseTransferController::class, 'action'])->defaults('action', 'submit')->middleware('inventory.permission:inventory.transfers.submit');
        Route::post('transfers/{transfer}/approve', [WarehouseTransferController::class, 'action'])->defaults('action', 'approve')->middleware('inventory.permission:inventory.transfers.approve');
        Route::post('transfers/{transfer}/reject', [WarehouseTransferController::class, 'action'])->defaults('action', 'reject')->middleware('inventory.permission:inventory.transfers.approve');
        Route::post('transfers/{transfer}/dispatch', [WarehouseTransferController::class, 'action'])->defaults('action', 'dispatch')->middleware('inventory.permission:inventory.transfers.dispatch');
        Route::post('transfers/{transfer}/close-shortage', [WarehouseTransferController::class, 'action'])->defaults('action', 'close-shortage')->middleware('inventory.permission:inventory.transfers.receive');
        Route::post('transfers/{transfer}/cancel', [WarehouseTransferController::class, 'action'])->defaults('action', 'cancel')->middleware('inventory.permission:inventory.transfers.cancel');
        Route::get('dashboard', [InventoryBalanceController::class, 'dashboard'])->middleware('inventory.permission:inventory.view');
        Route::get('balances', [InventoryBalanceController::class, 'index'])->middleware('inventory.permission:inventory.view');
        Route::get('units', [InventoryItemController::class, 'units'])->middleware('inventory.permission:inventory.view');
        Route::get('conversion-items', [InventoryItemController::class, 'conversionItems'])->middleware('inventory.permission:inventory.view');
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
        Route::get('movements', [StockMovementController::class, 'index'])->middleware('inventory.permission:inventory.view');
        Route::post('movements', [StockMovementController::class, 'store'])->middleware('inventory.permission:inventory.adjustments.create');
        Route::get('movements/{movement}', [StockMovementController::class, 'show'])->middleware('inventory.permission:inventory.view');
        Route::get('counts', [StockCountController::class, 'index'])->middleware('inventory.permission:inventory.counts.view');
        Route::post('counts', [StockCountController::class, 'store'])->middleware('inventory.permission:inventory.counts.create');
        Route::get('counts/{count}', [StockCountController::class, 'show'])->middleware('inventory.permission:inventory.counts.view');
        Route::put('counts/{count}/lines', [StockCountController::class, 'line'])->middleware('inventory.permission:inventory.counts.create');
        Route::post('counts/{count}/lines/{item}/review', [StockCountController::class, 'reviewLine'])->middleware('inventory.permission:inventory.counts.post');
        Route::post('counts/{count}/start', [StockCountController::class, 'action'])->defaults('action', 'start')->middleware('inventory.permission:inventory.counts.create');
        Route::post('counts/{count}/submit', [StockCountController::class, 'action'])->defaults('action', 'submit')->middleware('inventory.permission:inventory.counts.create');
        Route::post('counts/{count}/approve', [StockCountController::class, 'action'])->defaults('action', 'approve')->middleware('inventory.permission:inventory.counts.post');
        Route::post('counts/{count}/post', [StockCountController::class, 'action'])->defaults('action', 'post')->middleware('inventory.permission:inventory.counts.post');
        Route::post('counts/{count}/cancel', [StockCountController::class, 'action'])->defaults('action', 'cancel')->middleware('inventory.permission:inventory.counts.create');
    });

    Route::prefix('finance')->middleware('api.token')->group(function (): void {
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
