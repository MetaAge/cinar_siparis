<?php

namespace App\Services\Firebase;

use Google\Client as GoogleClient;
use Illuminate\Support\Facades\Http;

class FirebaseClient
{
    private string $projectId;
    private string $accessToken;

    public function __construct()
    {
        $this->projectId = config('firebase.project_id');
        $this->accessToken = $this->generateAccessToken();
    }

    private function generateAccessToken(): string
    {
        $client = new GoogleClient();
        $client->setAuthConfig(config('firebase.credentials'));
        $client->addScope('https://www.googleapis.com/auth/firebase.messaging');

        $token = $client->fetchAccessTokenWithAssertion();

        return $token['access_token'];
    }

    public function send(array $payload)
    {
        $url = "https://fcm.googleapis.com/v1/projects/{$this->projectId}/messages:send";

        $response = Http::withToken($this->accessToken)
    ->post($url, ['message' => $payload]);

        return [
            'ok' => $response->successful(),
            'status' => $response->status(),
            'body' => $response->json(),
        ];
    }
}