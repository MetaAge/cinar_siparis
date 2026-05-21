<?php

namespace App\Services\Dm\Channel;

class DmChannelAdapterResolver
{
    public function resolve(string $channel): DmChannelAdapterInterface
    {
        return match ($channel) {
            'instagram_dm' => new InstagramDmAdapter(),
            default => new WhatsAppSimulatedAdapter(),
        };
    }
}
