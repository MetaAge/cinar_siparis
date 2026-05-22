<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\Order;
use Illuminate\Http\Request;
use App\Services\Firebase\OrderNotificationService;

class CashierController extends Controller
{
    /**
     * Kasiyerin göreceği siparişler
     * (Ödeme alınmamış olanlar)
     */
    public function index()
    {
        return Order::whereIn('status', [
                'pending',
                'preparing',
                'ready',
            ])
            ->orderBy('delivery_datetime')
            ->get();
    }

    /**
     * Ödeme alındı
     */
    public function markPaid(Order $order)
    {
        if (in_array($order->status, ['paid', 'delivered'])) {
            return response()->json([
                'message' => 'Bu sipariş zaten tamamlanmış'
            ], 400);
        }

        $order->update([
            'remaining_amount' => 0,
            'status' => 'paid',
        ]);
        // 🔔 BİLDİRİM
        //OrderNotificationService::completedOrder($order);

        return response()->json([
            'message' => 'Sipariş tamamlandı',
            'order' => $order
        ]);
    }

    public function history(Request $request)
{
    $query = Order::query()
        ->whereIn('status', ['paid', 'delivered'])
        ->orderByDesc('updated_at');

    // Opsiyonel tarih filtresi
    if ($request->filled('from')) {
        $query->whereDate('updated_at', '>=', $request->from);
    }

    if ($request->filled('to')) {
        $query->whereDate('updated_at', '<=', $request->to);
    }

    return $query->get();
}
}