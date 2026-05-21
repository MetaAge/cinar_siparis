<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use App\Models\Order;



class OrderImage extends Model
{
    protected $fillable = ['order_id', 'image_path'];

    public function order()
    {
        return $this->belongsTo(Order::class);
    }
}