<?php

namespace App\Services\Dm;

class DmWebhookService
{
    public function __construct(
        private DmConversationService $conversationService,
        private DmAiFlowService $aiFlowService,
        private DmLeadService $leadService,
        private DmLeadEventService $leadEventService,
    ) {}

    public function handle(array $payload): array
    {
        $customer = $this->conversationService->findOrCreateCustomer($payload);
        $conversation = $this->conversationService->findOrCreateConversation($customer, $payload);

        $inboundResult = $this->conversationService->addInboundMessage($conversation, $payload);
        $isDuplicate = (bool) ($inboundResult['is_duplicate'] ?? false);

        $existingData = $conversation->lead?->collected_data ?? [];
        $existingData['intent_type'] = $conversation->intent_type;

        $flow = $this->aiFlowService->evaluate($payload['message'] ?? '', $existingData);
        $lead = $this->leadService->upsertFromFlow($conversation, $flow);
        $this->leadEventService->log($lead, 'lead_upserted', null, [
            'intent_type' => $lead->lead_type,
            'missing_fields' => $lead->missing_fields,
            'status' => $lead->status,
        ]);
        if (($flow['needs_human'] ?? false) === true) {
            $this->leadEventService->log($lead, 'escalated', 'Needs human review', [
                'reason' => $lead->escalation_reason,
            ]);
        }

        $outbound = $this->conversationService->addOutboundMessage($conversation, $flow['reply']);

        return [
            'conversation_id' => $conversation->id,
            'lead_id' => $lead->id,
            'lead_status' => $lead->status,
            'is_duplicate_message' => $isDuplicate,
            'intent_type' => $lead->lead_type,
            'missing_fields' => $lead->missing_fields,
            'reply' => $outbound->content,
        ];
    }
}
