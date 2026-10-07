<?php

namespace App\Services\FixedAssets;

use App\Services\SystemAccounts;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** Categories (default accounts + depreciation policy), sub-locations and module settings. */
final class AssetCatalogService
{
    public const FREQUENCIES = ['monthly' => 1, 'quarterly' => 3, 'semiannual' => 6, 'annual' => 12];

    public function __construct(private readonly SystemAccounts $system) {}

    // ---------------------------------------------------------------- settings

    public function settings(int $tenantId): array
    {
        $row = DB::table('fixed_asset_settings')->where('tenant_id', $tenantId)->first();
        $frequency = $row->depreciation_frequency ?? 'monthly';

        return [
            'depreciationFrequency' => $frequency,
            'defaultMethod' => $row->default_method ?? 'straight_line',
            'suggestedPeriodEnd' => $this->suggestedPeriodEnd($tenantId, $frequency),
            'lastRunPeriodEnd' => DB::table('depreciation_runs')->where('tenant_id', $tenantId)->where('status', 'posted')->where('trigger', 'manual')->max('period_end'),
        ];
    }

    public function saveSettings(int $tenantId, array $data, ?int $actorId): void
    {
        if (! isset(self::FREQUENCIES[$data['depreciationFrequency']])) {
            throw ValidationException::withMessages(['depreciationFrequency' => 'دورية غير مدعومة.']);
        }
        DB::table('fixed_asset_settings')->updateOrInsert(['tenant_id' => $tenantId], [
            'depreciation_frequency' => $data['depreciationFrequency'],
            'default_method' => $data['defaultMethod'] ?? 'straight_line',
            'updated_by' => $actorId, 'updated_at' => now(), 'created_at' => now(),
        ]);
    }

    /** The end of the latest COMPLETED period for the chosen frequency (or today when today closes a period). */
    public function suggestedPeriodEnd(int $tenantId, ?string $frequency = null): string
    {
        $frequency ??= DB::table('fixed_asset_settings')->where('tenant_id', $tenantId)->value('depreciation_frequency') ?? 'monthly';
        $months = self::FREQUENCIES[$frequency] ?? 1;
        $today = CarbonImmutable::today();
        $quarterEnd = fn (CarbonImmutable $d) => $d->month((int) (ceil($d->month / $months) * $months))->endOfMonth();
        $current = $quarterEnd($today);
        if ($current->isSameDay($today)) {
            return $today->toDateString();
        }

        return $quarterEnd($today->startOfMonth()->subMonthsNoOverflow($months))->toDateString();
    }

    // ---------------------------------------------------------------- categories

    public function categories(int $tenantId): array
    {
        $accounts = DB::table('financial_accounts')->where('tenant_id', $tenantId)->get(['id', 'code', 'name_ar'])->keyBy('id');
        $counts = DB::table('fixed_assets')->where('tenant_id', $tenantId)->whereNull('deleted_at')->groupBy('category_id')->selectRaw('category_id, COUNT(*) c')->pluck('c', 'category_id');
        $acc = fn ($id) => $id && isset($accounts[$id]) ? ['id' => (int) $id, 'code' => $accounts[$id]->code, 'name' => $accounts[$id]->name_ar] : null;

        return DB::table('asset_categories')->where('tenant_id', $tenantId)->whereNull('deleted_at')->orderBy('code')->get()
            ->map(fn ($c) => [
                'id' => (int) $c->id, 'parentId' => $c->parent_id ? (int) $c->parent_id : null, 'code' => $c->code,
                'nameAr' => $c->name_ar, 'nameEn' => $c->name_en, 'isActive' => (bool) $c->is_active,
                'defaultMethod' => $c->default_method, 'defaultLifeMonths' => $c->default_life_months !== null ? (int) $c->default_life_months : null,
                'defaultSalvagePercent' => (string) $c->default_salvage_percent,
                'assetAccount' => $acc($c->asset_account_id), 'accumulatedAccount' => $acc($c->accumulated_account_id),
                'expenseAccount' => $acc($c->expense_account_id), 'gainAccount' => $acc($c->gain_account_id), 'lossAccount' => $acc($c->loss_account_id),
                'assetsCount' => (int) ($counts[$c->id] ?? 0),
            ])->values()->all();
    }

