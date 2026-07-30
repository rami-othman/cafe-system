<?php

namespace App\Services\Catalog;

use App\Models\ProductAvailabilityRule;
use Carbon\CarbonImmutable;
use DateTimeInterface;
use Illuminate\Validation\ValidationException;

class ProductAvailabilityResolver
{
    public function __construct(private readonly ProductAvailabilityRuleService $rules) {}

    public function resolve(int $tenantId, int $productId, ?int $productVariantId, ?int $branchId, ?string $channel, DateTimeInterface|string $dateTime, string $timezone): array
    {
        $product = $this->rules->product($tenantId, $productId);
        if ($productVariantId !== null && ! $product->variants()->where('tenant_id', $tenantId)->whereKey($productVariantId)->exists()) {
            throw ValidationException::withMessages(['productVariantId' => 'The selected variant is invalid.']);
        }
        $branch = $this->rules->branch($tenantId, $branchId);
        $timezone = $branch?->timezone ?: $timezone;
        $at = $dateTime instanceof DateTimeInterface
            ? CarbonImmutable::instance($dateTime)->setTimezone($timezone)
            : CarbonImmutable::parse($dateTime, $timezone);

        $all = ProductAvailabilityRule::query()
            ->where('tenant_id', $tenantId)
            ->where('product_id', $product->id)
            ->where('is_active', true)
            ->get();
        $variantRules = $productVariantId === null ? collect() : $all->where('product_variant_id', $productVariantId);
        $productRules = $all->whereNull('product_variant_id');
        $level = $variantRules->filter(fn (ProductAvailabilityRule $rule) => $this->scopeMatches($rule, $branchId, $channel))->isNotEmpty() ? 'variant' : 'product';
        $candidates = $level === 'variant' ? $variantRules : $productRules;
        $candidates = $candidates->filter(fn (ProductAvailabilityRule $rule) => $this->scopeMatches($rule, $branchId, $channel));
        if ($candidates->isEmpty()) {
            return $this->unrestricted($productVariantId, $branchId, $channel, $timezone);
        }

        $specificity = $candidates->max(fn (ProductAvailabilityRule $rule) => $this->specificity($rule));
        $governing = $candidates->filter(fn (ProductAvailabilityRule $rule) => $this->specificity($rule) === $specificity);
        $matched = $governing->filter(fn (ProductAvailabilityRule $rule) => $this->scheduleMatches($rule, $at))
            ->sort(fn (ProductAvailabilityRule $left, ProductAvailabilityRule $right) => ($right->priority <=> $left->priority) ?: ($left->id <=> $right->id))
            ->first();
        if (! $matched) {
            return [
                'isScheduledAvailable' => false,
                'matchedRuleId' => null,
                'matchedScope' => $this->scope($governing->first()),
                'matchedLevel' => $level,
                'reason' => 'outside_schedule',
                'productVariantId' => $productVariantId,
                'branchId' => $branchId,
                'channel' => $channel,
                'timezone' => $timezone,
            ];
        }

        return [
            'isScheduledAvailable' => true,
            'matchedRuleId' => $matched->id,
            'matchedScope' => $this->scope($matched),
            'matchedLevel' => $level,
            'reason' => 'matched_rule',
            'productVariantId' => $productVariantId,
            'branchId' => $branchId,
            'channel' => $channel,
            'timezone' => $timezone,
        ];
    }

    private function unrestricted(?int $variantId, ?int $branchId, ?string $channel, string $timezone): array
    {
        return [
            'isScheduledAvailable' => true,
            'matchedRuleId' => null,
            'matchedScope' => null,
            'matchedLevel' => null,
            'reason' => 'no_schedule_restriction',
            'productVariantId' => $variantId,
            'branchId' => $branchId,
            'channel' => $channel,
            'timezone' => $timezone,
        ];
    }

    private function scopeMatches(ProductAvailabilityRule $rule, ?int $branchId, ?string $channel): bool
    {
        return ($rule->branch_id === null || (int) $rule->branch_id === $branchId)
            && ($rule->channel === null || $this->channel($rule) === $channel);
    }

    private function scheduleMatches(ProductAvailabilityRule $rule, CarbonImmutable $at): bool
    {
        $start = $this->time($rule->start_time);
        $end = $this->time($rule->end_time);
        $anchor = $at;
        if ($start !== null && $end !== null) {
            $time = $at->format('H:i');
            if ($start > $end) {
                if (! ($time >= $start || $time < $end)) {
                    return false;
                }
                if ($time < $end) {
                    $anchor = $anchor->subDay();
                }
            } elseif (! ($time >= $start && $time < $end)) {
                return false;
            }
        }
        if ($rule->day_of_week !== null && $anchor->dayOfWeek !== (int) $rule->day_of_week) {
            return false;
        }
        $date = $anchor->toDateString();

        return ! (($rule->start_date !== null && $date < $rule->start_date->toDateString())
            || ($rule->end_date !== null && $date > $rule->end_date->toDateString()));
    }

    private function specificity(ProductAvailabilityRule $rule): int
    {
        return ($rule->branch_id !== null ? 2 : 0) + ($rule->channel !== null ? 1 : 0);
    }

    private function scope(ProductAvailabilityRule $rule): string
    {
        return match ($this->specificity($rule)) {
            3 => 'branch_channel',
            2 => 'branch',
            1 => 'channel',
            default => 'global',
        };
    }

    private function channel(ProductAvailabilityRule $rule): ?string
    {
        return $rule->channel instanceof \BackedEnum ? $rule->channel->value : $rule->channel;
    }

    private function time(mixed $value): ?string
    {
        if ($value instanceof DateTimeInterface) {
            return $value->format('H:i');
        }

        return $value === null ? null : substr((string) $value, 0, 5);
    }
}
