<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class AddImageHeaders
{
    public function handle(Request $request, Closure $next)
    {
        $response = $next($request);

        // Sadece storage / image için güvenli
        if ($request->is('storage/*')) {
            $response->headers->set('Cross-Origin-Resource-Policy', 'cross-origin');
            $response->headers->set('Access-Control-Allow-Origin', '*');
        }

        return $response;
    }
}