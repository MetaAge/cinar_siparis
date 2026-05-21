<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('dm_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('conversation_id')->constrained('dm_conversations')->cascadeOnDelete();
            $table->string('direction')->index(); // inbound|outbound
            $table->string('message_type')->default('text');
            $table->string('channel_message_id')->nullable()->index();
            $table->text('content');
            $table->json('raw_payload')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('dm_messages');
    }
};
