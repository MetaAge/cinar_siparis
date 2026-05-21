<?php

namespace App\Services\Dm;

use App\Models\DmConversation;
use App\Models\DmCustomer;
use App\Models\DmMessage;

class DmConversationService
{
    public function findOrCreateCustomer(array $payload): DmCustomer
    {
        return DmCustomer::firstOrCreate(
            [
                'channel' => $payload['channel'] ?? 'whatsapp_simulated',
                'phone' => $payload['customer_phone'] ?? 'unknown',
            ],
            [
                'name' => $payload['customer_name'] ?? null,
                'external_id' => $payload['customer_external_id'] ?? null,
            ]
        );
    }

    public function findOrCreateConversation(DmCustomer $customer, array $payload): DmConversation
    {
        return DmConversation::firstOrCreate(
            [
                'customer_id' => $customer->id,
                'channel' => $payload['channel'] ?? 'whatsapp_simulated',
                'status' => 'open',
            ],
            [
                'channel_conversation_id' => $payload['conversation_id'] ?? null,
                'last_message_at' => now(),
            ]
        );
    }

    public function addInboundMessage(DmConversation $conversation, array $payload): array
    {
        $conversation->update(['last_message_at' => now()]);

        $messageId = $payload['message_id'] ?? null;
        if ($messageId) {
            $existing = DmMessage::where('conversation_id', $conversation->id)
                ->where('direction', 'inbound')
                ->where('channel_message_id', $messageId)
                ->first();
            if ($existing) {
                return ['message' => $existing, 'is_duplicate' => true];
            }
        }

        $created = DmMessage::create([
            'conversation_id' => $conversation->id,
            'direction' => 'inbound',
            'message_type' => 'text',
            'channel_message_id' => $payload['message_id'] ?? null,
            'content' => $payload['message'] ?? '',
            'raw_payload' => $payload,
        ]);

        return ['message' => $created, 'is_duplicate' => false];
    }

    public function addOutboundMessage(DmConversation $conversation, string $content): DmMessage
    {
        return DmMessage::create([
            'conversation_id' => $conversation->id,
            'direction' => 'outbound',
            'message_type' => 'text',
            'content' => $content,
            'raw_payload' => null,
        ]);
    }
}
