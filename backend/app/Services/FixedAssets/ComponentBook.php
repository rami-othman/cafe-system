<?php

namespace App\Services\FixedAssets;

use App\Support\Money;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * The items (بنود) an asset is made of. Cost of an item = its base share of the card cost + the
 * capitalised outlays allocated to it by non-voided transactions. An outlay targets the whole asset
 * (split equally or manually across the items), or adds one new item.
 */
final class ComponentBook
{
    /** @return list<object{id:int,name:string,cost:int,expenses:int,base:int}> */
    public function active(int $tenantId, int $assetId): array
    {
        $components = DB::table('fixed_asset_components')->where('tenant_id', $tenantId)->where('fixed_asset_id', $assetId)->whereNull('voided_at')
            ->orderBy('sort_order')->orderBy('id')->get();
        if ($components->isEmpty()) {
            return [];
        }
        $lines = DB::table('fixed_asset_component_lines as l')->join('fixed_asset_transactions as t', 't.id', '=', 'l.transaction_id')
            ->where('l.tenant_id', $tenantId)->where('l.fixed_asset_id', $assetId)->whereNull('t.voided_at')
            ->groupBy('l.component_id', 'l.capitalized')->selectRaw('l.component_id, l.capitalized, COALESCE(SUM(l.amount),0) amount')->get();
        $cap = [];
        $exp = [];
        foreach ($lines as $line) {
            if ($line->capitalized) {
                $cap[(int) $line->component_id] = Money::cents((string) $line->amount);
            } else {
                $exp[(int) $line->component_id] = Money::cents((string) $line->amount);
            }
        }

        return $components->map(fn ($c) => (object) [
            'id' => (int) $c->id, 'name' => $c->name, 'base' => Money::cents((string) $c->base_cost),
            'cost' => Money::cents((string) $c->base_cost) + ($cap[(int) $c->id] ?? 0), 'expenses' => $exp[(int) $c->id] ?? 0,
        ])->all();
    }

    public function hasComponents(int $tenantId, int $assetId): bool
    {
        return DB::table('fixed_asset_components')->where('tenant_id', $tenantId)->where('fixed_asset_id', $assetId)->whereNull('voided_at')->exists();
    }

    /** Equal split of $total over $n, the odd cents going to the first parts. @return list<int> */
    public static function equalParts(int $total, int $n): array
    {
        $base = intdiv($total, $n);
        $rest = $total - $base * $n;

        return array_map(fn (int $i) => $base + ($i < $rest ? 1 : 0), range(0, $n - 1));
    }

    /**
     * Replaces the items of a DRAFT asset. $items = [{name, cost?}], mode manual (explicit costs adding up to
     * the card cost) or equal (the card cost split equally). Empty list clears the items.
     */
    public function replaceDraft(int $tenantId, int $assetId, array $items, string $mode, int $totalCents): void
    {
        DB::table('fixed_asset_components')->where('tenant_id', $tenantId)->where('fixed_asset_id', $assetId)->delete();
        if ($items === []) {
            return;
        }
        $names = [];
        foreach ($items as $i => $item) {
            $name = trim((string) ($item['name'] ?? ''));
            if ($name === '') {
                throw ValidationException::withMessages(["components.{$i}.name" => 'اسم البند مطلوب.']);
            }
            $names[] = $name;
        }
        if ($mode === 'equal') {
            $costs = self::equalParts($totalCents, count($items));
        } else {
            $costs = [];
            foreach ($items as $i => $item) {
                $cents = Money::cents((string) ($item['cost'] ?? '0'), "components.{$i}.cost");
                if ($cents < 0) {
                    throw ValidationException::withMessages(["components.{$i}.cost" => 'كلفة البند لا يمكن أن تكون سالبة.']);
                }
                $costs[] = $cents;
            }
            if (array_sum($costs) !== $totalCents) {
                throw ValidationException::withMessages(['components' => 'مجموع كلف البنود ('.Money::decimal(array_sum($costs)).') لا يساوي كلفة الأصل ('.Money::decimal($totalCents).').']);
            }
        }
        $now = now();
        foreach ($names as $i => $name) {
            DB::table('fixed_asset_components')->insert([
                'tenant_id' => $tenantId, 'fixed_asset_id' => $assetId, 'name' => $name, 'base_cost' => Money::decimal($costs[$i]),
                'sort_order' => $i, 'created_at' => $now, 'updated_at' => $now,
            ]);
        }
    }

