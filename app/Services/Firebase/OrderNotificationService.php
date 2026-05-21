<?php

namespace App\Services\Firebase;

use App\Models\Order;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;

class OrderNotificationService
{
    public static function newOrder(Order $order): void
    {
        $messaging = app('firebase.messaging');

        $roles = ['cashier', 'production', 'admin'];

        foreach ($roles as $role) {

            $message = CloudMessage::withTarget('topic', "role_{$role}")
                ->withNotification(
                    Notification::create(
                        '🧁 Yeni Sipariş',
                        "#{$order->id} - {$order->customer_name}"
                    )
                )
                ->withData([
                    'type' => 'new_order',
                    'order_id' => (string) $order->id,
                    'role' => $role,
                ])
                ->withApnsConfig([
                    'payload' => [
                        'aps' => [
                            'sound' => 'default',
                            'badge' => 1,
                        ],
                    ],
                ]);

            $messaging->send($message);
        }
    }
    public static function completedOrder(Order $order): void
    {
        $messaging = app('firebase.messaging');

        $roles = ['cashier', 'production', 'admin'];

        foreach ($roles as $role) {

            $message = CloudMessage::withTarget('topic', "role_{$role}")
                ->withNotification(
                    Notification::create(
                        '✅ Sipariş Tamamlandı',
                        "#{$order->id} - {$order->customer_name}"
                    )
                )
                ->withData([
                    'type' => 'completed_order',
                    'order_id' => (string) $order->id,
                    'role' => $role,
                ])
                ->withApnsConfig([
                    'payload' => [
                        'aps' => [
                            'sound' => 'default',
                            'badge' => 1,
                        ],
                    ],
                ]);

            $messaging->send($message);
        }
    }
    public static function updatedOrder(Order $order): void
    {
        $messaging = app('firebase.messaging');

        $roles = ['cashier', 'production', 'admin'];

        foreach ($roles as $role) {

            $message = CloudMessage::withTarget('topic', "role_{$role}")
                ->withNotification(
                    Notification::create(
                        '✍️ Sipariş Güncellendi',
                        "#{$order->id} - {$order->customer_name}"
                    )
                )
                ->withData([
                    'type' => 'updated_order',
                    'order_id' => (string) $order->id,
                    'role' => $role,
                ])
                ->withApnsConfig([
                    'payload' => [
                        'aps' => [
                            'sound' => 'default',
                            'badge' => 1,
                        ],
                    ],
                ]);

            $messaging->send($message);
        }
    }
    public static function readyOrder(Order $order): void
    {
        $messaging = app('firebase.messaging');

        $roles = ['cashier', 'production', 'admin'];

        foreach ($roles as $role) {

            $message = CloudMessage::withTarget('topic', "role_{$role}")
                ->withNotification(
                    Notification::create(
                        '👌 Sipariş Teslimata Hazır',
                        "#{$order->id} - {$order->customer_name}"
                    )
                )
                ->withData([
                    'type' => 'ready_order',
                    'order_id' => (string) $order->id,
                    'role' => $role,
                ])
                ->withApnsConfig([
                    'payload' => [
                        'aps' => [
                            'sound' => 'default',
                            'badge' => 1,
                        ],
                    ],
                ]);

            $messaging->send($message);
        }
    }
}