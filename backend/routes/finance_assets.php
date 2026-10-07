<?php

use App\Http\Controllers\Api\FixedAssetController as A;
use App\Http\Controllers\Api\PartnerController as P;
use Illuminate\Support\Facades\Route;

/*
 * Fixed assets + partners/investors. Included inside the finance prefix group of routes/api.php
 * (api.token, password.changed, branch.access already applied).
 */

Route::prefix('assets')->group(function (): void {
    Route::get('settings', [A::class, 'settings'])->middleware('finance.permission:finance.assets.view');
    Route::put('settings', [A::class, 'saveSettings'])->middleware('finance.permission:finance.assets.manage');
    Route::get('categories', [A::class, 'categories'])->middleware('finance.permission:finance.assets.view');
    Route::post('categories', [A::class, 'storeCategory'])->middleware('finance.permission:finance.assets.manage');
    Route::post('categories/seed-from-chart', [A::class, 'seedCategories'])->middleware('finance.permission:finance.assets.manage');
    Route::patch('categories/{category}', [A::class, 'updateCategory'])->middleware('finance.permission:finance.assets.manage');
    Route::delete('categories/{category}', [A::class, 'deleteCategory'])->middleware('finance.permission:finance.assets.manage');
    Route::get('locations', [A::class, 'locations'])->middleware('finance.permission:finance.assets.view');
    Route::post('locations', [A::class, 'storeLocation'])->middleware('finance.permission:finance.assets.manage');
    Route::patch('locations/{location}', [A::class, 'updateLocation'])->middleware('finance.permission:finance.assets.manage');

    Route::get('depreciation-runs', [A::class, 'runs'])->middleware('finance.permission:finance.assets.view');
    Route::post('depreciation-runs/preview', [A::class, 'previewRun'])->middleware('finance.permission:finance.assets.view');
    Route::post('depreciation-runs', [A::class, 'storeRun'])->middleware('finance.permission:finance.assets.depreciate');
    Route::get('depreciation-runs/{run}', [A::class, 'showRun'])->middleware('finance.permission:finance.assets.view');
    Route::post('depreciation-runs/{run}/reverse', [A::class, 'reverseRun'])->middleware('finance.permission:finance.assets.depreciate');

    Route::get('counts', [A::class, 'counts'])->middleware('finance.permission:finance.assets.view');
    Route::post('counts', [A::class, 'startCount'])->middleware('finance.permission:finance.assets.manage');
    Route::get('counts/{count}', [A::class, 'showCount'])->whereNumber('count')->middleware('finance.permission:finance.assets.view');
    Route::post('counts/{count}/scan', [A::class, 'scanCount'])->whereNumber('count')->middleware('finance.permission:finance.assets.manage');
    Route::patch('counts/{count}/lines/{line}', [A::class, 'updateCountLine'])->whereNumber('count')->whereNumber('line')->middleware('finance.permission:finance.assets.manage');
    Route::post('counts/{count}/close', [A::class, 'closeCount'])->whereNumber('count')->middleware('finance.permission:finance.assets.manage');
    Route::post('counts/{count}/cancel', [A::class, 'cancelCount'])->whereNumber('count')->middleware('finance.permission:finance.assets.manage');

    Route::get('reports/alerts', [A::class, 'alerts'])->middleware('finance.permission:finance.assets.view');
    Route::get('reports/operations', [A::class, 'operations'])->middleware('finance.permission:finance.assets.view');

    Route::get('/', [A::class, 'index'])->middleware('finance.permission:finance.assets.view');
    Route::post('/', [A::class, 'store'])->middleware('finance.permission:finance.assets.manage');
    Route::get('{asset}', [A::class, 'show'])->whereNumber('asset')->middleware('finance.permission:finance.assets.view');
    Route::patch('{asset}', [A::class, 'update'])->whereNumber('asset')->middleware('finance.permission:finance.assets.manage');
    Route::delete('{asset}', [A::class, 'destroy'])->whereNumber('asset')->middleware('finance.permission:finance.assets.manage');
    Route::get('{asset}/schedule', [A::class, 'schedule'])->whereNumber('asset')->middleware('finance.permission:finance.assets.view');
    Route::post('{asset}/activate', [A::class, 'activate'])->whereNumber('asset')->middleware('finance.permission:finance.assets.manage');
    Route::post('{asset}/additions', [A::class, 'addition'])->whereNumber('asset')->middleware('finance.permission:finance.assets.manage');
    Route::post('{asset}/maintenance', [A::class, 'maintenance'])->whereNumber('asset')->middleware('finance.permission:finance.assets.manage');
    Route::post('{asset}/expenses', [A::class, 'expense'])->whereNumber('asset')->middleware('finance.permission:finance.assets.manage');
    Route::post('{asset}/disposals', [A::class, 'disposal'])->whereNumber('asset')->middleware('finance.permission:finance.assets.manage');
    Route::post('{asset}/transfers', [A::class, 'transfer'])->whereNumber('asset')->middleware('finance.permission:finance.assets.manage');
    Route::post('{asset}/transactions/{transaction}/reverse', [A::class, 'reverseTransaction'])->whereNumber('asset')->middleware('finance.permission:finance.assets.manage');
});

