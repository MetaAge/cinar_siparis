<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class DmConversation extends Model
{
    use HasFactory;

    protected $fillable = [
        'customer_id',
        'channel',
        'channel_conversation_id',
        'status',
        'intent_type',
        'last_message_at',
        'meta',
    ];

    protected $casts = [
        'last_message_at' => 'datetime',
        'meta' => 'array',
    ];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(DmCustomer::class, 'customer_id');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(DmMessage::class, 'conversation_id');
    }

    public function lead(): BelongsTo
    {
        return $this->belongsTo(DmLead::class, 'id', 'conversation_id');
    }
}
