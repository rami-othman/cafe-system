<?php

namespace App\Support;

use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

final class PaymentPerformanceProbe
{
    private bool $active = false;
    private bool $listenerRegistered = false;
    private float $startedAt = 0.0;
    private array $phases = [];
    private array $queries = [];
    private array $phaseStack = [];

    public function begin(): void
    {
        if (! config('payment_performance.enabled')) {
            return;
        }

        $this->phases = [];
        $this->queries = [];
        $this->phaseStack = [];
        $this->active = true;
        $this->startedAt = defined('LARAVEL_START') ? LARAVEL_START : microtime(true);
        if (! $this->listenerRegistered) {
            DB::listen(function (QueryExecuted $query): void {
                if (! $this->active) {
                    return;
                }
                $this->queries[] = [
                    'phase' => end($this->phaseStack) ?: 'request/auth',
                    'ms' => round((float) $query->time, 2),
                    'signature' => $this->signature($query->sql),
                ];
            });
            $this->listenerRegistered = true;
        }
    }

    public function enabled(): bool
    {
        return $this->active;
    }

    public function start(string $phase): float
    {
        if ($this->active) {
            $this->phaseStack[] = $phase;
        }

        return microtime(true);
    }

    public function stop(string $phase, float $startedAt): void
    {
        if (! $this->active) {
            return;
        }
        $this->phases[$phase] = round(($this->phases[$phase] ?? 0) + (microtime(true) - $startedAt) * 1000, 2);
        $index = array_search($phase, array_reverse($this->phaseStack, true), true);
        if ($index !== false) {
            unset($this->phaseStack[$index]);
            $this->phaseStack = array_values($this->phaseStack);
        }
    }

    public function measure(string $phase, callable $callback): mixed
    {
        $startedAt = $this->start($phase);
        try {
            return $callback();
        } finally {
            $this->stop($phase, $startedAt);
        }
    }

    public function finish(int $status): array
    {
        if (! $this->active) {
            return [];
        }
        $this->active = false;
        $totalMs = round((microtime(true) - $this->startedAt) * 1000, 2);
        $grouped = [];
        foreach ($this->queries as $query) {
            $key = $query['signature'];
            $grouped[$key] ??= ['count' => 0, 'totalMs' => 0.0, 'phases' => []];
            $grouped[$key]['count']++;
            $grouped[$key]['totalMs'] = round($grouped[$key]['totalMs'] + $query['ms'], 2);
            $grouped[$key]['phases'][$query['phase']] = ($grouped[$key]['phases'][$query['phase']] ?? 0) + 1;
        }
        uasort($grouped, fn (array $a, array $b): int => $b['count'] <=> $a['count']);
        $repeated = array_filter($grouped, fn (array $row): bool => $row['count'] > 1);
        $report = [
            'status' => $status,
            'totalMs' => $totalMs,
            'timingsMs' => ['request/auth' => round(max(0, ($this->phases['controller_start_offset'] ?? 0)), 2)] + $this->withoutInternalPhases(),
            'queryCount' => count($this->queries),
            'queryTimeMs' => round(array_sum(array_column($this->queries, 'ms')), 2),
            'queriesByPhase' => array_count_values(array_column($this->queries, 'phase')),
            'repeatedQueries' => $repeated,
        ];
        Log::debug('pos.payment.performance', $report);

        return $report;
    }

    public function controllerStarted(): void
    {
        if ($this->active) {
            $this->phases['controller_start_offset'] = (microtime(true) - $this->startedAt) * 1000;
            $this->phaseStack = ['payment orchestration'];
        }
    }

    private function withoutInternalPhases(): array
    {
        $phases = $this->phases;
        unset($phases['controller_start_offset']);
        $phases['total request duration'] = round((microtime(true) - $this->startedAt) * 1000, 2);
        return $phases;
    }

    private function signature(string $sql): string
    {
        $sql = preg_replace("/'(?:''|[^'])*'/", '?', $sql) ?? $sql;
        $sql = preg_replace('/\b\d+(?:\.\d+)?\b/', '?', $sql) ?? $sql;
        return preg_replace('/\s+/', ' ', trim($sql)) ?? $sql;
    }
}
