<?php

namespace App\Models\Concerns;

use Illuminate\Database\Eloquent\Builder;

trait HasTenantScope
{
    public function scopeForTenant(Builder $query, int $tenantId): Builder
    {
        return $query->where($query->getModel()->getTable().'.tenant_id', $tenantId);
    }
}
