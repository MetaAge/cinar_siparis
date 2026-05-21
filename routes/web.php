<?php

use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Response;

Route::get('/public-image/orders/{filename}', function ($filename) {
    // Güvenlik: path traversal engelle
    $filename = basename($filename);

    $path = storage_path('app/public/orders/' . $filename);

    if (!File::exists($path)) {
        // Eğer DB bazen sonuna "_" eklediyse, tolerans:
        if (str_ends_with($filename, '_.png')) {
            $alt = storage_path('app/public/orders/' . rtrim($filename, '_'));
            if (File::exists($alt)) {
                $path = $alt;
            } else {
                abort(404, 'Image not found');
            }
        } else {
            abort(404, 'Image not found');
        }
    }

    return Response::file($path, [
        'Access-Control-Allow-Origin' => 'https://siparis.cinarpastaneleri.com',
        'Access-Control-Allow-Methods' => 'GET, OPTIONS',
        'Access-Control-Allow-Headers' => '*',
        'Cache-Control' => 'public, max-age=86400',
    ]);
});
