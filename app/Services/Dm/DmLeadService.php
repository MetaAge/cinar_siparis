<?php

namespace App\Services\Dm;

use App\Models\DmConversation;
use App\Models\DmLead;

class DmLeadService
{
    public function upsertFromFlow(DmConversation $conversation, array $flow): DmLead
    {
        $lead = DmLead::firstOrNew(['conversation_id' => $conversation->id]);
        $lead->customer_id = $conversation->customer_id;
        $lead->lead_type = $flow['intent_type'];
        $lead->status = $this->resolveStatus($flow);
        $lead->collected_data = $this->mergeCollectedData(
            (array) ($lead->collected_data ?? []),
            (array) ($flow['collected_data'] ?? [])
        );
        $lead->missing_fields = $flow['missing_fields'];
        $lead->conversation_summary = $flow['conversation_summary'];
        $lead->ai_recommendation = $flow['ai_recommendation'];
        if (($flow['needs_human'] ?? false) === true && $lead->escalated_at === null) {
            $lead->escalated_at = now();
            $lead->escalation_reason = (string) ($flow['escalation_reason'] ?? 'needs_human_rule_triggered');
        }
        $lead->save();

        $conversation->update(['intent_type' => $flow['intent_type']]);

        return $lead;
    }

    private function resolveStatus(array $flow): string
    {
        if (($flow['needs_human'] ?? false) === true) return 'waiting';
        return count($flow['missing_fields'] ?? []) === 0 ? 'waiting' : 'new';
    }

    private function mergeCollectedData(array $existing, array $incoming): array
    {
        foreach ($incoming as $key => $value) {
            if ($value === null) {
                continue;
            }
            if (is_string($value) && trim($value) === '') {
                continue;
            }
            $existing[$key] = $value;
        }
        return $existing;
    }
}
