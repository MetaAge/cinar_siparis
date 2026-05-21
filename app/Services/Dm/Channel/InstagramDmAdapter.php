<?php

namespace App\Services\Dm\Channel;

class InstagramDmAdapter implements DmChannelAdapterInterface
{
    public function normalize(array $payload): array
    {
        $payload['channel'] = 'instagram_dm';
        return $payload;
    }
}