    /** Draft asset whose card cost changed while it has items: the items must be re-split. */
    public function assertDraftBalanced(int $tenantId, int $assetId, int $totalCents): void
    {
        $sum = (int) Money::cents((string) DB::table('fixed_asset_components')->where('tenant_id', $tenantId)->where('fixed_asset_id', $assetId)->whereNull('voided_at')->sum('base_cost'));
        if ($this->hasComponents($tenantId, $assetId) && $sum !== $totalCents) {
            throw ValidationException::withMessages(['components' => 'تغيّرت كلفة الأصل؛ أعد توزيع كلفة البنود (مجموعها الحالي '.Money::decimal($sum).').']);
        }
    }

    /**
     * Allocates an outlay to the items and records it against $txId.
     * $data: scope = asset (default) | new_component; distribution = equal (default) | manual;
     *        allocations = [{componentId, amount}] (manual); componentName (new_component).
     * An asset without items needs no allocation, except when a first new item is added: the existing cost is then
     * kept as an implicit base item so the items still add up to the asset cost.
     *
     * @return string the scope that was applied (asset|component|new_component|none)
     */
    public function allocate(int $tenantId, int $assetId, int $txId, int $amountCents, bool $capitalized, array $data, int $currentCostCents): string
    {
        $scope = $data['scope'] ?? 'asset';
        $now = now();
        $record = function (int $componentId, int $cents) use ($tenantId, $assetId, $txId, $capitalized, $now): void {
            if ($cents === 0) {
                return;
            }
            DB::table('fixed_asset_component_lines')->insert([
                'tenant_id' => $tenantId, 'fixed_asset_id' => $assetId, 'component_id' => $componentId, 'transaction_id' => $txId,
                'amount' => Money::decimal($cents), 'capitalized' => $capitalized, 'created_at' => $now, 'updated_at' => $now,
            ]);
        };

        if ($scope === 'new_component') {
            $name = trim((string) ($data['componentName'] ?? ''));
            if ($name === '') {
                throw ValidationException::withMessages(['componentName' => 'اسم البند الجديد مطلوب.']);
            }
            if (! $this->hasComponents($tenantId, $assetId) && $currentCostCents > 0) {
                DB::table('fixed_asset_components')->insert([
                    'tenant_id' => $tenantId, 'fixed_asset_id' => $assetId, 'name' => 'الأصل الأساسي', 'base_cost' => Money::decimal($currentCostCents),
                    'source_transaction_id' => $txId, // implicit: removed again if this transaction is reversed
                    'sort_order' => 0, 'created_at' => $now, 'updated_at' => $now,
                ]);
            }
            $next = (int) DB::table('fixed_asset_components')->where('tenant_id', $tenantId)->where('fixed_asset_id', $assetId)->max('sort_order') + 1;
            $componentId = (int) DB::table('fixed_asset_components')->insertGetId([
                'tenant_id' => $tenantId, 'fixed_asset_id' => $assetId, 'name' => $name, 'base_cost' => '0.00', 'source_transaction_id' => $txId,
                'sort_order' => $next, 'created_at' => $now, 'updated_at' => $now,
            ]);
            $record($componentId, $amountCents);

            return 'new_component';
        }

        $components = $this->active($tenantId, $assetId);
        if ($components === []) {
            return 'none';
        }
        $distribution = $data['distribution'] ?? 'equal';
        if ($distribution === 'manual') {
            $allocations = [];
            foreach ((array) ($data['allocations'] ?? []) as $i => $row) {
                $componentId = (int) ($row['componentId'] ?? 0);
                if (! collect($components)->contains(fn ($c) => $c->id === $componentId)) {
                    throw ValidationException::withMessages(["allocations.{$i}.componentId" => 'البند غير موجود في هذا الأصل.']);
                }
                $cents = Money::cents((string) ($row['amount'] ?? '0'), "allocations.{$i}.amount");
                if ($cents < 0) {
                    throw ValidationException::withMessages(["allocations.{$i}.amount" => 'مبلغ التوزيع لا يمكن أن يكون سالبًا.']);
                }
                $allocations[$componentId] = ($allocations[$componentId] ?? 0) + $cents;
            }
            if (array_sum($allocations) !== $amountCents) {
                throw ValidationException::withMessages(['allocations' => 'مجموع التوزيع ('.Money::decimal(array_sum($allocations)).') لا يساوي المبلغ ('.Money::decimal($amountCents).').']);
            }
            foreach ($allocations as $componentId => $cents) {
                $record((int) $componentId, $cents);
            }

            return 'component';
        }
        foreach (self::equalParts($amountCents, count($components)) as $i => $cents) {
            $record($components[$i]->id, $cents);
        }

        return 'asset';
    }

    /** Items that only exist because of a transaction that is now being reversed. */
    public function voidCreatedBy(int $tenantId, int $assetId, int $txId): void
    {
        DB::table('fixed_asset_components')->where('tenant_id', $tenantId)->where('fixed_asset_id', $assetId)->where('source_transaction_id', $txId)->update(['voided_at' => now()]);
    }
}
