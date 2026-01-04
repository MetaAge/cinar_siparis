<?php
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\Response;

Route::get('/image-proxy', function (Request $request) {
    $url = urldecode($request->query('url'));

    // SADECE local storage dosyalarına izin ver
    if (!str_starts_with($url, 'http://localhost:8000/storage/')) {
        abort(403);
    }

    // storage path’e çevir
    $path = str_replace('http://localhost:8000/storage/', '', $url);

    if (!Storage::disk('public')->exists($path)) {
        abort(404);
    }

    $file = Storage::disk('public')->get($path);
    $mime = Storage::disk('public')->mimeType($path);

    return response($file, 200, [
        'Content-Type' => $mime,
        'Access-Control-Allow-Origin' => '*',
        'Cache-Control' => 'public, max-age=86400',
    ]);
});