<?php

namespace App\Http\Controllers;

use App\Services\Dm\Channel\DmChannelAdapterResolver;
use App\Services\Dm\DmWebhookService;
use Illuminate\Support\Facades\Cache;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DmWebhookController extends Controller
{
    public function __construct(
        private DmWebhookService $service,
        private DmChannelAdapterResolver $adapterResolver,
    ) {}

    public function store(Request $request): JsonResponse
    {
        $traceId = (string) str()->uuid();
        $expected = (string) config('services.dm.webhook_secret');
        if ($expected !== '') {
            $incoming = (string) $request->header('X-DM-Webhook-Secret', '');
            if (!hash_equals($expected, $incoming)) {
                return response()->json([
                    'ok' => false,
                    'message' => 'Unauthorized webhook secret.',
                    'trace_id' => $traceId,
                ], 401);
            }
        }
        if (!$this->passesSignature($request)) {
            return response()->json(['ok' => false, 'message' => 'Invalid signature.', 'trace_id' => $traceId], 401);
        }

        $validated = $request->validate([
            'channel' => 'required|string|max:50',
            'customer_phone' => 'required|string|max:30',
            'customer_name' => 'nullable|string|max:100',
            'message' => 'required|string|max:3000',
            'message_id' => 'nullable|string|max:100',
            'conversation_id' => 'nullable|string|max:100',
        ]);
        if (!$this->passesRateLimit($validated)) {
            return response()->json(['ok' => false, 'message' => 'Too many requests.', 'trace_id' => $traceId], 429);
        }

        $adapter = $this->adapterResolver->resolve($validated['channel']);
        $normalized = $adapter->normalize($validated);
        $result = $this->service->handle($normalized);

        return response()->json([
            'ok' => true,
            'data' => $result,
            'trace_id' => $traceId,
        ]);
    }

    private function passesRateLimit(array $payload): bool
    {
        $key = 'dm_webhook:'.($payload['channel'] ?? 'x').':'.($payload['customer_phone'] ?? 'x');
        $count = Cache::increment($key);
        if ($count === 1) {
            Cache::put($key, 1, now()->addMinute());
        }
        return $count <= (int) config('services.dm.rate_limit_per_minute', 30);
    }

    private function passesSignature(Request $request): bool
    {
        $secret = (string) config('services.dm.signature_secret');
        if ($secret === '') return true;

        $timestamp = (int) $request->header('X-DM-Timestamp', 0);
        $signature = (string) $request->header('X-DM-Signature', '');
        if ($timestamp <= 0 || $signature === '') return false;
        if (abs(time() - $timestamp) > (int) config('services.dm.signature_ttl_seconds', 300)) return false;

        $raw = $request->getContent();
        $expected = hash_hmac('sha256', $timestamp.'.'.$raw, $secret);
        return hash_equals($expected, $signature);
    }
}
