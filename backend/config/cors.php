<?php

return [
    'paths' => [
        'api/*',
        'storage/*',   // 🔥 BU SATIR ŞART
    ],

    'allowed_methods' => ['*'],

    'allowed_origins' => [
        'http://localhost:52736', // Flutter Web
    ],

    'allowed_headers' => ['*'],

    'supports_credentials' => false,
];