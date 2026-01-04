<?php

use Illuminate\Support\Facades\Response;
use Illuminate\Support\Facades\Storage;

Route::get('/public-image/{path}', function ($path) {
    if (!Storage::disk('public')->exists($path)) {
        abort(404);
    }

    $file = Storage::disk('public')->get($path);
    $type = Storage::disk('public')->mimeType($path);

    return Response::make($file, 200, [
        'Content-Type' => $type,
        'Access-Control-Allow-Origin' => 'http://localhost:52736',
    ]);
})->where('path', '.*');