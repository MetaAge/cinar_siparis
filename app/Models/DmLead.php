<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class DmLead extends Model
{
    use HasFactory;

    protected $fillable = [
        'conversation_id',
        'customer_id',
        'lead_type',
        'status',
        'escalated_at',
        'escalation_reason',
        'collected_data',
        'missing_fields',
        'conversation_summary',
        'ai_recommendation',
        'staff_notes',
    ];

    protected $casts = [
        'escalated_at' => 'datetime',
        'collected_data' => 'array',
        'missing_fields' => 'array',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(DmCustomer::class, 'customer_id');
    }

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(DmConversation::class, 'conversation_id');
    }

    public function events(): HasMany
    {
        return $this->hasMany(DmLeadEvent::class, 'lead_id');
    }
}
