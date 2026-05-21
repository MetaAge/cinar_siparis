<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('dm_lead_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('lead_id')->constrained('dm_leads')->cascadeOnDelete();
            $table->string('event_type')->index();
            $table->text('note')->nullable();
            $table->json('payload')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('dm_lead_events');
    }
};
