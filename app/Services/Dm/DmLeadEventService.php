<?php

namespace App\Services\Dm;

use App\Models\DmLead;
use App\Models\DmLeadEvent;

class DmLeadEventService
{
    public function log(DmLead $lead, string $eventType, ?string $note = null, ?array $payload = null): DmLeadEvent
    {
        return DmLeadEvent::create([
            'lead_id' => $lead->id,
            'event_type' => $eventType,
            'note' => $note,
            'payload' => $payload,
        ]);
    }
}
