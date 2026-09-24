<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;

/**
 * Narrow v1 boundary for tenant Cafe Configuration. This deliberately stays
 * separate from the future granular permission matrix.
 */
class CafeConfigurationPolicy
{
    /**
     * Branch fields a Manager is allowed to touch through the shared branch
     * update endpoint. Everything else on that endpoint (name, financial
     * wiring, shift settings, POS warehouse, ...) remains Owner-only.
     */
    public const PRINTER_FIELDS = [
        'receiptPrintingEnabled',
        'defaultPaperWidth',
        'autoPrintAfterPayment',
        'defaultPrinterName',
        'defaultPrinterIp',
        'defaultPrinterPort',
    ];

    public function assertCanManageBranches(User $actor): void
    {
        $this->assertCanManage($actor);
    }

    public function assertCanManage(User $actor): void
    {
        if (! $actor->isOwner()) {
            throw new AuthorizationException('You are not allowed to manage cafe configuration.');
        }
    }

    /**
     * Owner and Manager may administer branch printing (printer defaults and
     * receipt template), and need read access to the branch picker/details
     * that the Printing screen depends on. Employee may not.
     */
    public function canAdministerPrinting(User $actor): bool
    {
        return in_array($actor->effectiveRoleCode(), [
            DefaultTenantRoleService::OWNER,
            DefaultTenantRoleService::MANAGER,
        ], true);
    }

    public function assertCanAdministerPrinting(User $actor): void
    {
        if (! $this->canAdministerPrinting($actor)) {
            throw new AuthorizationException('You are not allowed to manage printing configuration.');
        }
    }
}
