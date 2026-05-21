<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('dm_customers', function (Blueprint $table) {
            $table->id();
            $table->string('name')->nullable();
            $table->string('phone')->index();
            $table->string('channel')->default('whatsapp_simulated')->index();
            $table->string('external_id')->nullable()->index();
            $table->json('meta')->nullable();
            $table->timestamps();
            $table->unique(['channel', 'phone']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('dm_customers');
    }
};
