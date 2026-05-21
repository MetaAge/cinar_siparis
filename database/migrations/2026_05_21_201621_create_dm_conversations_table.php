<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('dm_conversations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_id')->constrained('dm_customers')->cascadeOnDelete();
            $table->string('channel')->default('whatsapp_simulated')->index();
            $table->string('channel_conversation_id')->nullable()->index();
            $table->string('status')->default('open')->index();
            $table->string('intent_type')->nullable()->index();
            $table->timestamp('last_message_at')->nullable()->index();
            $table->json('meta')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('dm_conversations');
    }
};
