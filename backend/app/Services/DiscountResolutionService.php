<?php

namespace App\Services;

use App\Exceptions\OrderLifecycleException;
use Brick\Math\BigDecimal;
use Brick\Math\BigInteger;
use Brick\Math\RoundingMode;
use Illuminate\Support\Facades\DB;

/** Pure resolution of persisted context; callers own the order transaction. */
final class DiscountResolutionService
{
    public function __construct(private readonly DiscountEligibilityService $eligibility, private readonly DiscountSettingsService $settings) {}

    public function lock(int $tenantId): void
    {
        // Also used by settings and every policy writer. Covers absent settings
        // and phantom policies without taking a tenant FK/numbering row lock.
        DB::select('select pg_advisory_xact_lock(?, ?)', [20402, $tenantId]);
    }

    public function isolatedAutomatic(): bool
    {
        return app()->environment('testing') && config('discount_engine.isolated_automatic') === true
            && in_array(DB::selectOne('select current_database() as name')->name, ['cafe_system_618_testing', 'cafe_system_618_testing_migrations'], true);
    }

    public function automatic(int $tenantId): bool
    {
        return $this->settings->read($tenantId)['automaticEnabled'] || $this->isolatedAutomatic();
    }

    public function active(int $tenantId, int $orderId): bool
    {
        return $this->requiresContract($tenantId) || DB::table('order_discount_intents')->where('tenant_id', $tenantId)->where('order_id', $orderId)->exists()
            || DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $orderId)->whereNotNull('source')->exists();
    }

    public function requiresContract(int $tenantId): bool
    {
        $settings = $this->settings->read($tenantId);

        return $this->automatic($tenantId) || $settings['combinationMode'] !== 'single'
            || $settings['maximumTotalDiscountPercent'] !== null;
    }

    /**
     * Saved explicit intent: the legacy single object, or (V3) an ordered list.
     * Callers pass it straight back to resolve(), which accepts both shapes.
     */
    public function intent(int $tenantId, int $orderId): ?array
    {
        $stored = DB::table('order_discount_intents')->where('tenant_id', $tenantId)->where('order_id', $orderId)->value('intent');
        if ($stored !== null) {
            return json_decode($stored, true, flags: JSON_THROW_ON_ERROR);
        }
        $rows = DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $orderId)->where(fn ($q) => $q->whereNull('source')->orWhere('source', '!=', 'automatic'))
            ->orderByRaw('coalesce(application_sequence, 0), id')->get();
        if ($rows->isEmpty()) {
            return null;
        }
        $modes = DB::table('discounts')->where('tenant_id', $tenantId)->whereIn('id', $rows->pluck('discount_id')->filter()->all())->pluck('application_mode', 'id');
        $intents = [];
        foreach ($rows as $legacy) {
            $intents[] = $legacy->discount_id !== null
                ? ['source' => ($modes[$legacy->discount_id] ?? null) === 'code' ? 'code' : 'configured_manual', 'discountId' => (int) $legacy->discount_id]
                : ['source' => 'ad_hoc', 'type' => $legacy->discount_type, 'value' => (string) $legacy->discount_value, 'name' => $legacy->discount_name];
        }

        return count($intents) === 1 ? $intents[0] : $intents;
    }

    /** Normalizes a stored/requested intent (single object, list or null) to an ordered list. */
    public function intents(?array $intent): array
    {
        if ($intent === null || $intent === []) {
            return [];
        }
        $list = array_key_exists('source', $intent) ? [$intent] : array_values($intent);

        // Key order of stored JSON is not significant; hashes must not depend on it.
        return array_map(function (array $one): array {
            ksort($one);

            return $one;
        }, $list);
    }

    public function resolve(int $tenantId, object $order, ?array $intent, ?object $method = null, bool $strict = true, ?array $suppressionOverride = null): array
    {
        $this->lock($tenantId);
        $settings = $this->settings->read($tenantId);
        $items = DB::table('order_items')->where('tenant_id', $tenantId)->where('order_id', $order->id)->whereNull('deleted_at')->orderBy('id')->get();
        $balances = [];
        foreach ($items as $item) {
            $balances[(int) $item->id] = $this->cents($item->total);
        }
        $subtotal = array_sum($balances);
        $order = clone $order;
        $order->subtotal = $this->decimal($subtotal);
        $budget = $settings['maximumTotalDiscountPercent'] === null ? $subtotal
            : $this->cents(BigDecimal::of($order->subtotal)->multipliedBy((string) $settings['maximumTotalDiscountPercent'])->exactlyDividedBy(100));
        $budget = min($budget, $subtotal);
        $policies = DB::table('discounts')->where('tenant_id', $tenantId)->whereNull('deleted_at')->orderBy('id')->lockForUpdate()->get();
        $suppressed = $suppressionOverride ?? DB::table('order_discount_suppressions')->where('tenant_id', $tenantId)->where('order_id', $order->id)->orderBy('discount_id')->pluck('discount_id')->all();
        $requested = $this->intents($intent);
        $excluded = [];
        if (count($requested) > 1) {
            ['selected' => $selected, 'excluded' => $excluded, 'reasons' => $reasons, 'provisional' => $provisional] = $this->resolveSet($tenantId, $order, $requested, $method, $strict, $settings, $items, $balances, $budget, $policies);
        } else {
            [$selected, $reasons, $provisional] = $this->selectSingle($tenantId, $order, $requested[0] ?? null, $method, $strict, $settings, $items, $balances, $budget, $policies, $suppressed);
        }
        $discounts = [];
        $allocated = array_fill_keys(array_keys($balances), 0);
        foreach ($selected as $index => $row) {
            $policy = $row['policy'];
            $allocations = [];
            foreach ($row['allocations'] as $id => $amount) {
                $allocated[$id] += $amount;
                if ($allocated[$id] > $balances[$id] || $amount < 0) {
                    throw new \LogicException('Discount allocation exceeds line balance.');
                }
                $allocations[] = ['orderItemId' => $id, 'amount' => $this->decimal($amount)];
            }
            if (array_sum($row['allocations']) !== $row['amount']) {
                throw new \LogicException('Discount allocation total mismatch.');
            }
            $discounts[] = ['discountId' => $policy->id === null ? null : (int) $policy->id, 'source' => $row['source'], 'stage' => in_array($policy->scope, ['product', 'category'], true) ? 'items' : 'order', 'name' => $policy->name, 'type' => $policy->type, 'value' => (string) $policy->value, 'amount' => $this->decimal($row['amount']), 'priority' => (int) ($policy->priority ?? 0), 'fixedAmountBasis' => $policy->fixed_amount_basis, 'applicationMode' => $policy->application_mode, 'scope' => $policy->scope, 'sequence' => $index + 1, 'combinationBehavior' => $policy->combination_behavior ?? 'follow_cafe_policy', 'capped' => (bool) ($row['capped'] ?? false), 'allocations' => $allocations];
        }
        $totalDiscount = array_sum(array_column($selected, 'amount'));
        if ($totalDiscount > $subtotal || $totalDiscount > $budget) {
            throw new \LogicException('Discount exceeds budget.');
        }
        $tax = $this->cents(BigDecimal::of($this->decimal($subtotal - $totalDiscount))->multipliedBy((string) $order->tax_rate));
        $totals = ['subtotal' => $this->decimal($subtotal), 'discountTotal' => $this->decimal($totalDiscount), 'taxTotal' => $this->decimal($tax), 'total' => $this->decimal($subtotal - $totalDiscount + $tax)];
        // Excluded candidates are reported in the legacy reasons list as well.
        foreach ($excluded as $row) {
            $reasons[] = ['discountId' => $row['discountId'], 'code' => $row['code']];
        }
        $result = ['discounts' => $discounts, 'totals' => $totals, 'settingsVersion' => $settings['version'], 'provisional' => $provisional, 'reasons' => $reasons,
            'requested' => array_map(fn (array $one, int $position): array => ['position' => $position + 1, 'source' => $one['source'] ?? null, 'discountId' => isset($one['discountId']) ? (int) $one['discountId'] : null], $requested, array_keys($requested)),
            'excluded' => $excluded, 'policy' => DiscountSettingsService::effectivePolicy($settings)];
        $result['fingerprint'] = $this->fingerprint($tenantId, $order, $requested, $method, $result, $policies->all(), $items->all(), $suppressed);

        return $result;
    }

    /** Legacy engine selection: at most one explicit intent plus Automatic candidates. */
    private function selectSingle(int $tenantId, object $order, ?array $intent, ?object $method, bool $strict, array $settings, $items, array $balances, int $budget, $policies, array $suppressed): array
    {
        $candidates = [];
        $explicit = null;
        $reasons = [];
        $provisional = false;
        foreach ($policies as $policy) {
            $isExplicit = $intent !== null && ($intent['discountId'] ?? null) === (int) $policy->id;
            if (! $isExplicit && ($policy->application_mode !== 'automatic' || ! $this->automatic($tenantId))) {
                continue;
            }
            if ($isExplicit && (($intent['source'] === 'code' && $policy->application_mode !== 'code') || ($intent['source'] === 'configured_manual' && $policy->application_mode !== 'manual'))) {
                if ($strict) {
                    throw new OrderLifecycleException('DISCOUNT_APPLICATION_MODE_INVALID', 'Review the selected discount again.');
                }

                continue;
            }
            if (! $isExplicit && in_array($policy->id, $suppressed)) {
                $reasons[] = ['discountId' => (int) $policy->id, 'code' => 'DISCOUNT_SUPPRESSED'];

                continue;
            }
            $restricted = $this->tenderRestricted($tenantId, $policy);
            try {
                $full = $this->eligibility->assertApplicable($tenantId, $policy, $order, $method?->paymentMethodId, $method?->type);
                if ($method === null && $restricted && ($isExplicit || $this->cents($full['amount']) > 0)) {
                    $provisional = true;
                    $reasons[] = ['discountId' => (int) $policy->id, 'code' => 'DISCOUNT_TENDER_PENDING'];
                    if (! $isExplicit) {
                        continue;
                    }
                }
                $weights = [];
                foreach ($this->eligibility->eligibleItems($tenantId, $order, $policy)->orderBy('order_items.id')->get(['order_items.*']) as $item) {
                    $weights[(int) $item->id] = ['balance' => $this->decimal($balances[(int) $item->id]), 'quantity' => (string) $item->quantity];
                }
                if ($policy->scope === 'bundle') {
                    $weights = $this->bundleWeights($tenantId, $order, $policy, $items, $balances);
                }
                $candidate = ['policy' => $policy, 'source' => $isExplicit ? $intent['source'] : 'automatic', 'weights' => $weights, 'bundleAmount' => $this->cents($full['amount'])];
                if ($isExplicit) {
                    $explicit = $candidate;
                } else {
                    $candidates[] = $candidate;
                }
            } catch (OrderLifecycleException $e) {
                if ($isExplicit && $strict) {
                    throw $e;
                }
                $reasons[] = ['discountId' => (int) $policy->id, 'code' => $e->domainCode];
            }
        }
        if ($intent !== null && $intent['source'] !== 'ad_hoc' && $explicit === null && $strict) {
            throw new OrderLifecycleException('DISCOUNT_INACTIVE', 'Review the selected discount again.');
        }
        if ($intent !== null && $intent['source'] !== 'ad_hoc' && $explicit === null) {
            // Cart changes can invalidate an explicit policy, but must never
            // replace that persisted intent with an Automatic offer. Payment
            // remains strict until the actor reviews/removes the intent.
            $candidates = [];
            $reasons[] = ['discountId' => $intent['discountId'], 'code' => 'DISCOUNT_REVIEW_REQUIRED'];
        }
        if (($intent['source'] ?? null) === 'ad_hoc') {
            $explicit = ['policy' => (object) ['id' => null, 'name' => $intent['name'] ?? 'POS Discount', 'type' => $intent['type'], 'value' => $intent['value'], 'scope' => 'order', 'fixed_amount_basis' => 'per_order', 'maximum_discount_amount' => null, 'priority' => 0, 'application_mode' => 'manual'], 'source' => 'ad_hoc', 'weights' => []];
            foreach ($items as $item) {
                $explicit['weights'][(int) $item->id] = ['balance' => $this->decimal($balances[(int) $item->id]), 'quantity' => (string) $item->quantity];
            }
        }
        $behavior = ($intent['source'] ?? null) === 'code' ? $settings['couponBehavior'] : $settings['manualBehavior'];
        $exclusiveIntent = $explicit !== null && ($settings['combinationMode'] === 'single' || $behavior === 'exclusive' || $explicit['policy']->scope === 'bundle'
            || ($explicit['policy']->scope === 'order' && $settings['orderDiscountBehavior'] === 'exclusive'));
        if ($exclusiveIntent) {
            $selected = [$this->score($explicit, $balances, $budget)];
        } elseif ($settings['combinationMode'] === 'single') {
            $best = $this->best($candidates, $balances, $budget, $settings['selectionStrategy']);
            $selected = $best === null ? [] : [$best];
        } else {
            $remaining = $balances;
            $left = $budget;
            $selected = [];
            if ($explicit !== null && $explicit['policy']->scope !== 'order') {
                $selected[] = $this->score($explicit, $remaining, $left);
                $this->reserve($selected[0], $remaining, $left, true);
            }
            $itemCandidates = array_values(array_filter($candidates, fn ($c) => in_array($c['policy']->scope, ['product', 'category'], true)));
            while ($left > 0 && ($best = $this->best($itemCandidates, $remaining, $left, $settings['selectionStrategy'])) !== null) {
                $selected[] = $best;
                $this->reserve($best, $remaining, $left, true);
                $itemCandidates = array_values(array_filter($itemCandidates, fn ($c) => $c['policy']->id !== $best['policy']->id));
            }
            $orderCandidates = array_values(array_filter($candidates, fn ($c) => $c['policy']->scope === 'order'));
            if ($settings['orderDiscountBehavior'] === 'after_items') {
                // Reservations prevent item overlap; order stage uses actual
                // residual balances, rather than the reserved identity map.
                $residual = $balances;
                foreach ($selected as $row) {
                    foreach ($row['allocations'] as $id => $amount) {
                        $residual[$id] -= $amount;
                    }
                }
                $best = $explicit !== null && $explicit['policy']->scope === 'order'
                    ? $this->score($explicit, $residual, $left)
                    : $this->best($orderCandidates, $residual, $left, $settings['selectionStrategy']);
                if ($best !== null) {
                    $selected[] = $best;
                }
            } elseif ($explicit === null) {
                $best = $this->best(array_values(array_filter($candidates, fn ($c) => in_array($c['policy']->scope, ['order', 'bundle'], true))), $balances, $budget, $settings['selectionStrategy']);
                if ($best !== null && ($selected === [] || $this->compareGroups([$best], $selected, $settings['selectionStrategy']) < 0)) {
                    $selected = [$best];
                }
            }
            // Bundle always exclusive, including after_items; compare only
            // automatic alternatives when there is no explicit intent.
            if ($explicit === null && $settings['orderDiscountBehavior'] === 'after_items') {
                $bundle = $this->best(array_values(array_filter($candidates, fn ($c) => $c['policy']->scope === 'bundle')), $balances, $budget, $settings['selectionStrategy']);
                if ($bundle !== null && ($selected === [] || $this->compareGroups([$bundle], $selected, $settings['selectionStrategy']) < 0)) {
                    $selected = [$bundle];
                }
            }
        }

        return [$selected, $reasons, $provisional];
    }

    public const MAX_REQUESTED_INTENTS = 10;

    /**
     * Discount System V3: a reviewed set of two or more explicit intents
     * resolved against the Cafe Discount Policy. Automatic candidates are not
     * discovered here (Automatic Discounts are out of scope for V3).
     *
     * Rules, in this order of precedence:
     *  1. A duplicate or malformed intent is rejected. An individually
     *     ineligible discount throws when $strict (payment, apply, preview) and
     *     is reported as excluded otherwise (draft cart recalculation).
     *  2. Structural policy (violation()): multiple discounts, exclusivity,
     *     maximum count, multiple coupons, coupon + configured, item + order.
     *     conflictResolution picks which requested discounts are retained:
     *     best_saving keeps the compatible subset with the highest total saving;
     *     priority keeps compatible discounts greedily by priority (higher
     *     number wins, then lower discount id).
     *  3. The retained set is applied in one authoritative sequence: item-level
     *     discounts before order-level ones, reviewed order within each level.
     *     Each discount is calculated on what the previous ones left (sequential
     *     stacking), clamped to the shared maximumTotalDiscountPercent budget.
     *  4. different_items_only: a discount cannot touch an item already
     *     discounted by an earlier one (an order-level discount may follow
     *     item-level ones when allowOrderAfterItemDiscounts). It is calculated
     *     on the disjoint remainder, or excluded when none remains.
     */
    private function resolveSet(int $tenantId, object $order, array $requested, ?object $method, bool $strict, array $settings, $items, array $balances, int $budget, $policies): array
    {
        if (count($requested) > self::MAX_REQUESTED_INTENTS) {
            throw new OrderLifecycleException('MAXIMUM_DISCOUNT_COUNT_EXCEEDED', 'Too many discounts were requested.');
        }
        $seen = [];
        foreach ($requested as $one) {
            if (! in_array($one['source'] ?? null, ['code', 'configured_manual'], true)) {
                throw new OrderLifecycleException('DISCOUNT_AD_HOC_DISABLED', 'Choose an existing eligible discount policy.');
            }
            $id = (int) ($one['discountId'] ?? 0);
            if ($id <= 0) {
                throw new OrderLifecycleException('DISCOUNT_NOT_FOUND', 'The selected discount is unavailable.');
            }
            if (isset($seen[$id])) {
                throw new OrderLifecycleException('DISCOUNT_DUPLICATE_INTENT', 'Each discount can be requested only once.');
            }
            $seen[$id] = true;
        }
        $cfg = DiscountSettingsService::effectivePolicy($settings);
        $candidates = [];
        $excluded = [];
        $reasons = [];
        $provisional = false;
        foreach ($requested as $index => $one) {
            $id = (int) $one['discountId'];
            $policy = $policies->firstWhere('id', $id);
            try {
                if (! $policy) {
                    throw new OrderLifecycleException('DISCOUNT_INACTIVE', 'Review the selected discount again.');
                }
                if (($one['source'] === 'code' && $policy->application_mode !== 'code') || ($one['source'] === 'configured_manual' && $policy->application_mode !== 'manual')) {
                    throw new OrderLifecycleException('DISCOUNT_APPLICATION_MODE_INVALID', 'Review the selected discount again.');
                }
                $full = $this->eligibility->assertApplicable($tenantId, $policy, $order, $method?->paymentMethodId, $method?->type);
                if ($method === null && $this->tenderRestricted($tenantId, $policy)) {
                    $provisional = true;
                    $reasons[] = ['discountId' => $id, 'code' => 'DISCOUNT_TENDER_PENDING'];
                }
                $weights = [];
                foreach ($this->eligibility->eligibleItems($tenantId, $order, $policy)->orderBy('order_items.id')->get(['order_items.*']) as $item) {
                    $weights[(int) $item->id] = ['balance' => $this->decimal($balances[(int) $item->id]), 'quantity' => (string) $item->quantity];
                }
                if ($policy->scope === 'bundle') {
                    $weights = $this->bundleWeights($tenantId, $order, $policy, $items, $balances);
                }
                $candidates[] = ['policy' => $policy, 'source' => $one['source'], 'weights' => $weights, 'bundleAmount' => $this->cents($full['amount']),
                    'position' => $index, 'level' => $policy->scope === 'order' ? 'order' : 'item', 'code' => $one['source'] === 'code',
                    'exclusive' => ($policy->combination_behavior ?? 'follow_cafe_policy') === 'exclusive'];
            } catch (OrderLifecycleException $e) {
                if ($strict) {
                    throw $e;
                }
                $excluded[] = $this->exclusion($index, $id, $policy->name ?? null, $one['source'], $e->domainCode, []);
            }
        }
        $evaluation = $this->simulate([], $cfg, $balances, $budget);
        if ($candidates !== []) {
            $evaluation = $cfg['conflictResolution'] === 'priority'
                ? $this->selectByPriority($candidates, $cfg, $balances, $budget)
                : $this->selectBestSaving($candidates, $cfg, $balances, $budget);
        }
        $applied = array_column($evaluation['applied'], 'position');
        $kept = array_values(array_filter($candidates, fn (array $candidate): bool => in_array($candidate['position'], $applied, true)));
        foreach ($candidates as $candidate) {
            if (! in_array($candidate['position'], $applied, true)) {
                [$code, $with] = $this->explainExclusion($candidate, $kept, $cfg, $balances, $budget);
                $excluded[] = $this->exclusion($candidate['position'], (int) $candidate['policy']->id, $candidate['policy']->name, $candidate['source'], $code, $with);
            }
        }
        usort($excluded, fn (array $a, array $b): int => $a['position'] <=> $b['position']);

        return ['selected' => $evaluation['applied'], 'excluded' => $excluded, 'reasons' => $reasons, 'provisional' => $provisional];
    }

    private function exclusion(int $index, int $discountId, ?string $name, string $source, string $code, array $conflictsWith): array
    {
        return ['position' => $index + 1, 'discountId' => $discountId, 'name' => $name, 'source' => $source, 'code' => $code, 'conflictsWith' => $conflictsWith];
    }

    /** First structural Cafe Policy rule a set breaks, or null. Monotone: a superset never repairs a violation. */
    private function violation(array $set, array $cfg): ?string
    {
        if (count($set) < 2) {
            return null;
        }
        if (! $cfg['allowMultipleDiscounts']) {
            return 'MULTIPLE_DISCOUNTS_DISABLED';
        }
        if (array_filter($set, fn (array $candidate): bool => $candidate['exclusive']) !== []) {
            return 'EXCLUSIVE_DISCOUNT_CONFLICT';
        }
        if (count($set) > $cfg['effectiveMaximumDiscounts']) {
            return 'MAXIMUM_DISCOUNT_COUNT_EXCEEDED';
        }
        $codes = count(array_filter($set, fn (array $candidate): bool => $candidate['code']));
        if ($codes > 1 && ! $cfg['allowMultipleCoupons']) {
            return 'MULTIPLE_COUPONS_DISABLED';
        }
        if ($codes > 0 && $codes < count($set) && ! $cfg['allowCouponWithConfigured']) {
            return 'COUPON_COMBINATION_NOT_ALLOWED';
        }
        if (count(array_unique(array_column($set, 'level'))) > 1 && ! $cfg['allowOrderAfterItemDiscounts']) {
            return 'ORDER_ITEM_COMBINATION_NOT_ALLOWED';
        }

        return null;
    }

    /** Authoritative application sequence: item-level first, then order-level; reviewed order within a level. */
    private function sequence(array $set): array
    {
        usort($set, fn (array $a, array $b): int => (($a['level'] === 'order') <=> ($b['level'] === 'order')) ?: ($a['position'] <=> $b['position']));

        return $set;
    }

    /** Sequentially applies a set. Integer-cent arithmetic through score(); never negative. */
    private function simulate(array $sequence, array $cfg, array $balances, int $budget): array
    {
        $residual = $balances;
        $left = $budget;
        $applied = [];
        $dropped = [];
        $byItem = [];
        $byOrder = [];
        $disjoint = $cfg['stackingMode'] === 'different_items_only';
        foreach ($sequence as $candidate) {
            $view = $residual;
            if ($disjoint) {
                foreach (array_keys($view) as $id) {
                    if (isset($byOrder[$id]) || ($candidate['level'] === 'item' && isset($byItem[$id]))) {
                        $view[$id] = 0;
                    }
                }
            }
            $scored = $this->score($candidate, $view, $left, true);
            if ($scored['amount'] <= 0) {
                $code = 'DISCOUNT_ITEMS_NOT_ELIGIBLE';
                if ($left <= 0) {
                    $code = 'MAXIMUM_TOTAL_DISCOUNT_EXCEEDED';
                } elseif ($disjoint && $view !== $residual && $this->score($candidate, $residual, $left, true)['amount'] > 0) {
                    $code = 'SAME_ITEM_STACKING_DISABLED';
                }
                $dropped[] = ['candidate' => $candidate, 'code' => $code];

                continue;
            }
            $capped = $scored['amount'] >= $left && $this->score($candidate, $view, PHP_INT_MAX, true)['amount'] > $scored['amount'];
            $applied[] = $scored + ['capped' => $capped];
            foreach ($scored['allocations'] as $id => $amount) {
                $residual[$id] -= $amount;
                if ($candidate['level'] === 'order') {
                    $byOrder[$id] = true;
                } else {
                    $byItem[$id] = true;
                }
            }
            $left -= $scored['amount'];
        }

        return ['applied' => $applied, 'dropped' => $dropped, 'total' => array_sum(array_column($applied, 'amount'))];
    }

    private function selectBestSaving(array $candidates, array $cfg, array $balances, int $budget): array
    {
        $best = null;
        $search = function (int $from, array $subset) use (&$search, &$best, $candidates, $cfg, $balances, $budget): void {
            if ($subset !== []) {
                $evaluation = $this->simulate($this->sequence($subset), $cfg, $balances, $budget);
                if ($best === null || $this->betterSet($evaluation, $best)) {
                    $best = $evaluation;
                }
            }
            for ($i = $from; $i < count($candidates); $i++) {
                $next = [...$subset, $candidates[$i]];
                if ($this->violation($next, $cfg) === null) {
                    $search($i + 1, $next);
                }
            }
        };
        $search(0, []);

        return $best;
    }

    /** Higher total saving, then fewer discounts, then the lexicographically lower discount ids. */
    private function betterSet(array $a, array $b): bool
    {
        if ($a['total'] !== $b['total']) {
            return $a['total'] > $b['total'];
        }
        if (count($a['applied']) !== count($b['applied'])) {
            return count($a['applied']) < count($b['applied']);
        }
        $ids = function (array $evaluation): array {
            $ids = array_map(fn (array $row): int => (int) $row['policy']->id, $evaluation['applied']);
            sort($ids);

            return $ids;
        };

        return $ids($a) < $ids($b);
    }

    private function selectByPriority(array $candidates, array $cfg, array $balances, int $budget): array
    {
        usort($candidates, fn (array $a, array $b): int => ((int) ($b['policy']->priority ?? 0) <=> (int) ($a['policy']->priority ?? 0)) ?: ((int) $a['policy']->id <=> (int) $b['policy']->id));
        $chosen = [];
        foreach ($candidates as $candidate) {
            $trial = [...$chosen, $candidate];
            if ($this->violation($trial, $cfg) === null
                && count($this->simulate($this->sequence($trial), $cfg, $balances, $budget)['applied']) === count($trial)) {
                $chosen = $trial;
            }
        }

        return $this->simulate($this->sequence($chosen), $cfg, $balances, $budget);
    }

    /** Stable reason why a requested, eligible discount was not part of the final set. */
    private function explainExclusion(array $candidate, array $kept, array $cfg, array $balances, int $budget): array
    {
        $with = array_map(fn (array $row): int => (int) $row['policy']->id, $kept);
        sort($with);
        $trial = [...$kept, $candidate];
        if (($code = $this->violation($trial, $cfg)) !== null) {
            return [$code, $with];
        }
        $dropped = $this->simulate($this->sequence($trial), $cfg, $balances, $budget)['dropped'];
        foreach ($dropped as $drop) {
            if ($drop['candidate']['position'] === $candidate['position']) {
                return [$drop['code'], $with];
            }
        }

        return [$dropped[0]['code'] ?? 'DISCOUNT_CONFLICT', $with];
    }

    private function score(array $candidate, array $balances, int $budget, bool $sequential = false): array
    {
        $weights = [];
        $policy = $candidate['policy'];
        $perUnit = $policy->scope === 'product' && $policy->type === 'fixed' && $policy->fixed_amount_basis === 'per_unit';
        $basis = BigDecimal::zero();
        foreach ($candidate['weights'] as $id => $item) {
            $balance = BigDecimal::min($this->decimal($balances[$id] ?? 0), $item['balance']);
            if ($balance->isGreaterThan(0)) {
                // Fixed per-unit benefit belongs to its quantity contribution,
                // not the selling-price proportion of unrelated eligible lines.
                $contribution = $perUnit ? BigDecimal::min(BigDecimal::of((string) $policy->value)->multipliedBy($item['quantity']), $balance) : $balance;
                $weights[$id] = $contribution->multipliedBy(100);
                $basis = $basis->plus($contribution);
            }
        }
        $raw = $policy->scope === 'bundle' ? BigDecimal::of($this->decimal($candidate['bundleAmount']))
            : ($policy->type === 'percentage' ? $basis->multipliedBy((string) $policy->value)->exactlyDividedBy(100)
                : ($perUnit ? $basis : BigDecimal::of((string) $policy->value)));
        if ($sequential && $policy->scope === 'bundle') {
            // A package after another discount is priced on what remains of its
            // matched lines. On pristine lines this equals bundleAmount.
            $raw = BigDecimal::min($raw, $policy->type === 'percentage' ? $basis->multipliedBy((string) $policy->value)->exactlyDividedBy(100) : BigDecimal::min((string) $policy->value, $basis));
        }
        if ($policy->maximum_discount_amount !== null) {
            $raw = BigDecimal::min($raw, (string) $policy->maximum_discount_amount);
        }
        $amount = max(0, min($this->cents($raw), $this->cents($basis), $budget));

        $allocations = $this->allocate($amount, $weights);
        foreach ($allocations as $id => $part) {
            // One cent may be required by aggregate HALF_UP rounding of
            // subcent contributions; nothing beyond that contribution's
            // ceiling may be transferred to this line, even after caps.
            if ($part > $weights[$id]->toScale(0, RoundingMode::CEILING)->toInt() || $part > $balances[$id]) {
                throw new \LogicException('Discount allocation exceeds eligible contribution.');
            }
        }

        return $candidate + ['amount' => $amount, 'allocations' => $allocations];
    }

    /** Exact cent weights may contain fractions; round only the aggregate. */
    public function allocate(int $amount, array $weights): array
    {
        $weights = array_map(fn ($weight) => BigDecimal::of($weight), $weights);
        $scale = $weights === [] ? 0 : max(array_map(fn ($weight) => $weight->getScale(), $weights));
        $weights = array_map(fn ($weight) => $weight->toScale($scale)->getUnscaledValue(), $weights);
        $total = BigInteger::zero();
        foreach ($weights as $weight) {
            $total = $total->plus($weight);
        }
        if ($amount === 0 || $total->isZero()) {
            return [];
        }
        $parts = [];
        $remainders = [];
        foreach ($weights as $id => $weight) {
            [$quotient, $remainder] = BigInteger::of($amount)->multipliedBy($weight)->quotientAndRemainder($total);
            $parts[$id] = $quotient->toInt();
            $remainders[$id] = $remainder;
        }
        $ids = array_keys($parts);
        usort($ids, fn ($a, $b) => $remainders[$b]->compareTo($remainders[$a]) ?: ($a <=> $b));
        $left = $amount - array_sum($parts);
        foreach (array_slice($ids, 0, $left) as $id) {
            $parts[$id]++;
        }
        ksort($parts);

        return array_filter($parts, fn ($v) => $v > 0);
    }

    private function best(array $candidates, array $balances, int $budget, string $strategy): ?array
    {
        $scored = array_values(array_filter(array_map(fn ($c) => $this->score($c, $balances, $budget), $candidates), fn ($c) => $c['amount'] > 0));
        usort($scored, fn ($a, $b) => $this->compareGroups([$a], [$b], $strategy));

        return $scored[0] ?? null;
    }

    private function compareGroups(array $a, array $b, string $strategy): int
    {
        $ids = fn ($group) => collect($group)->map(fn ($c) => (int) $c['policy']->id)->sort()->values()->all();
        if ($strategy === 'priority') {
            $priority = fn ($group) => max(array_map(fn ($c) => (int) ($c['policy']->priority ?? 0), $group));
            $cmp = $priority($b) <=> $priority($a);
            if ($cmp === 0) {
                $rankId = fn ($group) => min(array_map(fn ($c) => (int) $c['policy']->id, array_filter($group, fn ($c) => (int) ($c['policy']->priority ?? 0) === $priority($group))));
                $cmp = $rankId($a) <=> $rankId($b);
            }
        } else {
            $cmp = array_sum(array_column($a, 'amount')) <=> array_sum(array_column($b, 'amount'));
            if ($strategy === 'highest_saving') {
                $cmp = -$cmp;
            }
        }

        return $cmp ?: ((count($a) <=> count($b)) ?: ($ids($a) <=> $ids($b)));
    }

    private function reserve(array $candidate, array &$balances, int &$budget, bool $identities): void
    {
        $budget -= $candidate['amount'];
        foreach ($candidate['allocations'] as $id => $amount) {
            $balances[$id] = $identities ? 0 : $balances[$id] - $amount;
        }
    }

    private function bundleWeights(int $tenantId, object $order, object $policy, iterable $items, array $balances): array
    {
        $weights = [];
        $selectedVariants = app(DiscountBundleVariantService::class)->savedIds($tenantId, $policy->id);
        foreach (DB::table('discount_bundle_requirements')->where('tenant_id', $tenantId)->where('discount_id', $policy->id)->orderBy('product_id')->get() as $requirement) {
            $remaining = BigDecimal::of((string) $requirement->quantity);
            foreach ($items as $item) {
                if ((int) $item->product_id !== (int) $requirement->product_id || $remaining->isLessThanOrEqualTo(0)
                    || ! DiscountBundleVariantService::accepts($selectedVariants[(int) $requirement->product_id] ?? [], $item->product_variant_id)) {
                    continue;
                }
                $take = BigDecimal::min($remaining, (string) $item->quantity);
                $weights[(int) $item->id] = ['balance' => (string) BigDecimal::min($this->decimal($balances[(int) $item->id]), $take->multipliedBy((string) $item->unit_price)), 'quantity' => (string) $take];
                $remaining = $remaining->minus($take);
            }
        }

        return $weights;
    }

    public function tenderRestricted(int $tenantId, object $policy): bool
    {
        return ! in_array(strtolower(trim((string) $policy->payment_method)), ['', 'any payment method'], true)
            || DB::table('discount_targets')->where('tenant_id', $tenantId)->where('discount_id', $policy->id)->where('target_type', 'payment_method')->exists();
    }

    private function fingerprint(int $tenantId, object $order, array $intent, ?object $method, array $result, array $policies, array $items, array $suppressed): string
    {
        // JSONB preserves values, not object key order; intents() already
        // normalized every requested intent (including ad-hoc), and its list
        // order is the reviewed application sequence, which is hashed too.
        // Full tenant policy set, including inactive/zero/ineligible candidates,
        // plus targets and usages: newly eligible/created policies cannot evade it.
        $context = [];
        foreach (['discount_targets', 'discount_product_target_variants', 'discount_channel_targets', 'discount_bundle_requirements', 'discount_bundle_requirement_variants'] as $table) {
            $context[$table] = DB::table($table)->where('tenant_id', $tenantId)->orderBy('id')->get()->all();
        }
        $context['branch'] = DB::table('branches')->where('tenant_id', $tenantId)->where('id', $order->branch_id)->first();
        $context['customer'] = $order->customer_id === null ? null : DB::table('customers')->where('tenant_id', $tenantId)->where('id', $order->customer_id)->first();
        $context['groups'] = DB::table('customer_groups')->where('tenant_id', $tenantId)->orderBy('id')->get()->all();
        $context['memberships'] = DB::table('customer_group_memberships')->where('tenant_id', $tenantId)->where('customer_id', $order->customer_id)->orderBy('id')->get()->all();
        $context['settings'] = $this->settings->read($tenantId);
        $context['businessDate'] = now($context['branch']->timezone ?: 'UTC')->toDateString();
        $context['intentState'] = DB::table('order_discount_intents')->where('tenant_id', $tenantId)->where('order_id', $order->id)->first();
        $context['suppressions'] = DB::table('order_discount_suppressions')->where('tenant_id', $tenantId)->where('order_id', $order->id)->orderBy('id')->get()->all();
        $context['applied'] = DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $order->id)->orderBy('id')->get()->all();
        $policies = array_map(function ($policy): array {
            $data = (array) $policy;
            // Settlement usage is not a policy edit. Eligibility outcomes in
            // result already capture exhaustion/customer/daily limits.
            unset($data['used_count']);

            return $data;
        }, $policies);

        return hash_hmac('sha256', json_encode([$order, $items, $intent, $method, $policies, $suppressed, $context, $result], JSON_THROW_ON_ERROR), (string) config('app.key'));
    }

    public function persist(int $tenantId, object $order, array $result): void
    {
        DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $order->id)->delete();
        foreach ($result['discounts'] as $discount) {
            $snapshot = $discount;
            unset($snapshot['allocations'], $snapshot['amount']);
            if ($discount['discountId'] !== null) {
                $snapshot['targets'] = DB::table('discount_targets')->where('tenant_id', $tenantId)->where('discount_id', $discount['discountId'])->orderBy('target_type')->orderBy('target_id')->get(['target_type', 'target_id'])->map(fn ($t) => ['type' => $t->target_type, 'id' => (int) $t->target_id])->all();
                $snapshot['productVariantSelections'] = [];
                foreach (array_filter($snapshot['targets'], fn ($t) => $t['type'] === 'product') as $target) {
                    $variants = DB::table('discount_product_target_variants')->where('tenant_id', $tenantId)->where('discount_id', $discount['discountId'])->where('product_id', $target['id'])->orderBy('product_variant_id')->pluck('product_variant_id')->map(fn ($id) => (int) $id)->all();
                    $snapshot['productVariantSelections'][] = ['productId' => $target['id'], 'variantMode' => $variants === [] ? 'all' : 'selected', 'variantIds' => $variants];
                }
                $snapshot['channelKeys'] = DB::table('discount_channel_targets')->where('tenant_id', $tenantId)->where('discount_id', $discount['discountId'])->orderBy('channel_key')->pluck('channel_key')->all();
                $bundleVariants = app(DiscountBundleVariantService::class)->savedIds($tenantId, $discount['discountId']);
                $snapshot['bundleRequirements'] = DB::table('discount_bundle_requirements')->where('tenant_id', $tenantId)->where('discount_id', $discount['discountId'])->orderBy('product_id')->get(['product_id', 'quantity'])->map(fn ($r) => ['productId' => (int) $r->product_id, 'quantity' => (string) $r->quantity, 'variantMode' => ($bundleVariants[(int) $r->product_id] ?? []) === [] ? 'all' : 'selected', 'variantIds' => $bundleVariants[(int) $r->product_id] ?? []])->all();
            }
            $id = DB::table('order_discounts')->insertGetId(['tenant_id' => $tenantId, 'order_id' => $order->id, 'discount_id' => $discount['discountId'], 'discount_name' => $discount['name'], 'discount_type' => $discount['type'], 'discount_value' => $discount['value'], 'discount_amount' => $discount['amount'], 'source' => $discount['source'], 'stage' => $discount['stage'], 'settings_version' => $result['settingsVersion'], 'application_sequence' => $discount['sequence'] ?? null, 'calculation_metadata' => json_encode(['calculationVersion' => 2, 'rounding' => 'HALF_UP', 'allocation' => 'largest_remainder', 'stacking' => 'sequential', 'sequence' => $discount['sequence'] ?? null, 'capped' => $discount['capped'] ?? false, 'policy' => $result['policy'] ?? null]), 'policy_snapshot' => json_encode($snapshot), 'created_at' => now(), 'updated_at' => now()]);
            foreach ($discount['allocations'] as $allocation) {
                DB::table('order_discount_allocations')->insert(['tenant_id' => $tenantId, 'order_id' => $order->id, 'order_discount_id' => $id, 'order_item_id' => $allocation['orderItemId'], 'amount' => $allocation['amount'], 'created_at' => now(), 'updated_at' => now()]);
            }
        }
        DB::table('orders')->where('tenant_id', $tenantId)->where('id', $order->id)->update(['subtotal' => $result['totals']['subtotal'], 'discount_total' => $result['totals']['discountTotal'], 'tax_total' => $result['totals']['taxTotal'], 'total' => $result['totals']['total'], 'updated_at' => now()]);
    }

    public function cents(string|int|BigDecimal $amount): int
    {
        return BigDecimal::of((string) $amount)->multipliedBy(100)->toScale(0, RoundingMode::HALF_UP)->toInt();
    }

    public function decimal(int $cents): string
    {
        return (string) BigDecimal::of($cents)->dividedBy(100, 2);
    }
}
