<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Order;


class ReportController extends Controller
{
    //
    public function summary(Request $request)
{
    $start = $request->start;
    $end = $request->end;

    return [
        'total_orders' => Order::whereBetween('created_at', [$start, $end])->count(),
        'total_revenue' => Order::whereBetween('created_at', [$start, $end])->sum('order_total'),
        'total_deposit' => Order::whereBetween('created_at', [$start, $end])->sum('deposit_amount'),
        'total_remaining' => Order::whereBetween('created_at', [$start, $end])->sum('remaining_amount'),
    ];
}
}
