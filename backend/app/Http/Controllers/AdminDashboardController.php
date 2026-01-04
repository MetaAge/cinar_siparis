<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\Order;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminDashboardController extends Controller
{
    /**
     * Admin Dashboard özet verileri (NULL-safe)
     */
    public function index(): JsonResponse
    {
        $now = Carbon::now();
        $today = Carbon::today();
        $tomorrow = Carbon::tomorrow();
        $startOfWeek = Carbon::now()->startOfWeek();
        $endOfWeek = Carbon::now()->endOfWeek();

        // ---------------------------
        // 🔴 Geciken siparişler
        // ---------------------------
        $lateOrdersCount = Order::query()
            ->whereNotNull('delivery_datetime')
            ->where('delivery_datetime', '<', $now)
            ->where('status', '!=', 'paid')
            ->count();

        // ---------------------------
        // 🟠 1 saat içinde teslim
        // ---------------------------
        $soonOrdersCount = Order::query()
            ->whereNotNull('delivery_datetime')
            ->whereBetween('delivery_datetime', [$now, $now->copy()->addHour()])
            ->where('status', '!=', 'paid')
            ->count();

        // ---------------------------
        // 🟡 Kapora alınmamış
        // ---------------------------
        $noDepositOrdersCount = Order::query()
            ->where(function ($q) {
                $q->whereNull('deposit_amount')
                  ->orWhere('deposit_amount', 0);
            })
            ->where('status', '!=', 'paid')
            ->count();

        // ---------------------------
        // Bugün (created_at NULL-safe)
        // ---------------------------
        $todayOrders = Order::query()
            ->whereNotNull('created_at')
            ->whereDate('created_at', $today);

        $todayRevenue = (float) (clone $todayOrders)
            ->where('status', 'paid')
            ->sum('order_total');

        $todayOrderCount = (int) (clone $todayOrders)->count();

        // ---------------------------
        // Yarın teslim
        // ---------------------------
        $tomorrowOrderCount = Order::query()
            ->whereNotNull('delivery_datetime')
            ->whereDate('delivery_datetime', $tomorrow)
            ->count();

        // ---------------------------
        // Bu hafta ciro
        // ---------------------------
        $weekRevenue = (float) Order::query()
            ->whereNotNull('created_at')
            ->whereBetween('created_at', [$startOfWeek, $endOfWeek])
            ->where('status', 'paid')
            ->sum('order_total');

        // ---------------------------
        // Son 7 gün ciro (grafik)
        // ---------------------------
        $last7DaysRevenue = [];
        for ($i = 6; $i >= 0; $i--) {
            $date = Carbon::today()->subDays($i);

            $revenue = (float) Order::query()
                ->whereNotNull('created_at')
                ->whereDate('created_at', $date)
                ->where('status', 'paid')
                ->sum('order_total');

            $last7DaysRevenue[] = [
                'date' => $date->format('Y-m-d'),
                'revenue' => $revenue,
            ];
        }

        // ---------------------------
        // Sipariş durum dağılımı
        // ---------------------------
        $statusDistribution = [
            'preparing' => Order::where('status', 'preparing')->count(),
            'ready'     => Order::where('status', 'ready')->count(),
            'paid'      => Order::where('status', 'paid')->count(),
        ];

        return response()->json([
            'today' => [
                'revenue' => $todayRevenue,
                'order_count' => $todayOrderCount,
            ],
            'tomorrow' => [
                'order_count' => $tomorrowOrderCount,
            ],
            'week' => [
                'revenue' => $weekRevenue,
            ],
            'last_7_days_revenue' => $last7DaysRevenue,
            'status_distribution' => $statusDistribution,
            'alerts' => [
                'late_orders' => $lateOrdersCount,
                'soon_orders' => $soonOrdersCount,
                'no_deposit_orders' => $noDepositOrdersCount,
            ],
        ]);
    }

    /**
     * Tarih aralığına göre toplam ciro (NULL-safe)
     */
    public function revenueByRange(Request $request): JsonResponse
    {
        try {
            $request->validate([
                'from' => ['required', 'date'],
                'to'   => ['required', 'date', 'after_or_equal:from'],
            ]);

            $from = Carbon::parse($request->query('from'))->startOfDay();
            $to   = Carbon::parse($request->query('to'))->endOfDay();

            $query = Order::query()
                ->whereNotNull('created_at')
                ->whereBetween('created_at', [$from, $to])
                ->where('status', 'paid')
                ->whereNotNull('order_total');

            $totalRevenue = (float) $query->sum('order_total');
            $orderCount = (int) $query->count();

            return response()->json([
                'from' => $from->toDateString(),
                'to' => $to->toDateString(),
                'total_revenue' => $totalRevenue,
                'order_count' => $orderCount,
            ]);

        } catch (\Throwable $e) {
            return response()->json([
                'message' => 'Revenue range error',
                'error' => $e->getMessage(),
            ], 500);
        }
    }
}