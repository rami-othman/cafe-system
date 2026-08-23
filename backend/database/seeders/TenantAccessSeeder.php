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

        DB::table('tenants')->updateOrInsert(['slug' => 'cafe-618'], [
            'name' => 'Cafe 6:18',
            'status' => 'active',
            'plan' => 'starter',
            'currency' => 'SYP',
            'timezone' => 'Asia/Damascus',
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');

        $branchIds = [];
        foreach ([
            ['name' => 'Main Branch', 'address' => 'Cafe System 618 Main Branch', 'phone' => '+963 11 555 0100'],
            ['name' => 'Downtown', 'address' => '123 Espresso Lane, Cityville', 'phone' => '+963 11 555 0101'],
            ['name' => 'Mall', 'address' => 'Level 2, City Mall', 'phone' => '+963 11 555 0102'],
            ['name' => 'Airport', 'address' => 'Departures Hall', 'phone' => '+963 11 555 0103'],
        ] as $branch) {
            DB::table('branches')->updateOrInsert([
                'tenant_id' => $tenantId,
                'name' => $branch['name'],
            ], [
                'address' => $branch['address'],
                'phone' => $branch['phone'],
                'currency' => 'SYP',
                'timezone' => 'Asia/Damascus',
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            $branchIds[$branch['name']] = (int) DB::table('branches')
                ->where('tenant_id', $tenantId)
                ->where('name', $branch['name'])
                ->value('id');
        }

        $userIds = [];
        foreach ([
            ['name' => 'Cafe Owner', 'email' => 'owner@cafe618.local', 'role' => 'owner'],
            ['name' => 'Cashier User', 'email' => 'cashier@cafe618.local', 'role' => 'cashier'],
            ['name' => 'Shift Manager', 'email' => 'manager@cafe618.local', 'role' => 'manager'],
        ] as $user) {
            DB::table('users')->updateOrInsert([
                'tenant_id' => $tenantId,
                'email' => $user['email'],
            ], [
                'name' => $user['name'],
                'password' => Hash::make('password'),
                'role' => $user['role'],
                'email_verified_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            $userIds[$user['email']] = (int) DB::table('users')
                ->where('tenant_id', $tenantId)
                ->where('email', $user['email'])
                ->value('id');
        }

        $assignments = [];
        foreach ($userIds as $email => $userId) {
            foreach ($email === 'manager@cafe618.local' ? $branchIds : [$branchIds['Downtown']] as $branchId) {
                $assignments[] = [
                    'tenant_id' => $tenantId,
                    'user_id' => $userId,
                    'branch_id' => $branchId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
            }
        }

        foreach ($assignments as $assignment) {
            DB::table('user_branches')->updateOrInsert([
                'tenant_id' => $assignment['tenant_id'],
                'user_id' => $assignment['user_id'],
                'branch_id' => $assignment['branch_id'],
            ], $assignment);
        }

        DB::table('api_tokens')->updateOrInsert([
            'tenant_id' => $tenantId,
            'user_id' => $userIds['cashier@cafe618.local'],
            'name' => 'demo-pos-token',
        ], [
            'token_hash' => hash('sha256', 'demo-pos-token'),
            'expires_at' => $now->copy()->addDays(30),
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }
}
