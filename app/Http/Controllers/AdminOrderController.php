<?php

namespace App\Http\Controllers;

use App\Models\Order;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class AdminOrderController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $type = $request->query('type');
        $now = Carbon::now();

        $query = Order::query();

        if ($type === 'late') {
            // 🔴 Geciken
            $query->where('delivery_datetime', '<', $now)
                  ->whereNotIn('status', ['paid']);
        }

        if ($type === 'soon') {
            // 🟠 1 saat içinde
            $query->whereBetween('delivery_datetime', [
                    $now,
                    $now->copy()->addHour(),
                ])
                ->whereNotIn('status', ['paid']);
        }

        if ($type === 'no_deposit') {
            // 🟡 Kapora yok
            $query->where(function ($q) {
                    $q->whereNull('deposit_amount')
                      ->orWhere('deposit_amount', 0);
                })
                ->whereNotIn('status', ['paid']);
        }

        $orders = $query
            ->orderBy('delivery_datetime')
            ->get()
            ->map(function ($o) {
                return [
                    'id' => $o->id,
                    'customer_name' => $o->customer_name,
                    'customer_phone' => $o->customer_phone,
                    'details' => $o->details,
                    'delivery_datetime' => $o->delivery_datetime?->format('Y-m-d H:i'),
                    'status' => $o->status,
                    'order_total' => $o->order_total,
                    'deposit_amount' => $o->deposit_amount,
                    'remaining_amount' => $o->order_total - ($o->deposit_amount ?? 0),
                ];
            });

        return response()->json([
            'type' => $type,
            'count' => $orders->count(),
            'orders' => $orders,
        ]);
    }
    public function active(Request $request): JsonResponse
    {
        $perPage = (int) $request->query('per_page', 20);
        $perPage = max(5, min($perPage, 100)); // 5-100 arası güvenli

        $p = Order::where('status', '!=', 'paid')
            ->orderBy('delivery_datetime')
            ->paginate($perPage);

        return response()->json($this->paginateResponse($p));
    }

    public function history(Request $request): JsonResponse
    {
        $perPage = (int) $request->query('per_page', 20);
        $perPage = max(5, min($perPage, 100));

        $p = Order::where('status', 'paid')
            ->orderByDesc('delivery_datetime')
            ->paginate($perPage);

        return response()->json($this->paginateResponse($p));
    }

    private function paginateResponse($p): array
    {
        return [
            'data' => $p->getCollection()->map(fn ($o) => [
                'id' => $o->id,
                'customer_name' => $o->customer_name,
                'customer_phone' => $o->customer_phone,
                'details' => $o->details,
                'status' => $o->status,
                'order_total' => (int) $o->order_total,
                'deposit_amount' => $o->deposit_amount === null ? null : (int) $o->deposit_amount,
                'remaining_amount' => (int) $o->order_total - (int) ($o->deposit_amount ?? 0),
                'delivery_datetime' => optional($o->delivery_datetime)->format('Y-m-d H:i'),
                'image_url' => $o->image_url, // varsa
            ])->values(),

            'meta' => [
                'current_page' => $p->currentPage(),
                'last_page' => $p->lastPage(),
                'per_page' => $p->perPage(),
                'total' => $p->total(),
            ],

            'links' => [
                'next' => $p->nextPageUrl(),
                'prev' => $p->previousPageUrl(),
            ],
        ];
    }
}