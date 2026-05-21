<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class DmCustomer extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'phone',
        'channel',
        'external_id',
        'meta',
    ];

    protected $casts = [
        'meta' => 'array',
    ];

    public function conversations(): HasMany
    {
        return $this->hasMany(DmConversation::class, 'customer_id');
    }
}
