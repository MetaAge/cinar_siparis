<?php

namespace App\Http\Controllers;

use App\Models\DmLead;
use App\Models\Order;
use Illuminate\Http\JsonResponse;

class AdminDmLeadOrderDraftController extends Controller
{
    public function store(int $id): JsonResponse
    {
        $lead = DmLead::with('customer')->findOrFail($id);
        if ($lead->status !== 'approved') {
            return response()->json(['ok' => false, 'message' => 'Lead must be approved first.'], 422);
        }

        $data = (array) ($lead->collected_data ?? []);
        $details = 'DM Lead #'.$lead->id.' | Tür: '.($lead->lead_type ?? '-')."\n".json_encode($data, JSON_UNESCAPED_UNICODE);

        $order = Order::create([
            'order_no' => 'DM-'.now()->timestamp,
            'customer_name' => $lead->customer->name ?? 'DM Müşteri',
            'customer_phone' => $lead->customer->phone ?? '-',
            'order_details' => $details,
            'order_total' => 0,
            'deposit_amount' => 0,
            'remaining_amount' => 0,
            'delivery_datetime' => now()->addDay(),
            'status' => 'preparing',
            'created_by' => auth()->id() ?? 1,
        ]);

        return response()->json(['ok' => true, 'order' => $order], 201);
    }
}
