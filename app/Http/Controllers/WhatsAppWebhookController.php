<?php

namespace App\Http\Controllers;

use App\Services\Dm\DmWebhookService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WhatsAppWebhookController extends Controller
{
    public function __construct(private DmWebhookService $dmWebhookService) {}

    public function verify(Request $request)
    {
        $mode = $request->query('hub_mode') ?? $request->query('hub.mode');
        $token = $request->query('hub_verify_token') ?? $request->query('hub.verify_token');
        $challenge = $request->query('hub_challenge') ?? $request->query('hub.challenge');

        if ($mode === 'subscribe' && $token === (string) env('WA_VERIFY_TOKEN')) {
            return response((string) $challenge, 200)
                ->header('Content-Type', 'text/plain');
        }

        return response('Forbidden', 403)->header('Content-Type', 'text/plain');
    }

    public function receive(Request $request): JsonResponse
    {
        // Minimal parser (Cloud API webhook payload)
        $entries = $request->input('entry', []);
        foreach ($entries as $entry) {
            foreach (($entry['changes'] ?? []) as $change) {
                $value = $change['value'] ?? [];
                $messages = $value['messages'] ?? [];
                $contacts = $value['contacts'] ?? [];
                $contactName = $contacts[0]['profile']['name'] ?? null;

                foreach ($messages as $msg) {
                    if (($msg['type'] ?? '') !== 'text') {
                        continue;
                    }
                    $payload = [
                        'channel' => 'whatsapp_cloud',
                        'customer_phone' => $msg['from'] ?? 'unknown',
                        'customer_name' => $contactName,
                        'message' => $msg['text']['body'] ?? '',
                        'message_id' => $msg['id'] ?? null,
                        'conversation_id' => $value['metadata']['phone_number_id'] ?? null,
                    ];

                    $this->dmWebhookService->handle($payload);
                }
            }
        }

        return response()->json(['ok' => true]);
    }
}
