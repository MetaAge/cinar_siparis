<?php

namespace App\Services\Dm;

class DmAiFlowService
{
    public function evaluate(string $text, array $currentData = []): array
    {
        $intent = $this->detectIntent($text, $currentData['intent_type'] ?? null);
        $newData = array_merge($currentData, $this->extractData($intent, $text));
        $required = $this->requiredFields($intent);
        $missing = array_values(array_filter($required, fn($f) => empty($newData[$f])));

        return [
            'intent_type' => $intent,
            'collected_data' => $newData,
            'missing_fields' => $missing,
            'reply' => $this->buildReply($intent, $missing),
            'conversation_summary' => $this->buildSummary($intent, $newData),
            'ai_recommendation' => $this->buildRecommendation($intent, $missing),
            'needs_human' => $this->needsHuman($text),
        ];
    }

    private function detectIntent(string $text, ?string $existing): string
    {
        if ($existing) return $existing;

        $t = mb_strtolower($text);
        if (str_contains($t, 'kruvasan')) return 'croissant';
        if (str_contains($t, 'pasta') || str_contains($t, 'doğum günü') || str_contains($t, 'dogum gunu')) return 'boutique_cake';
        if (str_contains($t, 'adres') || str_contains($t, 'şube') || str_contains($t, 'saat')) return 'branch_info';
        if (str_contains($t, 'insan') || str_contains($t, 'yetkili') || str_contains($t, 'şikayet')) return 'human_support';
        return 'general_product';
    }

    private function extractData(string $intent, string $text): array
    {
        $t = mb_strtolower($text);
        $data = [];

        if (preg_match('/(\d{1,3})\s*kiş/i', $text, $m)) $data['person_count'] = $m[1];
        if (str_contains($t, 'cumartesi')) $data['date'] = 'cumartesi';
        if (str_contains($t, 'pazar')) $data['date'] = 'pazar';
        if (preg_match('/(\d{1,2}[:.]\d{2})/', $text, $m)) $data['time'] = str_replace('.', ':', $m[1]);
        if (str_contains($t, 'kız çocuk')) $data['concept'] = 'kız çocuk doğum günü';

        if ($intent === 'boutique_cake') {
            if (preg_match('/pasta yazısı[:\s-]*(.+)/iu', $text, $m)) {
                $data['cake_text'] = $this->cleanCakeText($m[1]);
            } elseif (preg_match('/yazı[:\s-]*(.+)/iu', $text, $m)) {
                $data['cake_text'] = $this->cleanCakeText($m[1]);
            }

            if (str_contains($t, 'teslim alma')) $data['delivery_type'] = 'teslim_alma';
            if (str_contains($t, 'paket')) $data['delivery_type'] = 'paket';
            if (str_contains($t, 'kurye')) $data['delivery_type'] = 'kurye';

            if (preg_match('/(\d{3,6})\s*[-–]\s*(\d{3,6})\s*(tl|₺)?/iu', $text, $m)) {
                $data['budget_range'] = $m[1].'-'.$m[2].' TL';
            } elseif (preg_match('/bütçe\w*[:\s-]*(\d{3,6})\s*(tl|₺)?/iu', $text, $m)) {
                $data['budget_range'] = $m[1].' TL';
            }

            if (str_contains($t, 'görselim var') || str_contains($t, 'ornek gorselim var') || str_contains($t, 'örnek görselim var')) {
                $data['has_reference_image'] = true;
            }
            if (str_contains($t, 'görsel yok') || str_contains($t, 'örnek görsel yok')) {
                $data['has_reference_image'] = false;
            }
        }

        return $data;
    }

    private function cleanCakeText(string $raw): string
    {
        $cakeText = trim($raw, " \t\n\r\0\x0B,.");
        $cakeText = preg_split('/,\s*(teslim alma|paket|kurye)\b/iu', $cakeText)[0] ?? $cakeText;
        return trim($cakeText, " \t\n\r\0\x0B,.");
    }

    private function requiredFields(string $intent): array
    {
        return match ($intent) {
            'boutique_cake' => ['date', 'time', 'person_count', 'concept', 'cake_text', 'delivery_type', 'budget_range', 'has_reference_image'],
            'croissant' => ['croissant_type', 'quantity', 'delivery_type', 'hot_out_time'],
            default => [],
        };
    }

    private function buildReply(string $intent, array $missing): string
    {
        if ($intent === 'human_support') {
            return 'Sizi hemen yetkili ekibe yönlendiriyorum. Kısa süre içinde dönüş yapılacaktır.';
        }

        if (count($missing) === 0) {
            return 'Teşekkür ederiz, bilgileri aldım. Net fiyat ve uygunluk personel onayı sonrası bildirilecektir.';
        }

        $labels = [
            'date' => 'teslim tarihi',
            'time' => 'teslim saati',
            'person_count' => 'kişi sayısı',
            'concept' => 'konsept',
            'cake_text' => 'pasta yazısı',
            'delivery_type' => 'teslim alma / paket / kurye tercihi',
            'budget_range' => 'bütçe aralığı',
            'has_reference_image' => 'örnek görsel olup olmadığı',
            'croissant_type' => 'kruvasan çeşidi',
            'quantity' => 'adet',
            'hot_out_time' => 'sıcak çıkış saati beklentisi',
        ];

        $first = $missing[0];
        $question = $labels[$first] ?? $first;

        return "Memnuniyetle yardımcı olayım. Öncelikle {$question} bilgisini paylaşabilir misiniz?";
    }

    private function buildSummary(string $intent, array $data): string
    {
        return 'Talep türü: '.$intent.'. Toplanan alan sayısı: '.count($data);
    }

    private function buildRecommendation(string $intent, array $missing): string
    {
        if ($intent === 'human_support') return 'İnsan desteğine öncelikli atama önerilir.';
        if (count($missing) > 0) return 'Eksik bilgiler tamamlanınca personel onayına gönderilsin.';
        return 'Lead personel onayı için hazır.';
    }

    private function needsHuman(string $text): bool
    {
        $t = mb_strtolower($text);
        return str_contains($t, 'acil') || str_contains($t, 'şikayet') || str_contains($t, 'sinir') || str_contains($t, 'iptal');
    }
}
