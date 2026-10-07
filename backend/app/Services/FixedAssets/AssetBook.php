<?php

namespace App\Services\FixedAssets;

use App\Services\SystemAccounts;
use App\Support\Money;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Read side of one asset: its effective accounts (asset override → category default) and its
 * book figures, always derived from the non-voided ledger rows (fixed_asset_transactions).
 */
final class AssetBook
{
    public const ACCOUNT_FIELDS = ['asset_account_id', 'accumulated_account_id', 'expense_account_id', 'gain_account_id', 'loss_account_id'];

    public function __construct(private readonly SystemAccounts $system) {}

    public function asset(int $tenantId, int $assetId, bool $lock = false): object
    {
        $query = DB::table('fixed_assets')->where('tenant_id', $tenantId)->where('id', $assetId)->whereNull('deleted_at');
        $asset = $lock ? $query->lockForUpdate()->first() : $query->first();
        abort_unless($asset, 404, 'الأصل غير موجود.');

        return $asset;
    }

    /** @return array{asset:?int, accumulated:?int, expense:?int, gain:?int, loss:?int} */
    public function accounts(int $tenantId, object $asset): array
    {
        $category = $asset->category_id ? DB::table('asset_categories')->where('tenant_id', $tenantId)->where('id', $asset->category_id)->first() : null;
        $pick = fn (string $field) => ($asset->{$field} ?? null) ?: ($category?->{$field} ?? null);
        $result = [
            'asset' => $pick('asset_account_id'),
            'accumulated' => $pick('accumulated_account_id'),
            'expense' => $pick('expense_account_id'),
            'gain' => $pick('gain_account_id'),
            'loss' => $pick('loss_account_id'),
        ];
        // Depreciating assets without their own / their category's expense account fall back to the
        // company-wide «مصاريف اهتلاك» expense account (adopted from the chart, or created under expenses).
        if ($result['expense'] === null && ($asset->method ?? 'straight_line') !== 'none') {
            $result['expense'] = $this->system->id($tenantId, 'assets.depreciation_expense');
        }
        $result['gain'] ??= $this->system->id($tenantId, 'assets.gain');
        $result['loss'] ??= $this->system->id($tenantId, 'assets.loss');

        return array_map(fn ($v) => $v === null ? null : (int) $v, $result);
    }

    public function requireAccounts(int $tenantId, object $asset, array $keys): array
    {
        $accounts = $this->accounts($tenantId, $asset);
        $labels = ['asset' => 'حساب الأصل', 'accumulated' => 'حساب مجمع الاهتلاك', 'expense' => 'حساب مصروف الاهتلاك', 'gain' => 'حساب الأرباح الرأسمالية', 'loss' => 'حساب الخسائر الرأسمالية'];
        foreach ($keys as $key) {
            if (! $accounts[$key]) {
                throw ValidationException::withMessages(['accounts' => "حدد {$labels[$key]} في صنف الأصل أو في بطاقة الأصل."]);
            }
        }

        return $accounts;
    }

    /** @return array{cost:int, accumulated:int, lifeChange:int} cents, as of $asOf (inclusive) or all time */
    public function totals(int $tenantId, int $assetId, ?string $asOf = null): array
    {
        $row = DB::table('fixed_asset_transactions')->where('tenant_id', $tenantId)->where('fixed_asset_id', $assetId)->whereNull('voided_at')
            ->when($asOf !== null, fn ($q) => $q->where('transaction_date', '<=', $asOf))
            ->selectRaw('COALESCE(SUM(cost_amount),0) cost, COALESCE(SUM(depreciation_amount),0) acc, COALESCE(SUM(life_change_months),0) life')->first();

        return ['cost' => Money::cents((string) $row->cost), 'accumulated' => Money::cents((string) $row->acc), 'lifeChange' => (int) $row->life];
    }

    /** Totals for many assets in one query: assetId => totals. */
    public function totalsMany(int $tenantId, array $assetIds, ?string $asOf = null): array
    {
        if ($assetIds === []) {
            return [];
        }
        $rows = DB::table('fixed_asset_transactions')->where('tenant_id', $tenantId)->whereIn('fixed_asset_id', $assetIds)->whereNull('voided_at')
            ->when($asOf !== null, fn ($q) => $q->where('transaction_date', '<=', $asOf))
            ->groupBy('fixed_asset_id')
            ->selectRaw('fixed_asset_id, COALESCE(SUM(cost_amount),0) cost, COALESCE(SUM(depreciation_amount),0) acc, COALESCE(SUM(life_change_months),0) life')->get();
        $out = [];
        foreach ($rows as $row) {
            $out[(int) $row->fixed_asset_id] = ['cost' => Money::cents((string) $row->cost), 'accumulated' => Money::cents((string) $row->acc), 'lifeChange' => (int) $row->life];
        }

        return $out;
    }

    public function latestTransaction(int $tenantId, int $assetId): ?object
    {
        return DB::table('fixed_asset_transactions')->where('tenant_id', $tenantId)->where('fixed_asset_id', $assetId)->whereNull('voided_at')
            ->orderByDesc('transaction_date')->orderByDesc('id')->first();
    }
}
