<?php

namespace App\Actions\SuperAdmin;

use App\Services\FinancialSetupService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class OnboardTenant
{
    public function __construct(private readonly FinancialSetupService $financialSetup) {}

    public function handle(array $data, int $actorId): int
    {
        return DB::transaction(function () use ($data, $actorId): int {
            $plan = DB::table('plans')->where('id', $data['planId'])->where('is_active', true)->first();
            if (! $plan) {
                throw ValidationException::withMessages(['planId' => 'The selected plan is unavailable.']);
            }
            $now = now();
            $tenantId = DB::table('tenants')->insertGetId([
                'name' => $data['name'], 'slug' => $data['slug'], 'status' => 'trial', 'plan' => $plan->code,
                'email' => $data['email'], 'phone' => $data['phone'] ?? null, 'timezone' => $data['timezone'],
                'currency' => $data['currency'], 'logo_url' => $data['logoUrl'] ?? null, 'created_at' => $now, 'updated_at' => $now,
            ]);
            $ownerId = DB::table('users')->insertGetId([
                'tenant_id' => $tenantId, 'name' => $data['ownerName'], 'email' => $data['ownerEmail'],
                'password' => Hash::make(Str::random(32)), 'role' => 'owner', 'is_active' => true,
                'created_at' => $now, 'updated_at' => $now,
            ]);
            $branchId = DB::table('branches')->insertGetId([
                'tenant_id' => $tenantId, 'name' => $data['branchName'], 'address' => $data['branchAddress'] ?? null,
                'phone' => $data['branchPhone'] ?? null, 'timezone' => $data['timezone'], 'currency' => $data['currency'],
                'is_active' => true, 'created_at' => $now, 'updated_at' => $now,
            ]);
            DB::table('user_branches')->insert(['tenant_id' => $tenantId, 'user_id' => $ownerId, 'branch_id' => $branchId, 'created_at' => $now, 'updated_at' => $now]);
            $this->financialSetup->ensureForTenant($tenantId, $branchId, $ownerId);
            DB::table('tenant_settings')->insert(['tenant_id' => $tenantId, 'settings' => json_encode([]), 'created_at' => $now, 'updated_at' => $now]);
            $trialEnds = $now->copy()->addDays($data['trialDays']);
            $subscriptionId = DB::table('subscriptions')->insertGetId(['tenant_id' => $tenantId, 'plan_id' => $plan->id, 'status' => 'trialing', 'billing_cycle' => 'monthly', 'trial_starts_at' => $now, 'trial_ends_at' => $trialEnds, 'current_period_starts_at' => $now, 'current_period_ends_at' => $trialEnds, 'provider' => 'manual', 'created_at' => $now, 'updated_at' => $now]);
            DB::table('subscription_events')->insert(['subscription_id' => $subscriptionId, 'actor_id' => $actorId, 'event' => 'created', 'payload' => json_encode(['plan' => $plan->code]), 'occurred_at' => $now, 'created_at' => $now, 'updated_at' => $now]);

            return $tenantId;
        });
    }
}
