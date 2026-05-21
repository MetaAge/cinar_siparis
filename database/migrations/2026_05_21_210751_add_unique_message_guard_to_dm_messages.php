<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('dm_messages', function (Blueprint $table) {
            $table->unique(['conversation_id', 'direction', 'channel_message_id'], 'dm_messages_unique_external');
        });
    }

    public function down(): void
    {
        Schema::table('dm_messages', function (Blueprint $table) {
            $table->dropUnique('dm_messages_unique_external');
        });
    }
};