Route::prefix('partners')->group(function (): void {
    Route::get('/', [P::class, 'index'])->middleware('finance.permission:finance.partners.view');
    Route::post('/', [P::class, 'store'])->middleware('finance.permission:finance.partners.manage');
    Route::get('portal', [P::class, 'portal'])->middleware('finance.permission:finance.partners.portal');
    Route::get('linkable-users', [P::class, 'linkableUsers'])->middleware('finance.permission:finance.partners.manage');
    Route::get('overview', [P::class, 'overview'])->middleware('finance.permission:finance.partners.view');
    Route::get('transactions', [P::class, 'transactions'])->middleware('finance.permission:finance.partners.view');
    Route::post('transactions/{transaction}/reverse', [P::class, 'reverseTransaction'])->middleware('finance.permission:finance.partners.manage');
    Route::get('branches/{branch}/ownership', [P::class, 'ownership'])->middleware('finance.permission:finance.partners.view');
    Route::put('branches/{branch}/ownership', [P::class, 'setOwnership'])->middleware('finance.permission:finance.partners.manage');
    Route::put('branches/{branch}/settings', [P::class, 'saveSettings'])->middleware('finance.permission:finance.partners.manage');
    Route::get('overhead', [P::class, 'overheadList'])->middleware('finance.permission:finance.partners.view');
    Route::post('overhead/preview', [P::class, 'overheadPreview'])->middleware('finance.permission:finance.partners.view');
    Route::post('overhead', [P::class, 'overheadStore'])->middleware('finance.permission:finance.partners.distribute');
    Route::get('overhead/{allocation}', [P::class, 'overheadShow'])->whereNumber('allocation')->middleware('finance.permission:finance.partners.view');
    Route::post('overhead/{allocation}/reverse', [P::class, 'overheadReverse'])->whereNumber('allocation')->middleware('finance.permission:finance.partners.distribute');
    Route::get('distributions', [P::class, 'distributions'])->middleware('finance.permission:finance.partners.view');
    Route::post('distributions/preview', [P::class, 'previewDistribution'])->middleware('finance.permission:finance.partners.view');
    Route::post('distributions', [P::class, 'storeDistribution'])->middleware('finance.permission:finance.partners.distribute');
    Route::get('distributions/{distribution}', [P::class, 'showDistribution'])->middleware('finance.permission:finance.partners.view');
    Route::post('distributions/{distribution}/reverse', [P::class, 'reverseDistribution'])->middleware('finance.permission:finance.partners.distribute');
    Route::patch('{partner}', [P::class, 'update'])->whereNumber('partner')->middleware('finance.permission:finance.partners.manage');
    Route::post('{partner}/transactions', [P::class, 'storeTransaction'])->whereNumber('partner')->middleware('finance.permission:finance.partners.manage');
    Route::get('{partner}/statement', [P::class, 'statement'])->whereNumber('partner')->middleware('finance.permission:finance.partners.view');
});
