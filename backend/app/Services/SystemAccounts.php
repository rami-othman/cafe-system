<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use RuntimeException;

/**
 * Accounts the assets / partners modules need, resolved once per tenant and remembered as a
 * mapping row (sales_account_mappings) so the owner can re-map them. Resolution order:
 *   1. existing mapping
 *   2. an existing account to adopt (by code — Phinix chart — then by exact Arabic name)
 *   3. a new account under the preferred parent (Phinix) or as a root (legacy chart)
 * Plus createChild(): a person-level account (partner capital, current, drawings) under a parent.
 */
final class SystemAccounts
{
    /**
     * key => [name, adoptCodes[], parentCodes[], preferredCodes[], group, normal, legacyCodes[]]
     * adoptCodes must also match the group, otherwise they are skipped.
     */
    public const SPECS = [
        'branches.inter_branch' => ['جاري الفروع', [], ['12'], ['125'], 'assets', 'debit', ['1900']],
        'assets.gain' => ['ارباح راس مالية', ['63'], ['6'], ['63'], 'revenue', 'credit', ['4900']],
        'assets.loss' => ['خسائر راس مالية', ['514'], ['5'], ['514'], 'expenses', 'debit', ['6900']],
        'assets.depreciation_expense' => ['مصاريف اهتلاك', ['515'], ['5'], ['515'], 'expenses', 'debit', ['6800']],
        'partners.capital_parent' => ['رأس المال', ['211'], ['21'], ['211'], 'equity', 'credit', ['3100']],
        'partners.current_parent' => ['جاري الشركاء', [], ['22'], ['227'], 'liabilities', 'credit', ['2500']],
        'partners.drawings_parent' => ['مسحوبات الشركاء', ['123'], ['12'], ['123'], 'assets', 'debit', ['1950']],
        'partners.distribution' => ['توزيعات أرباح الفروع', [], ['21'], ['212'], 'equity', 'debit', ['3300']],
    ];

    public function __construct(private readonly FinanceAccountMap $map) {}

    public function id(int $tenantId, string $key): int
    {
        return (int) ($this->map->account($tenantId, $key)?->id ?? $this->ensure($tenantId, $key));
    }

    public function ensure(int $tenantId, string $key): int
    {
        $mapped = $this->map->account($tenantId, $key);
        if ($mapped) {
            return (int) $mapped->id;
        }
        [$name, $adopt, $parents, $preferred, $group, $normal, $legacy] = self::SPECS[$key]
            ?? throw new RuntimeException("Unknown system account key {$key}.");

        return DB::transaction(function () use ($tenantId, $key, $name, $adopt, $parents, $preferred, $group, $normal, $legacy): int {
            $now = now();
            $live = fn () => DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereNull('deleted_at');
            $accountId = null;
            foreach ($adopt as $code) {
                $row = $live()->where('code', $code)->first();
                if ($row && $row->account_group === $group) {
                    $accountId = (int) $row->id;
                    break;
                }
            }
            $accountId ??= ($id = $live()->where('name_ar', $name)->where('account_group', $group)->value('id')) ? (int) $id : null;

            if ($accountId === null) {
                $parent = null;
                foreach ($parents as $code) {
                    $parent = $live()->where('code', $code)->first();
                    if ($parent) {
                        break;
                    }
                }
                $codes = $parent ? $preferred : $legacy;
                $payload = [
                    'tenant_id' => $tenantId,
                    'parent_account_id' => $parent?->id,
                    'code' => $this->freeCode($tenantId, $codes, $parent ? (string) $parent->code : '9'),
                    'name_ar' => $name,
                    'name_en' => $name,
                    'account_group' => $group,
                    'normal_balance' => $normal,
                    'is_active' => true,
                    'is_system_protected' => true,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
                if (Schema::hasColumn('financial_accounts', 'catalog_source')) {
                    $payload['catalog_source'] = $parent?->catalog_source;
                }
                $accountId = (int) DB::table('financial_accounts')->insertGetId($payload);
            } else {
                DB::table('financial_accounts')->where('id', $accountId)->update(['is_active' => true, 'updated_at' => $now]);
            }

            DB::table('sales_account_mappings')->updateOrInsert(
                ['tenant_id' => $tenantId, 'mapping_key' => $key],
                ['financial_account_id' => $accountId, 'created_at' => $now, 'updated_at' => $now],
            );

            return $accountId;
        });
    }

    /** A new leaf account under $parentId, coded parent code + next number (e.g. 211 → 2115). */
    public function createChild(int $tenantId, int $parentId, string $name, ?string $nameEn = null): int
    {
        $parent = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $parentId)->whereNull('deleted_at')->first()
            ?? throw new RuntimeException('Parent account not found.');
        $siblings = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('parent_account_id', $parentId)
            ->pluck('code')->filter(fn ($c) => ctype_digit((string) $c) && str_starts_with((string) $c, (string) $parent->code))
            ->map(fn ($c) => (int) $c);
        $start = $siblings->isNotEmpty() ? $siblings->max() + 1 : (int) ($parent->code.'1');
        $code = null;
        for ($n = $start; $n < $start + 100000; $n++) {
            if (! DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', (string) $n)->exists()) {
                $code = (string) $n;
                break;
            }
        }
        $now = now();
        $payload = [
            'tenant_id' => $tenantId, 'parent_account_id' => $parentId, 'code' => $code ?? throw new RuntimeException('No free code.'),
            'name_ar' => $name, 'name_en' => $nameEn ?? $name, 'account_group' => $parent->account_group,
            'normal_balance' => $parent->normal_balance, 'is_active' => true, 'is_system_protected' => false,
            'created_at' => $now, 'updated_at' => $now,
        ];
        if (Schema::hasColumn('financial_accounts', 'catalog_source')) {
            $payload['catalog_source'] = $parent->catalog_source ?? null;
        }

        return (int) DB::table('financial_accounts')->insertGetId($payload);
    }

    private function freeCode(int $tenantId, array $preferred, string $prefix): string
    {
        $taken = fn (string $code): bool => DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', $code)->exists();
        foreach ($preferred as $code) {
            if (! $taken($code)) {
                return $code;
            }
        }
        for ($n = 1; $n < 100000; $n++) {
            if (! $taken($prefix.$n)) {
                return $prefix.$n;
            }
        }

        throw new RuntimeException('No free account code.');
    }
}
