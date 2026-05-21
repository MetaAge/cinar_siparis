<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DmLeadEvent extends Model
{
    use HasFactory;

    protected $fillable = [
        'lead_id',
        'event_type',
        'note',
        'payload',
    ];

    protected $casts = [
        'payload' => 'array',
    ];

    public function lead(): BelongsTo
    {
        return $this->belongsTo(DmLead::class, 'lead_id');
    }
}
