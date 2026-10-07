<?php

namespace App\Services;

/**
 * The inter-branch clearing account ("جاري الفروع"). When one journal entry has lines in more
 * than one branch, each branch's side is balanced against this account, so every branch keeps
 * a balanced trial balance while the company-wide total of the account nets to zero.
 * Mapped as branches.inter_branch (the owner can re-map it). Phinix chart: 125 under 12.
 */
final class InterBranchAccount
{
    public const MAPPING_KEY = 'branches.inter_branch';

    public const NAME = 'جاري الفروع';

    public function __construct(private readonly SystemAccounts $accounts) {}

    public function id(int $tenantId): int
    {
        return $this->accounts->id($tenantId, self::MAPPING_KEY);
    }

    public function ensure(int $tenantId): int
    {
        return $this->accounts->ensure($tenantId, self::MAPPING_KEY);
    }
}
