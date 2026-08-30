<?php

namespace App\Services\Menu;

use Carbon\CarbonImmutable;

/** Evaluates schedule definitions frozen in a published menu snapshot. */
class SnapshotScheduleResolver
{
    public function menu(array $rules, int $branchId, string $channel, CarbonImmutable $at): array
    {
        return $this->resolve($rules, $branchId, $channel, $at) + ['matchedLevel' => null];
    }

    public function product(array $rules, ?int $variantId, int $branchId, string $channel, CarbonImmutable $at): array
    {
        $scoped = array_values(array_filter($rules, fn (array $rule) => $this->scopeMatches($rule, $branchId, $channel)));
        $variantRules = $variantId === null ? [] : array_values(array_filter($scoped, fn (array $rule) => ($rule['productVariantId'] ?? null) === $variantId));
        $level = $variantRules === [] ? 'product' : 'variant';
        $candidates = $variantRules === [] ? array_values(array_filter($scoped, fn (array $rule) => ($rule['productVariantId'] ?? null) === null)) : $variantRules;

        return $this->resolveCandidates($candidates, $at) + ['matchedLevel' => $candidates === [] ? null : $level];
    }

    private function resolve(array $rules, int $branchId, string $channel, CarbonImmutable $at): array
    {
        return $this->resolveCandidates(array_values(array_filter($rules, fn (array $rule) => $this->scopeMatches($rule, $branchId, $channel))), $at);
    }

    private function resolveCandidates(array $candidates, CarbonImmutable $at): array
    {
        if ($candidates === []) {
            return ['isScheduledAvailable' => true, 'matchedRuleId' => null, 'matchedScope' => null, 'reason' => 'no_schedule_restriction'];
        }

        $specificity = max(array_map(fn (array $rule) => $this->specificity($rule), $candidates));
        $governing = array_values(array_filter($candidates, fn (array $rule) => $this->specificity($rule) === $specificity));
        $matched = array_values(array_filter($governing, fn (array $rule) => $this->matches($rule, $at)));
        usort($matched, fn (array $left, array $right) => (($right['priority'] ?? 0) <=> ($left['priority'] ?? 0)) ?: (($left['id'] ?? 0) <=> ($right['id'] ?? 0)));

        if ($matched === []) {
            return ['isScheduledAvailable' => false, 'matchedRuleId' => null, 'matchedScope' => $this->scope($governing[0]), 'reason' => 'outside_schedule'];
        }

        return ['isScheduledAvailable' => true, 'matchedRuleId' => $matched[0]['id'] ?? null, 'matchedScope' => $this->scope($matched[0]), 'reason' => 'matched_rule'];
    }

    private function scopeMatches(array $rule, int $branchId, string $channel): bool
    {
        return (($rule['branchId'] ?? null) === null || (int) $rule['branchId'] === $branchId)
            && (($rule['channel'] ?? null) === null || $rule['channel'] === $channel);
    }

    private function matches(array $rule, CarbonImmutable $at): bool
    {
        $start = $this->time($rule['startTime'] ?? null);
        $end = $this->time($rule['endTime'] ?? null);
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
        if (($rule['dayOfWeek'] ?? null) !== null && $anchor->dayOfWeek !== (int) $rule['dayOfWeek']) {
            return false;
        }
        $date = $anchor->toDateString();

        return ! (($rule['startDate'] ?? null) !== null && $date < $rule['startDate'])
            && ! (($rule['endDate'] ?? null) !== null && $date > $rule['endDate']);
    }

    private function specificity(array $rule): int
    {
        return (($rule['branchId'] ?? null) !== null ? 2 : 0) + (($rule['channel'] ?? null) !== null ? 1 : 0);
    }

    private function scope(array $rule): string
    {
        return match ($this->specificity($rule)) {
            3 => 'branch_channel', 2 => 'branch', 1 => 'channel', default => 'global'
        };
    }

    private function time(?string $value): ?string
    {
        return $value === null ? null : substr($value, 0, 5);
    }
}
