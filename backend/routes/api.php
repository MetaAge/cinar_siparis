<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\ProductionOrderController;
use App\Http\Controllers\OrderController;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\CashierController;
use App\Http\Controllers\CashierOrderController;
use App\Http\Controllers\ImageProxyController;
use App\Http\Controllers\AdminDashboardController;
use App\Http\Controllers\AdminOrderController;

Route::post('/login', [AuthController::class, 'login']);

Route::middleware(['auth:sanctum', 'role:production,admin,cashier'])->group(function () {

    Route::post('/logout', [AuthController::class, 'logout']);

    Route::get('/production/orders/today', [ProductionOrderController::class, 'today']);
    Route::get('/production/orders/late', [ProductionOrderController::class, 'late']);
    Route::get('/production/orders/upcoming', [ProductionOrderController::class, 'upcoming']);

    Route::middleware(['role:admin'])->group(function () {
    Route::get('/admin/dashboard', [AdminDashboardController::class, 'index']);
    Route::get('/admin/orders', [AdminOrderController::class, 'index']);
    Route::get('/admin/orders/active', [AdminOrderController::class, 'active']);
    Route::get('/admin/orders/history', [AdminOrderController::class, 'history']);
    Route::get('/admin/dashboard/revenue-range', [AdminDashboardController::class, 'revenueByRange']);
    });


    Route::middleware('role:cashier')->group(function () {

        Route::get('/cashier/orders', [CashierController::class, 'index']);

        Route::patch(
            '/cashier/orders/{order}/paid',
            [CashierController::class, 'markPaid']
        );

        // ✅ Yeni sipariş oluştur
        Route::post('/cashier/orders', [CashierOrderController::class, 'store']);

        // ✅ Opsiyonel: görsel upload
        Route::post('/cashier/orders/upload-image', [CashierOrderController::class, 'uploadImage']);

        Route::get('/cashier/orders/history', [CashierController::class, 'history']);
    });
    

    Route::middleware(['auth:sanctum', 'role:cashier,admin,production'])->group(function () {
            Route::post('/orders', [OrderController::class, 'store']);
        });

        Route::middleware(['auth:sanctum', 'role:production,admin'])->group(function () {
            Route::patch('/orders/{id}/ready', [OrderController::class, 'markAsReady']);
        });
});
