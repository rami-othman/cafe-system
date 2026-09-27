<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

final class FactoryCatalogService
{
    /** Copy defaults once; subsequent cafe edits never overwrite private catalogs. */
    public function ensureForBranch(int $tenantId, int $branchId, bool $apply = true): array
    {
        return DB::transaction(function () use ($tenantId, $branchId, $apply): array {
            $created = [];
            foreach (DB::table('invoice_groups')->where('tenant_id', $tenantId)->whereNull('owner_branch_id')->get() as $group) {
                $code = 'f'.$branchId.'_'.$group->code;
                $target = DB::table('invoice_groups')->where('tenant_id', $tenantId)->where('owner_branch_id', $branchId)->where('code', $code)->first();
                if (! $target) {
                    $created[] = 'group '.$code;
                    if ($apply) {
                        $values = (array) $group;
                        unset($values['id']);
                        $target = (object) ['id' => DB::table('invoice_groups')->insertGetId(array_merge($values, ['owner_branch_id' => $branchId, 'code' => $code]))];
                    }
                }
                foreach (DB::table('invoice_types')->where('tenant_id', $tenantId)->where('invoice_group_id', $group->id)->whereNull('owner_branch_id')->get() as $type) {
                    $code = 'f'.$branchId.'_'.$type->code;
                    if (DB::table('invoice_types')->where('tenant_id', $tenantId)->where('owner_branch_id', $branchId)->where('code', $code)->exists()) continue;
                    $created[] = 'type '.$code;
                    if ($apply) {
                        $values = (array) $type;
                        unset($values['id']);
                        DB::table('invoice_types')->insert(array_merge($values, ['owner_branch_id' => $branchId, 'code' => $code, 'invoice_group_id' => $target->id]));
                    }
                }
            }
            return $created;
        });
    }
}
