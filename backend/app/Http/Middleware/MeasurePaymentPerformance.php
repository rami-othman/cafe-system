<?php

namespace App\Http\Middleware;

use App\Support\PaymentPerformanceProbe;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class MeasurePaymentPerformance
{
    public function __construct(private readonly PaymentPerformanceProbe $probe) {}

    public function handle(Request $request, Closure $next): Response
    {
        if (! $request->isMethod('POST') || ! preg_match('#^api/v1/orders/\d+/pay$#', $request->path())) {
            return $next($request);
        }
        $this->probe->begin();
        $response = $next($request);
        $report = $this->probe->finish($response->getStatusCode());
        if ($report !== []) {
            $response->headers->set('X-Payment-Query-Count', (string) $report['queryCount']);
            $response->headers->set('Server-Timing', $this->serverTiming($report['timingsMs']));
        }
        return $response;
    }

    private function serverTiming(array $timings): string
    {
        return implode(', ', array_map(
            fn (string $name, float|int $ms): string => str_replace([' ', '/'], ['_', '_'], $name).';dur='.round($ms, 2),
            array_keys($timings),
            array_values($timings),
        ));
    }
}
