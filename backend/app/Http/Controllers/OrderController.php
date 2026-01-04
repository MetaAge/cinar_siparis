<?php

namespace App\Http\Controllers;

use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Carbon;
use App\Enums\OrderStatus;
use Illuminate\Validation\Rule;

class OrderController extends Controller
{
    /**
     * Yeni sipariş oluştur (Tezgahtar / Test için curl)
     * POST /api/orders
     */
    public function store(Request $request)
{
    $validated = $request->validate([
        'customer_name'     => 'required|string|max:255',
        'customer_phone'    => 'nullable|string|max:50',
        'order_details'     => 'required|string',
        'image_url'         => 'nullable|string',
        'order_total'       => 'nullable|integer|min:0',
        'deposit_amount'    => 'nullable|integer|min:0',
        'delivery_datetime' => 'required|date',
    ]);

    $deposit = $validated['deposit_amount'] ?? 0;
    $total   = $validated['order_total'] ?? null;

    $imageUrl = $validated['image_url'] ?? null;

if ($imageUrl && str_contains($imageUrl, 'images.unsplash.com')) {
    if (!str_contains($imageUrl, '?')) {
        $imageUrl .= '?w=800&q=80&auto=format';
    }
}

    $order = Order::create([
        'order_no'          => 'CNR-' . strtoupper(uniqid()),
        'customer_name'     => $validated['customer_name'],
        'customer_phone'    => $validated['customer_phone'] ?? null,
        'order_details'     => $validated['order_details'],
        'image_url'         => $imageUrl,
        'order_total'       => $total,
        'deposit_amount'    => $deposit,
        'remaining_amount'  => $total !== null ? max($total - $deposit, 0) : null,
        'delivery_datetime' => $validated['delivery_datetime'],
        'status'            => 'preparing',
        'created_by'        => $request->user()->id,
    ]);

    return response()->json($order, 201);
}

    /**
     * Siparişi hazırlandı olarak işaretle (İmalat)
     * PATCH /api/orders/{id}/ready
     */
    public function markAsReady(int $id): JsonResponse
    {
        $order = Order::findOrFail($id);

        if ($order->status === 'ready') {
            return response()->json([
                'message' => 'Sipariş zaten hazır',
            ], 200);
        }

        $order->update([
            'status' => 'ready',
        ]);

        return response()->json([
            'message' => 'Sipariş hazırlandı olarak işaretlendi',
            'order'   => $order,
        ]);
    }
}