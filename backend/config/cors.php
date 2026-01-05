<?php

return [
    'paths' => [
        'api/*',
        'storage/*',
    ],

    'allowed_methods' => ['*'],

    'allowed_origins' => [
        'https://siparis.cinarpastaneleri.com',
    ],

    'allowed_headers' => ['*'],

    'supports_credentials' => false,
];
