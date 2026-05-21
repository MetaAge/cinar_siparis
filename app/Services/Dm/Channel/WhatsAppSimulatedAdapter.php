<?php

namespace App\Services\Dm\Channel;

class WhatsAppSimulatedAdapter implements DmChannelAdapterInterface
{
    public function normalize(array $payload): array
    {
        $payload['channel'] = $payload['channel'] ?? 'whatsapp_simulated';
        return $payload;
    }
}
