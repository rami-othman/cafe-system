<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * In the Phoenix chart a cash box simply IS an account under group 13 "الأموال الجاهزة".
 * This keeps the operational cash location (used by shifts, transfers and the POS) in lock-step with
 * those accounts so nobody creates a box separately: create the account, the box exists.
 * Linking the POS to a box (see BranchController) is what turns it into that branch's drawer.
 */
final class CashBoxSyncService
{
    public const GROUP_CODE = '13';

    /** Creates (or refreshes the name of) the location of an account that sits directly under group 13. */
    public function ensureForAccount(int $tenantId, int $accountId, ?int $actorId = null): ?int
    {
        $account = DB::table('financial_accounts as a')
            ->join('financial_accounts as p', 'p.id', '=', 'a.parent_account_id')
            ->where('a.tenant_id', $tenantId)->where('a.id', $accountId)->whereNull('a.deleted_at')
            ->where('p.tenant_id', $tenantId)->where('p.code', self::GROUP_CODE)->where('a.catalog_source', 'phinix')
            ->first(['a.id', 'a.code', 'a.name_ar', 'a.is_active']);
        if (! $account) {
            return null;
        }
        $existing = DB::table('financial_locations')->where('tenant_id', $tenantId)->where('financial_account_id', $account->id)->orderBy('id')->get(['id', 'name']);
        if ($existing->count() === 1 && $existing[0]->name !== $account->name_ar) {
            DB::table('financial_locations')->where('id', $existing[0]->id)->update(['name' => $account->name_ar, 'updated_at' => now()]);
        }
        if ($existing->isNotEmpty()) {
            return (int) $existing[0]->id;
        }
        $isBank = str_contains((string) $account->name_ar, 'بنك');
        $code = strtoupper((string) $account->code);
        if (DB::table('financial_locations')->where('tenant_id', $tenantId)->where('code', $code)->exists()) {
            $code = 'ACC-'.$code;
        }

        return (int) DB::table('financial_locations')->insertGetId([
            'tenant_id' => $tenantId, 'branch_id' => null, 'financial_account_id' => (int) $account->id,
            'code' => substr($code, 0, 40), 'name' => $account->name_ar,
            'kind' => $isBank ? 'bank' : 'cash', 'type' => $isBank ? 'bank' : 'main_safe',
            'bank_name' => $isBank ? $account->name_ar : null, 'is_active' => (bool) $account->is_active,
            'created_by' => $actorId, 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    /** Registers every account under group 13 that has no location yet. @return int how many were created */
    public function syncTenant(int $tenantId, ?int $actorId = null): int
    {
        $parent = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', self::GROUP_CODE)->whereNull('deleted_at')->value('id');
        if (! $parent) {
            return 0;
        }
        $created = 0;
        foreach (DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('parent_account_id', $parent)->whereNull('deleted_at')->pluck('id') as $accountId) {
            $had = DB::table('financial_locations')->where('tenant_id', $tenantId)->where('financial_account_id', $accountId)->exists();
            if ($this->ensureForAccount($tenantId, (int) $accountId, $actorId) !== null && ! $had) {
                $created++;
            }
        }

        return $created;
    }

    /** An account whose box serves a POS drawer or a shift-close destination must not be switched off. */
    public function assertCanDeactivate(int $tenantId, int $accountId): void
    {
        $ids = DB::table('financial_locations')->where('tenant_id', $tenantId)->where('financial_account_id', $accountId)->pluck('id');
        if ($ids->isEmpty()) {
            return;
        }
        $inUse = DB::table('branches')->where('tenant_id', $tenantId)->whereNull('deleted_at')->where(fn ($q) => $q
            ->whereIn('pos_cash_financial_location_id', $ids)->orWhereIn('shift_close_destination_financial_location_id', $ids))->exists();
        if ($inUse) {
            throw ValidationException::withMessages(['isActive' => 'هذا الحساب صندوق مربوط بنقطة بيع أو بوجهة إغلاق وردية. غيّر الربط أولاً.']);
        }
    }

    /**
     * Linking a POS to a box makes it that branch's drawer: a free (unassigned) box becomes the branch's drawer.
     * Does nothing when the box is not free; the readiness check then reports the problem as before.
     */
    public function adoptAsDrawer(int $tenantId, int $branchId, int $locationId): void
    {
        $loc = DB::table('financial_locations')->where('tenant_id', $tenantId)->where('id', $locationId)->where('kind', 'cash')->where('is_active', true)->first();
        if (! $loc || $loc->type === 'cash_drawer' || $loc->branch_id !== null) {
            return;
        }
        $isDestination = DB::table('branches')->where('tenant_id', $tenantId)->where('shift_close_destination_financial_location_id', $locationId)->exists();
        $isOtherDrawer = DB::table('branches')->where('tenant_id', $tenantId)->where('pos_cash_financial_location_id', $locationId)->where('id', '<>', $branchId)->exists();
        if ($isDestination || $isOtherDrawer) {
            return;
        }
        DB::table('financial_locations')->where('id', $locationId)->update(['type' => 'cash_drawer', 'branch_id' => $branchId, 'updated_at' => now()]);
    }
}
