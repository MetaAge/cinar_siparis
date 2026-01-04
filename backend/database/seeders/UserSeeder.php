<?php

namespace Database\Seeders;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Database\Seeder;

class UserSeeder extends Seeder
{
    public function run()
    {
        User::create([
            'name' => 'Tezgahtar',
            'email' => 'cashier@cinar.com',
            'password' => Hash::make('123456'),
            'role' => 'cashier',
        ]);

        User::create([
            'name' => 'İmalat',
            'email' => 'production@cinar.com',
            'password' => Hash::make('123456'),
            'role' => 'production',
        ]);

        User::create([
            'name' => 'Admin',
            'email' => 'admin@cinar.com',
            'password' => Hash::make('123456'),
            'role' => 'admin',
        ]);
    }
}