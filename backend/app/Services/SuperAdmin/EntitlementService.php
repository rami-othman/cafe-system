<?php

namespace App\Services\SuperAdmin;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class EntitlementService
{
    public function tenantHasFeature(int $tenantId, string $featureKey): bool
    {
        return (bool) DB::table('subscriptions')->join('plan_features', 'plan_features.plan_id', '=', 'subscriptions.plan_id')
            ->where('subscriptions.tenant_id', $tenantId)->whereIn('subscriptions.status', ['trialing', 'active'])
            ->where('plan_features.feature_key', $featureKey)->value('plan_features.is_enabled');
    }

    public function tenantLimit(int $tenantId, string $limitKey): ?int
    {
        return DB::table('subscriptions')->join('plan_features', 'plan_features.plan_id', '=', 'subscriptions.plan_id')
            ->where('subscriptions.tenant_id', $tenantId)->where('plan_features.feature_key', $limitKey)->value('plan_features.limit_value');
    }

    public function assertCanCreateBranch(int $tenantId): void
    {
        $limit = $this->tenantLimit($tenantId, 'max_branches');
        if ($limit !== null && DB::table('branches')->where('tenant_id', $tenantId)->whereNull('deleted_at')->count() >= $limit) {
            throw ValidationException::withMessages(['branch' => 'The plan branch limit has been reached.']);
        }
    }
}
