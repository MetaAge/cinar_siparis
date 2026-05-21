<?php

namespace App\Services\Dm\Channel;

interface DmChannelAdapterInterface
{
    public function normalize(array $payload): array;
}