    public function saveCategory(int $tenantId, array $data, ?int $id, ?int $actorId): int
    {
        $code = trim((string) ($data['code'] ?? ''));
        if ($code === '') {
            $code = (string) ((DB::table('asset_categories')->where('tenant_id', $tenantId)->pluck('code')->filter(fn ($c) => ctype_digit((string) $c))->map(fn ($c) => (int) $c)->max() ?? 0) + 1);
        }
        if (DB::table('asset_categories')->where('tenant_id', $tenantId)->where('code', $code)->when($id, fn ($q) => $q->where('id', '!=', $id))->exists()) {
            throw ValidationException::withMessages(['code' => 'رمز الصنف مستخدم.']);
        }
        if (! empty($data['parentId'])) {
            if ((int) $data['parentId'] === $id || ! DB::table('asset_categories')->where('tenant_id', $tenantId)->where('id', $data['parentId'])->whereNull('deleted_at')->exists()) {
                throw ValidationException::withMessages(['parentId' => 'الصنف الأب غير صالح.']);
            }
        }
        $method = $data['defaultMethod'] ?? 'straight_line';
        if (! in_array($method, DepreciationCalculator::METHODS, true)) {
            throw ValidationException::withMessages(['defaultMethod' => 'طريقة اهتلاك غير مدعومة.']);
        }
        $payload = [
            'parent_id' => $data['parentId'] ?? null, 'code' => $code, 'name_ar' => trim((string) $data['nameAr']), 'name_en' => $data['nameEn'] ?? null,
            'default_method' => $method, 'default_life_months' => $data['defaultLifeMonths'] ?? null,
            'default_salvage_percent' => $data['defaultSalvagePercent'] ?? 0, 'is_active' => (bool) ($data['isActive'] ?? true), 'updated_at' => now(),
        ];
        $groups = ['assetAccountId' => ['asset_account_id', 'assets'], 'accumulatedAccountId' => ['accumulated_account_id', 'assets'], 'expenseAccountId' => ['expense_account_id', 'expenses'], 'gainAccountId' => ['gain_account_id', 'revenue'], 'lossAccountId' => ['loss_account_id', 'expenses']];
        foreach ($groups as $in => [$column, $group]) {
            $value = $data[$in] ?? null;
            if ($value) {
                $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $value)->where('is_active', true)->whereNull('deleted_at')->first();
                if (! $account) {
                    throw ValidationException::withMessages([$in => 'الحساب غير موجود أو غير مفعّل.']);
                }
                if ($account->account_group !== $group && ! ($group === 'expenses' && $account->account_group === 'cost_of_sales')) {
                    throw ValidationException::withMessages([$in => 'الحساب من مجموعة غير مناسبة لهذا الحقل.']);
                }
            }
            $payload[$column] = $value ?: null;
        }
        if ($payload['asset_account_id'] && $payload['asset_account_id'] === $payload['accumulated_account_id']) {
            throw ValidationException::withMessages(['accumulatedAccountId' => 'حساب المجمع يجب أن يختلف عن حساب الأصل.']);
        }
        if ($id) {
            $exists = DB::table('asset_categories')->where('tenant_id', $tenantId)->where('id', $id)->whereNull('deleted_at')->exists();
            abort_unless($exists, 404, 'الصنف غير موجود.');
            DB::table('asset_categories')->where('id', $id)->update($payload);

            return $id;
        }

