<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('dm_leads', function (Blueprint $table) {
            $table->id();
            $table->foreignId('conversation_id')->constrained('dm_conversations')->cascadeOnDelete();
            $table->foreignId('customer_id')->constrained('dm_customers')->cascadeOnDelete();
            $table->string('lead_type')->nullable()->index();
            $table->string('status')->default('new')->index(); // new|waiting|approved|cancelled
            $table->json('collected_data')->nullable();
            $table->json('missing_fields')->nullable();
            $table->text('conversation_summary')->nullable();
            $table->text('ai_recommendation')->nullable();
            $table->text('staff_notes')->nullable();
            $table->timestamps();
            $table->unique('conversation_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('dm_leads');
    }
};
