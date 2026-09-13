<?php

namespace App\Http\Middleware;

use App\Support\PaymentPerformanceProbe;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

final class MeasurePaymentPerformance
{
    public function __construct(private readonly PaymentPerformanceProbe $probe) {}

    public function handle(Request $request, Closure $next): Response
    {
        if (! $request->isMethod('POST') || ! preg_match('#^api/v1/orders/\d+/pay$#', $request->path())) {
            return $next($request);
        }
        $this->probe->begin();
        $requestId = (string) ($request->headers->get('X-Request-Id') ?: Str::uuid());
        $request->attributes->set('request_id', $requestId);
        try {
            $response = $next($request);
        } catch (Throwable $exception) {
            $actor = $request->attributes->get('auth_user');
            Log::error('pos.payment.failed', [
                'requestId' => $requestId,
                'tenantId' => $actor?->tenant_id,
                'userId' => $actor?->id,
                'orderId' => (int) $request->route('order'),
                'method' => $request->input('method'),
                'idempotencyKeyHash' => hash('sha256', (string) $request->input('idempotencyKey')),
                'exceptionClass' => $exception::class,
                'exceptionMessage' => $exception->getMessage(),
            ]);
            $this->probe->finish(500);
            throw $exception;
        }
        $report = $this->probe->finish($response->getStatusCode());
        $response->headers->set('X-Request-Id', $requestId);
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
