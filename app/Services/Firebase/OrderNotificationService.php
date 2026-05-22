<?php

namespace App\Services\Firebase;

use App\Models\Order;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Illuminate\Support\Facades\Log;

class OrderNotificationService
{
    public static function newOrder(Order $order): void
    {
        self::sendToAllRoles(
            '🧁 Yeni Sipariş',
            "#{$order->id} - {$order->customer_name}",
            'new_order',
            $order
        );
    }

    public static function completedOrder(Order $order): void
    {
        self::sendToAllRoles(
            '✅ Sipariş Tamamlandı',
            "#{$order->id} - {$order->customer_name}",
            'completed_order',
            $order
        );
    }

    public static function updatedOrder(Order $order): void
    {
        self::sendToAllRoles(
            '✍️ Sipariş Güncellendi',
            "#{$order->id} - {$order->customer_name}",
            'updated_order',
            $order
        );
    }

    public static function readyOrder(Order $order): void
    {
        self::sendToAllRoles(
            '👌 Sipariş Teslimata Hazır',
            "#{$order->id} - {$order->customer_name}",
            'ready_order',
            $order
        );
    }

    /**
     * Tüm rollere bildirim gönder.
     * Firebase hatası olursa logla ama HTTP yanıtını BLOKLAMA.
     */
    private static function sendToAllRoles(
        string $title,
        string $body,
        string $type,
        Order $order
    ): void {
        try {
            $messaging = app('firebase.messaging');
        } catch (\Throwable $e) {
            Log::error("FCM messaging servisi başlatılamadı: {$e->getMessage()}");
            return;
        }

        $roles = ['cashier', 'production', 'admin'];

        foreach ($roles as $role) {
            try {
                $message = CloudMessage::withTarget('topic', "role_{$role}")
                    ->withNotification(
                        Notification::create($title, $body)
                    )
                    ->withData([
                        'type' => $type,
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
            } catch (\Throwable $e) {
                Log::error("FCM bildirim gönderilemedi [role={$role}, type={$type}, order={$order->id}]: {$e->getMessage()}");
            }
        }
    }
}