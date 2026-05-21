<?php

namespace App\Enums;

enum OrderStatus: string
{
    case PENDING = 'pending';
    case PREPARING = 'preparing';
    case READY = 'ready';
    case PAID = 'paid';
    case DELIVERED = 'delivered';

    // İnsan okuyabilir etiket
    public function label(): string
    {
        return match ($this) {
            self::PENDING => 'Bekliyor',
            self::PREPARING => 'Hazırlanıyor',
            self::READY => 'Hazır',
            self::PAID => "Ödendi",
            self::DELIVERED => 'Teslim Edildi',
        };
    }

    // Flutter için renk anahtarı
    public function color(): string
    {
        return match ($this) {
            self::PENDING => 'grey',
            self::PREPARING => 'orange',
            self::READY => 'green',
            self::PAID => "green",
            self::DELIVERED => 'blue',
        };
    }
}