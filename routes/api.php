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
use App\Http\Controllers\DeviceTokenController;
use App\Http\Controllers\DmWebhookController;
use App\Http\Controllers\AdminDmLeadController;
use App\Http\Controllers\AdminDmLeadOrderDraftController;
use App\Http\Controllers\WhatsAppWebhookController;
use Illuminate\Http\Request;

Route::options('/{any}', function (Request $request) {
    return response()->json([], 204);
})->where('any', '.*');

Route::post('/login', [AuthController::class, 'login']);
Route::post('/dm/webhook', [DmWebhookController::class, 'store']);
Route::get('/dm/webhook/whatsapp', [WhatsAppWebhookController::class, 'verify']);
Route::post('/dm/webhook/whatsapp', [WhatsAppWebhookController::class, 'receive']);

Route::middleware(['auth:sanctum', 'role:production,admin,cashier'])->group(function () {
    

    Route::post('/device-tokens', [DeviceTokenController::class, 'store']);
    Route::post('/logout', [AuthController::class, 'logout']);

    Route::get('/production/orders/today', [ProductionOrderController::class, 'today']);
    Route::get('/production/orders/late', [ProductionOrderController::class, 'late']);
    Route::get('/production/orders/upcoming', [ProductionOrderController::class, 'upcoming']);
    Route::get('/production/orders/history', [ProductionOrderController::class, 'history']);

    Route::middleware(['role:admin'])->group(function () {
    Route::get('/admin/dashboard', [AdminDashboardController::class, 'index']);
    Route::get('/admin/orders', [AdminOrderController::class, 'index']);
    Route::get('/admin/orders/active', [AdminOrderController::class, 'active']);
    Route::get('/admin/orders/history', [AdminOrderController::class, 'history']);
    Route::get('/admin/dashboard/revenue-range', [AdminDashboardController::class, 'revenueByRange']);
    Route::get('/admin/dm-leads', [AdminDmLeadController::class, 'index']);
    Route::get('/admin/dm-leads/{id}', [AdminDmLeadController::class, 'show']);
    Route::patch('/admin/dm-leads/{id}/status', [AdminDmLeadController::class, 'updateStatus']);
    Route::post('/admin/dm-leads/{id}/notes', [AdminDmLeadController::class, 'addNote']);
    Route::post('/admin/dm-leads/{id}/suggest-reply', [AdminDmLeadController::class, 'suggestReply']);
    Route::post('/admin/dm-leads/{id}/create-order-draft', [AdminDmLeadOrderDraftController::class, 'store']);
    });


    Route::middleware('role:cashier,admin')->group(function () {

        Route::get('/cashier/orders', [CashierController::class, 'index']);
        Route::patch('/cashier/orders/{order}', [CashierOrderController::class, 'update']);
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
