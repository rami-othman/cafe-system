<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class TenantAccessSeeder extends Seeder
{
    public function run(): void
    {
        $now = now();

        $tenantId = DB::table('tenants')->insertGetId([
            'name' => 'Cafe 6:18',
            'slug' => 'cafe-618',
            'status' => 'active',
            'plan' => 'starter',
            'currency' => 'SYP',
            'timezone' => 'Asia/Damascus',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $branchIds = [];
        foreach ([
            ['name' => 'Downtown', 'address' => '123 Espresso Lane, Cityville', 'phone' => '+963 11 555 0101'],
            ['name' => 'Mall', 'address' => 'Level 2, City Mall', 'phone' => '+963 11 555 0102'],
            ['name' => 'Airport', 'address' => 'Departures Hall', 'phone' => '+963 11 555 0103'],
        ] as $branch) {
            $branchIds[$branch['name']] = DB::table('branches')->insertGetId([
                'tenant_id' => $tenantId,
                'name' => $branch['name'],
                'address' => $branch['address'],
                'phone' => $branch['phone'],
                'currency' => 'SYP',
                'timezone' => 'Asia/Damascus',
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $userIds = [];
        foreach ([
            ['name' => 'Cafe Owner', 'email' => 'owner@cafe618.local', 'role' => 'owner'],
            ['name' => 'Cashier User', 'email' => 'cashier@cafe618.local', 'role' => 'cashier'],
            ['name' => 'Shift Manager', 'email' => 'manager@cafe618.local', 'role' => 'manager'],
        ] as $user) {
            $userIds[$user['email']] = DB::table('users')->insertGetId([
                'tenant_id' => $tenantId,
                'name' => $user['name'],
                'email' => $user['email'],
                'password' => Hash::make('password'),
                'role' => $user['role'],
                'email_verified_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $assignments = [];
        foreach ($userIds as $userId) {
            $assignments[] = [
                'tenant_id' => $tenantId,
                'user_id' => $userId,
                'branch_id' => $branchIds['Downtown'],
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        DB::table('user_branches')->insert($assignments);

        DB::table('api_tokens')->insert([
            'tenant_id' => $tenantId,
            'user_id' => $userIds['cashier@cafe618.local'],
            'name' => 'demo-pos-token',
            'token_hash' => hash('sha256', 'demo-pos-token'),
            'expires_at' => $now->copy()->addDays(30),
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }
}
