<?php

namespace App\Services;

use App\Exceptions\CouponAttemptsThrottledException;
use App\Exceptions\OrderLifecycleException;
use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;

/**
 * Brute-force protection for typed coupon codes.
 *
 * Only FAILED redemptions spend budget, so ordinary configured-discount
 * previews, cart recalculations and successful redemptions are never throttled.
 * The budget is per tenant+user, with a larger per tenant+IP ceiling for a
 * shared cafe network. Branch is deliberately not a key, and there is no
 * tenant-wide key, so one mistyping cashier cannot lock out the others.
 * A success never clears the counters (a known-good code must not reset guessing).
 */
final class CouponAttemptGuard
{
    /**
     * Policy-availability failures. For a typed code they are reported exactly
     * like an unknown code, so a guess cannot learn that a code exists but is
     * expired, inactive, not yet started, out of hours or exhausted.
     * Order-context failures (minimum, customer, items, tender) stay specific
     * for the cashier; they still spend failed-attempt budget.
     */
    public const CONCEALED_CODES = [
        'DISCOUNT_INACTIVE', 'DISCOUNT_NOT_STARTED', 'DISCOUNT_EXPIRED', 'DISCOUNT_DAY_NOT_ALLOWED',
        'DISCOUNT_TIME_NOT_ALLOWED', 'DISCOUNT_BRANCH_NOT_ELIGIBLE', 'DISCOUNT_CHANNEL_NOT_ELIGIBLE',
        'DISCOUNT_USAGE_LIMIT_REACHED', 'DISCOUNT_BOGO_UNSUPPORTED', 'DISCOUNT_APPLICATION_MODE_INVALID',
        'DISCOUNT_APPLICATION_MODE_UNSUPPORTED',
    ];

    /** Run a typed-code redemption; failures spend budget and availability failures are concealed. */
    public function guarded(Request $request, int $tenantId, Closure $redeem): mixed
    {
        $this->assertAllowed($request, $tenantId);
        try {
            return $redeem();
        } catch (OrderLifecycleException $exception) {
            $this->recordFailure($request, $tenantId);

            throw $this->concealed($exception);
        }
    }

    public function assertAllowed(Request $request, int $tenantId): void
    {
        $wait = 0;
        foreach ($this->keys($request, $tenantId) as $key => $max) {
            if (RateLimiter::tooManyAttempts($key, $max)) {
                $wait = max($wait, RateLimiter::availableIn($key));
            }
        }
        if ($wait > 0) {
            throw new CouponAttemptsThrottledException($wait);
        }
    }

    public function recordFailure(Request $request, int $tenantId): void
    {
        $decay = (int) config('discount_engine.coupon_attempts.decay_seconds', 300);
        foreach (array_keys($this->keys($request, $tenantId)) as $key) {
            RateLimiter::hit($key, $decay);
        }
    }

    public function concealed(OrderLifecycleException $exception): OrderLifecycleException
    {
        return in_array($exception->domainCode, self::CONCEALED_CODES, true)
            ? new OrderLifecycleException('DISCOUNT_NOT_FOUND', 'The coupon code is invalid or unavailable.')
            : $exception;
    }

    /** @return array<string, int> limiter key => maximum failures per decay window */
    private function keys(Request $request, int $tenantId): array
    {
        $actor = $request->attributes->get('auth_user');
        $actorId = $actor instanceof User ? (int) $actor->id : 0;
        $config = config('discount_engine.coupon_attempts', []);

        return [
            "coupon-attempts:user:{$tenantId}:{$actorId}" => (int) ($config['per_user'] ?? 10),
            "coupon-attempts:ip:{$tenantId}:".sha1((string) $request->ip()) => (int) ($config['per_ip'] ?? 40),
        ];
    }
}
