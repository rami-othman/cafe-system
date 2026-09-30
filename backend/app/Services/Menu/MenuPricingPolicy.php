<?php

namespace App\Services\Menu;

use App\Models\User;
use App\Services\DefaultTenantRoleService;
use App\Domain\Menu\MenuPricingException;

/** Isolated V1 boundary; replace internals with menu.pricing.manage later. */
class MenuPricingPolicy
{
    public function canManage(?User $actor): bool
    {
        return $actor && in_array($actor->effectiveRoleCode(), [DefaultTenantRoleService::OWNER, DefaultTenantRoleService::MANAGER], true);
    }

    public function assertCanManage(?User $actor): void
    {
        if (! $this->canManage($actor)) {
            throw new MenuPricingException('MENU_PRICING_FORBIDDEN', 403);
        }
    }
}
