<?php

namespace App\Services;

use App\Models\Tenant;

class TenantOperationalPolicy
{
    /**
     * `past_due` remains operational in Phase 1 because no billing lock policy has
     * been approved yet. Suspension, cancellation, archive, and soft deletion do not.
     */
    public function allowsOperationalAccess(Tenant $tenant): bool
    {
        return ! $tenant->trashed()
            && ! in_array($tenant->status, ['suspended', 'cancelled', 'archived'], true);
    }
}
