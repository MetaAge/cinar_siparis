<?php

namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use App\Models\OrderImage;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use App\Enums\OrderStatus;


class Order extends Model
{
    protected $fillable = [
    'order_no',
    'customer_name',
    'customer_phone',
    'order_details',
    'image_url',
    'order_total',
    'deposit_amount',
    'remaining_amount',
    'delivery_datetime',
    'status',
    'created_by',
    ];

    protected $casts = [
    'order_total'       => 'integer',
    'deposit_amount'    => 'integer',
    'remaining_amount'  => 'integer',
    'delivery_datetime' => 'datetime',
    ];

    public function images()
    {
        return $this->hasMany(OrderImage::class);
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}