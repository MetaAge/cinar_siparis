<?php

namespace App\Http\Controllers;

use App\Models\Order;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Carbon;

class ProductionOrderController extends Controller
{
    // BUGÜN TESLİM
    public function today(): JsonResponse
    {
        $orders = Order::whereDate('delivery_datetime', Carbon::today())
            ->where('status', 'preparing')
            ->orderBy('delivery_datetime')
            ->get();

        return response()->json($orders);
    }

    // GECİKEN
    public function late(): JsonResponse
    {
        $orders = Order::where('delivery_datetime', '<', Carbon::now())
            ->where('status', 'preparing')
            ->orderBy('delivery_datetime')
            ->get();

        return response()->json($orders);
    }

    // YAKLAŞAN (yarın ve sonrası)
    public function upcoming(): JsonResponse
    {
        $orders = Order::where('delivery_datetime', '>', Carbon::today()->endOfDay())
            ->where('status', 'preparing')
            ->orderBy('delivery_datetime')
            ->get();

        return response()->json($orders);
    }
}