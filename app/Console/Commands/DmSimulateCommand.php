<?php

namespace App\Console\Commands;

use App\Models\DmLead;
use App\Services\Dm\DmWebhookService;
use Illuminate\Console\Command;

class DmSimulateCommand extends Command
{
    protected $signature = 'dm:simulate {phone=905551112233} {--name=Ayse}';
    protected $description = 'Run a 3-step DM simulation and print lead progression.';

    /**
     * Execute the console command.
     */
    public function handle(DmWebhookService $service): int
    {
        $phone = (string) $this->argument('phone');
        $name = (string) $this->option('name');

        $messages = [
            'Merhaba cumartesi 20 kişilik kız çocuk doğum günü pastası yaptırmak istiyorum',
            'Saat 15:30 olsun, pasta yazısı İyi ki doğdun Lina, teslim alma olacak',
            'Bütçem 2500-3000 TL, örnek görselim var',
        ];

        foreach ($messages as $idx => $message) {
            $result = $service->handle([
                'channel' => 'whatsapp_simulated',
                'customer_phone' => $phone,
                'customer_name' => $name,
                'message' => $message,
                'message_id' => 'sim-cli-'.($idx + 1).'-'.time(),
            ]);

            $this->line('');
            $this->info('Step '.($idx + 1));
            $this->line('Intent: '.$result['intent_type']);
            $this->line('Lead Status: '.$result['lead_status']);
            $this->line('Missing: '.json_encode($result['missing_fields'], JSON_UNESCAPED_UNICODE));
            $this->line('Reply: '.$result['reply']);
        }

        $lead = DmLead::with('customer')->latest('id')->first();
        if ($lead) {
            $this->line('');
            $this->info('Final Lead Snapshot');
            $this->line('Lead ID: '.$lead->id);
            $this->line('Customer: '.($lead->customer->name ?? '').' / '.$lead->customer->phone);
            $this->line('Type: '.$lead->lead_type);
            $this->line('Status: '.$lead->status);
            $this->line('Collected: '.json_encode($lead->collected_data, JSON_UNESCAPED_UNICODE));
        }

        return self::SUCCESS;
    }
}
