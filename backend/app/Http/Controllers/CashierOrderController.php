<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class CashierOrderController extends Controller
{
    public function store(Request $request)
    {
        $validated = $request->validate([
            'customer_name'     => 'required|string|max:255',
            'customer_phone'    => 'required|string|max:50',
            'order_details'     => 'required|string',
            'total_amount'      => 'required|numeric|min:0',
            'deposit_amount'    => 'nullable|numeric|min:0',
            'delivery_datetime' => 'required|date', // "2026-01-08 17:00:00"
            'image_url'         => 'nullable|string|max:2000',
        ]);

        $deposit = (float) ($validated['deposit_amount'] ?? 0);
        $total   = (float) $validated['total_amount'];

        if ($deposit > $total) {
            return response()->json([
                'message' => 'Kapora toplam tutardan büyük olamaz'
            ], 422);
        }

        $imageUrl = $validated['image_url'] ?? null;

        // Unsplash normalize (tek sefer)
        if ($imageUrl && str_contains($imageUrl, 'images.unsplash.com') && !str_contains($imageUrl, '?')) {
            $imageUrl .= '?w=800&q=80&auto=format';
        }

        $order = DB::transaction(function () use ($validated, $deposit, $total, $imageUrl, $request) {
            $remaining = $total - $deposit;

            return Order::create([
                "order_no" => 'CNR-' . now()->timestamp,
                'customer_name'     => $validated['customer_name'],
                'customer_phone'    => $validated['customer_phone'],
                'order_details'     => $validated['order_details'],
                'order_total'      => $total,
                'deposit_amount'    => $deposit,
                'remaining_amount'  => $remaining,
                'delivery_datetime' => $validated['delivery_datetime'],
                'status'            => 'preparing', // istersen 'preparing' yap
                'image_url'         => $imageUrl,
                'created_by'        => $request->user()->id,
            ]);
        });

        return response()->json([
            'message' => 'Sipariş oluşturuldu',
            'order' => $order
        ], 201);
    }

    // Opsiyonel: Dosya upload (Flutter Web file_picker ile)
    public function uploadImage(Request $request)
    {
        $request->validate([
            'image' => 'required|file|mimes:jpg,jpeg,png,webp|max:5120',
        ]);

        $path = $request->file('image')->store('orders', 'public');
        $url = asset('storage/' . $path);

        return response()->json([
            'message' => 'Yüklendi',
            'image_url' => $url
        ]);
    }
}