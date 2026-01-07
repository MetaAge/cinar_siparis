<?php

return [
    'paths' => [
        'api/*',
        'storage/*',
    ],

    'allowed_methods' => ['*'],

    'allowed_origins' => [
        'https://siparis.cinarpastaneleri.com',
        'http://localhost:3306',
        'http://127.0.0.1:3306',
    ],

    'allowed_headers' => ['*'],

    'supports_credentials' => false,
];
