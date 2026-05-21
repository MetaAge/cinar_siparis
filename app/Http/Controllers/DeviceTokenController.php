<?php

namespace App\Http\Controllers;

use App\Models\DeviceToken;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
    public function store(Request $request)
    {
        $request->validate([
            'token' => 'required|string',
            'platform' => 'nullable|string',
        ]);

        $user = $request->user();

        // Aynı token farklı kullanıcıya kayıtlıysa taşı
        DeviceToken::where('token', $request->token)->where('user_id', '!=', $user->id)->delete();

        DeviceToken::updateOrCreate(
            ['token' => $request->token],
            ['user_id' => $user->id, 'platform' => $request->platform]
        );

        return response()->json(['ok' => true]);
    }
}