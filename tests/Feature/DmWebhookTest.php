<?php

namespace Tests\Feature;

use App\Models\DmLead;
use Illuminate\Support\Facades\Config;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DmWebhookTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_creates_conversation_message_and_lead(): void
    {
        $payload = [
            'channel' => 'whatsapp_simulated',
            'customer_phone' => '905551112233',
            'customer_name' => 'Ayse',
            'message' => 'Merhaba cumartesi 20 kişilik kız çocuk doğum günü pastası yaptırmak istiyorum',
            'message_id' => 'msg-1',
        ];

        $response = $this->postJson('/api/dm/webhook', $payload);

        $response->assertOk()
            ->assertJsonPath('ok', true)
            ->assertJsonPath('data.intent_type', 'boutique_cake');

        $this->assertDatabaseCount('dm_conversations', 1);
        $this->assertDatabaseCount('dm_messages', 2); // inbound + outbound
        $this->assertDatabaseCount('dm_leads', 1);

        $this->assertDatabaseHas('dm_leads', [
            'lead_type' => 'boutique_cake',
        ]);
    }

    public function test_it_updates_missing_fields_and_marks_waiting_when_complete(): void
    {
        $base = [
            'channel' => 'whatsapp_simulated',
            'customer_phone' => '905551112233',
            'customer_name' => 'Ayse',
        ];

        $this->postJson('/api/dm/webhook', $base + [
            'message' => 'Merhaba cumartesi 20 kişilik kız çocuk doğum günü pastası yaptırmak istiyorum',
            'message_id' => 'msg-101',
        ])->assertOk();

        $this->postJson('/api/dm/webhook', $base + [
            'message' => 'Saat 15:30 olsun, pasta yazısı İyi ki doğdun Lina, teslim alma olacak',
            'message_id' => 'msg-102',
        ])->assertOk()
            ->assertJsonPath('data.missing_fields.0', 'budget_range');

        $final = $this->postJson('/api/dm/webhook', $base + [
            'message' => 'Bütçem 2500-3000 TL, örnek görselim var',
            'message_id' => 'msg-103',
        ]);

        $final->assertOk()
            ->assertJsonPath('data.lead_status', 'waiting')
            ->assertJsonPath('data.missing_fields', [])
            ->assertJsonPath(
                'data.reply',
                'Teşekkür ederiz, bilgileri aldım. Net fiyat ve uygunluk personel onayı sonrası bildirilecektir.'
            );

        $this->assertDatabaseHas('dm_leads', [
            'lead_type' => 'boutique_cake',
            'status' => 'waiting',
        ]);
    }

    public function test_it_is_idempotent_for_duplicate_message_id(): void
    {
        $payload = [
            'channel' => 'whatsapp_simulated',
            'customer_phone' => '905551112233',
            'customer_name' => 'Ayse',
            'message' => 'Merhaba, test duplicate',
            'message_id' => 'dup-1',
        ];

        $this->postJson('/api/dm/webhook', $payload)->assertOk();
        $second = $this->postJson('/api/dm/webhook', $payload)->assertOk();

        $second->assertJsonPath('data.is_duplicate_message', true);
        $this->assertDatabaseCount('dm_messages', 3); // 1 inbound + 2 outbound
    }

    public function test_it_escalates_to_human_and_sets_fields(): void
    {
        $payload = [
            'channel' => 'whatsapp_simulated',
            'customer_phone' => '905551112233',
            'customer_name' => 'Ayse',
            'message' => 'Acil şikayetim var, yetkiliye bağlayın',
            'message_id' => 'esc-1',
        ];

        $this->postJson('/api/dm/webhook', $payload)->assertOk();

        $lead = DmLead::first();
        $this->assertNotNull($lead);
        $this->assertNotNull($lead->escalated_at);
        $this->assertNotNull($lead->escalation_reason);
    }

    public function test_it_requires_valid_signature_when_enabled(): void
    {
        Config::set('services.dm.signature_secret', 'test-secret');

        $payload = json_encode([
            'channel' => 'whatsapp_simulated',
            'customer_phone' => '905551112233',
            'customer_name' => 'Ayse',
            'message' => 'Merhaba',
            'message_id' => 'sig-1',
        ], JSON_UNESCAPED_UNICODE);

        $timestamp = time();
        $signature = hash_hmac('sha256', $timestamp.'.'.$payload, 'test-secret');

        $ok = $this->withHeaders([
            'X-DM-Timestamp' => (string) $timestamp,
            'X-DM-Signature' => $signature,
        ])->post('/api/dm/webhook', [], [
            'CONTENT_TYPE' => 'application/json',
            'CONTENT' => $payload,
        ]);

        // fallback: send with postJson + headers for framework compatibility
        if ($ok->status() >= 400) {
            $ok = $this->withHeaders([
                'X-DM-Timestamp' => (string) $timestamp,
                'X-DM-Signature' => $signature,
            ])->postJson('/api/dm/webhook', json_decode($payload, true));
        }

        $ok->assertOk();

        $bad = $this->withHeaders([
            'X-DM-Timestamp' => (string) $timestamp,
            'X-DM-Signature' => 'bad-signature',
        ])->postJson('/api/dm/webhook', json_decode($payload, true));

        $bad->assertStatus(401);
    }
}
