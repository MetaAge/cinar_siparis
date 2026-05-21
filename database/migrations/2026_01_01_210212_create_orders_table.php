<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
    $table->id();
    $table->string('order_no')->unique();
    $table->string('customer_name');
    $table->string('customer_phone');
    $table->text('order_details');

    $table->decimal('order_total', 10, 2);
    $table->decimal('deposit_amount', 10, 2)->default(0);
    $table->decimal('remaining_amount', 10, 2);

    $table->dateTime('delivery_datetime');

    $table->enum('status', [
        'pending',
        'preparing',
        'ready',
        'delivered',
        "paid"
    ])->default('pending');

    $table->foreignId('created_by')->constrained('users');
    $table->timestamps();
});
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
