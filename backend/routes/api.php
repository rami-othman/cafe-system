<?php

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
