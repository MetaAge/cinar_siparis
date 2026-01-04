<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Models\Order;

class OrderStatusService
{
    public static function canChange(
        Order $order,
        OrderStatus $newStatus,
        string $role
    ): bool {

        return match ($order->status) {
            OrderStatus::PENDING =>
                in_array($newStatus, [OrderStatus::PREPARING]) &&
                in_array($role, ['production', 'admin']),

            OrderStatus::PREPARING =>
                in_array($newStatus, [OrderStatus::READY]) &&
                in_array($role, ['production', 'admin']),

            OrderStatus::READY =>
                in_array($newStatus, [OrderStatus::DELIVERED]) &&
                in_array($role, ['cashier', 'admin']),

            default => false,
        };
    }
}