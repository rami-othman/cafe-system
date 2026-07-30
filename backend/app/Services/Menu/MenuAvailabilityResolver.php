<?php

namespace App\Services\Menu;

use App\Models\MenuAvailabilityRule;
use Carbon\CarbonImmutable;
use DateTimeInterface;

/** Resolves menu schedule rules without changing their state. */
class MenuAvailabilityResolver
{
    public function resolve(int $tenantId, int $menuId, int $branchId, string $channel, DateTimeInterface|string|null $at, string $timezone): array
    {
        $evaluatedAt = $at instanceof DateTimeInterface
            ? CarbonImmutable::instance($at)->setTimezone($timezone)
            : CarbonImmutable::parse($at ?? 'now', $timezone);
        $rules = MenuAvailabilityRule::query()
            ->where('tenant_id', $tenantId)->where('menu_id', $menuId)->where('is_active', true)->get()
            ->filter(fn (MenuAvailabilityRule $rule) => ! $rule->trashed())
            ->filter(fn (MenuAvailabilityRule $rule) => $this->scopeMatches($rule, $branchId, $channel));

        if ($rules->isEmpty()) {
            return $this->result(true, null, null, 'no_schedule_restriction');
        }

        $specificity = $rules->max(fn (MenuAvailabilityRule $rule) => $this->specificity($rule));
        $governing = $rules->filter(fn (MenuAvailabilityRule $rule) => $this->specificity($rule) === $specificity);
        $matched = $governing->filter(fn (MenuAvailabilityRule $rule) => $this->scheduleMatches($rule, $evaluatedAt))
            ->sort(fn (MenuAvailabilityRule $left, MenuAvailabilityRule $right) => ($right->priority <=> $left->priority) ?: ($left->id <=> $right->id))
            ->first();

        return $matched
            ? $this->result(true, $matched->id, $this->scope($matched), 'matched_rule')
            : $this->result(false, null, $this->scope($governing->first()), 'outside_schedule');
    }

    private function result(bool $available, ?int $ruleId, ?string $scope, string $reason): array
    {
        return ['isScheduledAvailable' => $available, 'matchedRuleId' => $ruleId, 'matchedScope' => $scope, 'reason' => $reason];
    }

    private function scopeMatches(MenuAvailabilityRule $rule, int $branchId, string $channel): bool
    {
        return ($rule->branch_id === null || (int) $rule->branch_id === $branchId)
            && ($rule->channel === null || $this->value($rule->channel) === $channel);
    }

    private function scheduleMatches(MenuAvailabilityRule $rule, CarbonImmutable $at): bool
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

    private function specificity(MenuAvailabilityRule $rule): int
    {
        return ($rule->branch_id !== null ? 2 : 0) + ($rule->channel !== null ? 1 : 0);
    }

    private function scope(MenuAvailabilityRule $rule): string
    {
        return match ($this->specificity($rule)) {
            3 => 'branch_channel', 2 => 'branch', 1 => 'channel', default => 'global'
        };
    }

    private function value(mixed $value): mixed
    {
        return $value instanceof \BackedEnum ? $value->value : $value;
    }

    private function time(mixed $value): ?string
    {
        return $value instanceof DateTimeInterface ? $value->format('H:i') : ($value === null ? null : substr((string) $value, 0, 5));
    }
}