        return (int) DB::table('asset_categories')->insertGetId($payload + ['tenant_id' => $tenantId, 'created_by' => $actorId, 'created_at' => now()]);
    }

    public function deleteCategory(int $tenantId, int $id): void
    {
        if (DB::table('fixed_assets')->where('tenant_id', $tenantId)->where('category_id', $id)->whereNull('deleted_at')->exists()) {
            throw ValidationException::withMessages(['category' => 'لا يمكن حذف صنف عليه أصول.']);
        }
        if (DB::table('asset_categories')->where('tenant_id', $tenantId)->where('parent_id', $id)->whereNull('deleted_at')->exists()) {
            throw ValidationException::withMessages(['category' => 'لا يمكن حذف صنف له أصناف فرعية.']);
        }
        DB::table('asset_categories')->where('tenant_id', $tenantId)->where('id', $id)->update(['deleted_at' => now()]);
    }

    /**
     * Builds categories from the chart: every child G of "11 الموجودات الثابتة" becomes a category;
     * its child named "مجمع …" is the accumulated account, the other child is the asset account,
     * and the matching "مصروف اهتلاك …" under 515 is the expense account. Idempotent by code.
     */
    public function seedFromChart(int $tenantId, ?int $actorId = null): int
    {
        $root = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '11')->whereNull('deleted_at')->first();
        if (! $root) {
            return 0;
        }
        $gain = $this->system->id($tenantId, 'assets.gain');
        $loss = $this->system->id($tenantId, 'assets.loss');
        $expenseParent = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '515')->whereNull('deleted_at')->first();
        $expenses = $expenseParent ? DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('parent_account_id', $expenseParent->id)->whereNull('deleted_at')->get(['id', 'name_ar']) : collect();
        $created = 0;
        foreach (DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('parent_account_id', $root->id)->whereNull('deleted_at')->orderBy('code')->get() as $group) {
            if (DB::table('asset_categories')->where('tenant_id', $tenantId)->where('code', $group->code)->exists()) {
                continue;
            }
            $children = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('parent_account_id', $group->id)->whereNull('deleted_at')->get(['id', 'name_ar']);
            $accumulated = $children->first(fn ($c) => str_starts_with($this->norm($c->name_ar), 'مجمع'));
            $asset = $children->first(fn ($c) => ! str_starts_with($this->norm($c->name_ar), 'مجمع'));
            $label = trim(preg_replace('/^صافي\s+/u', '', $group->name_ar));
            $needle = $this->norm($label);
            $expense = $expenses->first(function ($e) use ($needle) {
                $name = $this->norm(preg_replace('/^مصروف\s+اهتلاك\s+/u', '', $e->name_ar));

                return $name !== '' && (str_contains($needle, $name) || str_contains($name, $needle));
            });
            DB::table('asset_categories')->insert([
                'tenant_id' => $tenantId, 'code' => (string) $group->code, 'name_ar' => $label, 'name_en' => null,
                'asset_account_id' => $asset->id ?? $group->id, 'accumulated_account_id' => $accumulated?->id,
                'expense_account_id' => $expense?->id, 'gain_account_id' => $gain, 'loss_account_id' => $loss,
                'default_method' => $accumulated ? 'straight_line' : 'none', 'default_life_months' => null,
                'default_salvage_percent' => 0, 'is_active' => true, 'created_by' => $actorId, 'created_at' => now(), 'updated_at' => now(),
            ]);
            $created++;
        }

        return $created;
    }

    // ---------------------------------------------------------------- locations

    public function locations(int $tenantId): array
    {
        $branches = DB::table('branches')->where('tenant_id', $tenantId)->pluck('name', 'id');

        return DB::table('asset_locations')->where('tenant_id', $tenantId)->whereNull('deleted_at')->orderBy('branch_id')->orderBy('name')->get()
            ->map(fn ($l) => ['id' => (int) $l->id, 'branchId' => $l->branch_id ? (int) $l->branch_id : null,
                'branchName' => $l->branch_id ? ($branches[$l->branch_id] ?? null) : 'الإدارة العامة', 'name' => $l->name, 'isActive' => (bool) $l->is_active,
                'assetsCount' => DB::table('fixed_assets')->where('tenant_id', $tenantId)->where('location_id', $l->id)->whereNull('deleted_at')->count()])->values()->all();
    }

    public function saveLocation(int $tenantId, array $data, ?int $id): int
    {
        $branch = ! empty($data['branchId']) ? (int) $data['branchId'] : null;
        if ($branch && ! DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branch)->exists()) {
            throw ValidationException::withMessages(['branchId' => 'الفرع غير موجود.']);
        }
        $payload = ['branch_id' => $branch, 'name' => trim((string) $data['name']), 'is_active' => (bool) ($data['isActive'] ?? true), 'updated_at' => now()];
        if ($id) {
            $location = DB::table('asset_locations')->where('tenant_id', $tenantId)->where('id', $id)->whereNull('deleted_at')->first();
            abort_unless($location, 404);
            if (($location->branch_id ? (int) $location->branch_id : null) !== $branch
                && DB::table('fixed_assets')->where('tenant_id', $tenantId)->where('location_id', $id)->whereNull('deleted_at')->exists()) {
                throw ValidationException::withMessages(['branchId' => 'لا يمكن تغيير فرع موقع عليه أصول؛ انقل الأصول أولًا.']);
            }
            DB::table('asset_locations')->where('id', $id)->update($payload);

            return $id;
        }

        return (int) DB::table('asset_locations')->insertGetId($payload + ['tenant_id' => $tenantId, 'created_at' => now()]);
    }

    private function norm(string $value): string
    {
        return trim(str_replace(['أ', 'إ', 'آ', 'ة', 'ى'], ['ا', 'ا', 'ا', 'ه', 'ي'], $value));
    }
}
