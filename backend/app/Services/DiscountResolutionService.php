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

    public function intent(int $tenantId, int $orderId): ?array
    {
        $stored = DB::table('order_discount_intents')->where('tenant_id', $tenantId)->where('order_id', $orderId)->value('intent');
        if ($stored !== null) {
            return json_decode($stored, true, flags: JSON_THROW_ON_ERROR);
        }
        $legacy = DB::table('order_discounts')->where('tenant_id', $tenantId)->where('order_id', $orderId)->where(fn ($q) => $q->whereNull('source')->orWhere('source', '!=', 'automatic'))->first();
        if (! $legacy) {
            return null;
        }
        if ($legacy->discount_id !== null) {
            $mode = DB::table('discounts')->where('tenant_id', $tenantId)->where('id', $legacy->discount_id)->value('application_mode');

            return ['source' => $mode === 'code' ? 'code' : 'configured_manual', 'discountId' => (int) $legacy->discount_id];
        }

        return ['source' => 'ad_hoc', 'type' => $legacy->discount_type, 'value' => (string) $legacy->discount_value, 'name' => $legacy->discount_name];
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
        $discounts = [];
        $allocated = array_fill_keys(array_keys($balances), 0);
        foreach ($selected as $row) {
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
            $discounts[] = ['discountId' => $policy->id === null ? null : (int) $policy->id, 'source' => $row['source'], 'stage' => in_array($policy->scope, ['product', 'category'], true) ? 'items' : 'order', 'name' => $policy->name, 'type' => $policy->type, 'value' => (string) $policy->value, 'amount' => $this->decimal($row['amount']), 'priority' => (int) ($policy->priority ?? 0), 'fixedAmountBasis' => $policy->fixed_amount_basis, 'applicationMode' => $policy->application_mode, 'scope' => $policy->scope, 'allocations' => $allocations];
        }
        $totalDiscount = array_sum(array_column($selected, 'amount'));
        if ($totalDiscount > $subtotal || $totalDiscount > $budget) {
            throw new \LogicException('Discount exceeds budget.');
        }
        $tax = $this->cents(BigDecimal::of($this->decimal($subtotal - $totalDiscount))->multipliedBy((string) $order->tax_rate));
        $totals = ['subtotal' => $this->decimal($subtotal), 'discountTotal' => $this->decimal($totalDiscount), 'taxTotal' => $this->decimal($tax), 'total' => $this->decimal($subtotal - $totalDiscount + $tax)];
        $result = ['discounts' => $discounts, 'totals' => $totals, 'settingsVersion' => $settings['version'], 'provisional' => $provisional, 'reasons' => $reasons];
        $result['fingerprint'] = $this->fingerprint($tenantId, $order, $intent, $method, $result, $policies->all(), $items->all(), $suppressed);

        return $result;
    }

    private function score(array $candidate, array $balances, int $budget): array
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
        foreach (DB::table('discount_bundle_requirements')->where('tenant_id', $tenantId)->where('discount_id', $policy->id)->orderBy('product_id')->get() as $requirement) {
            $remaining = BigDecimal::of((string) $requirement->quantity);
            foreach ($items as $item) {
                if ((int) $item->product_id !== (int) $requirement->product_id || $remaining->isLessThanOrEqualTo(0)) {
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

    private function fingerprint(int $tenantId, object $order, ?array $intent, ?object $method, array $result, array $policies, array $items, array $suppressed): string
    {
        // JSONB preserves values, not object key order. A stored review must
        // hash the same normalized intent as its preview, including ad-hoc.
        if ($intent !== null) {
            ksort($intent);
        }
        // Full tenant policy set, including inactive/zero/ineligible candidates,
        // plus targets and usages: newly eligible/created policies cannot evade it.
        $context = [];
        foreach (['discount_targets', 'discount_product_target_variants', 'discount_channel_targets', 'discount_bundle_requirements'] as $table) {
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
                $snapshot['bundleRequirements'] = DB::table('discount_bundle_requirements')->where('tenant_id', $tenantId)->where('discount_id', $discount['discountId'])->orderBy('product_id')->get(['product_id', 'quantity'])->map(fn ($r) => ['productId' => (int) $r->product_id, 'quantity' => (string) $r->quantity])->all();
            }
            $id = DB::table('order_discounts')->insertGetId(['tenant_id' => $tenantId, 'order_id' => $order->id, 'discount_id' => $discount['discountId'], 'discount_name' => $discount['name'], 'discount_type' => $discount['type'], 'discount_value' => $discount['value'], 'discount_amount' => $discount['amount'], 'source' => $discount['source'], 'stage' => $discount['stage'], 'settings_version' => $result['settingsVersion'], 'calculation_metadata' => json_encode(['calculationVersion' => 1, 'rounding' => 'HALF_UP', 'allocation' => 'largest_remainder']), 'policy_snapshot' => json_encode($snapshot), 'created_at' => now(), 'updated_at' => now()]);
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
