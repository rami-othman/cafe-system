<?php

namespace App\Services;

use Carbon\CarbonImmutable;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** A branch-local day boundary shared by preview, accounting and splitting. */
final readonly class ShiftClosePeriod
{
    public function __construct(public string $date, public string $timezone, public CarbonImmutable $end) {}

    public static function forShift(int $tenant, object $shift, string $date): self
    {
        $timezone = DB::table('branches')->where('tenant_id', $tenant)->where('id', $shift->branch_id)->value('timezone') ?: 'UTC';
        $today = CarbonImmutable::now('UTC')->setTimezone($timezone)->toDateString();
        $opened = CarbonImmutable::parse($shift->opened_at, 'UTC')->setTimezone($timezone)->toDateString();
        if ($date < $opened || $date > $today) {
            throw ValidationException::withMessages(['closingDate' => __('shifts.invalid_closing_date')]);
        }

        return new self($date, $timezone, CarbonImmutable::parse($date, $timezone)->addDay()->startOfDay()->utc());
    }

    public function historical(): bool
    {
        return $this->date < CarbonImmutable::now('UTC')->setTimezone($this->timezone)->toDateString();
    }

    public function timestamp(): string
    {
        return $this->end->format('Y-m-d H:i:s');
    }

    public function before(Builder $query, string $table, ?string $alias = null): Builder
    {
        return $query->whereRaw(self::eventExpression($table, $alias).' < ?', [$this->timestamp()]);
    }

    public function after(Builder $query, string $table, ?string $alias = null): Builder
    {
        return $query->whereRaw(self::eventExpression($table, $alias).' >= ?', [$this->timestamp()]);
    }

    public static function eventExpression(string $table, ?string $alias = null): string
    {
        $name = $alias ?? $table;

        return match ($table) {
            'payments' => "COALESCE({$name}.paid_at, {$name}.created_at)",
            'payment_refunds' => "COALESCE({$name}.refunded_at, {$name}.created_at)",
            'orders' => "COALESCE({$name}.closed_at, (SELECT MAX(COALESCE(ep.paid_at, ep.created_at)) FROM payments ep WHERE ep.tenant_id = {$name}.tenant_id AND ep.order_id = {$name}.id AND ep.status = 'completed' AND ep.deleted_at IS NULL), {$name}.opened_at, {$name}.created_at)",
            // Payment dates can be date-only. The immutable posting time is the
            // actual drawer event; editing expense metadata must not move it.
            'expenses' => "COALESCE((SELECT COALESCE(j.posted_at, j.created_at) FROM journal_entries j WHERE j.id = {$name}.journal_entry_id AND j.tenant_id = {$name}.tenant_id), {$name}.created_at)",
            'finance_documents' => "COALESCE({$name}.posted_at, {$name}.created_at)",
            'stock_counts' => "COALESCE({$name}.posted_at, {$name}.created_at)",
            default => "{$name}.created_at",
        };
    }
}
