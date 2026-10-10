<?php

return [
    // Only the isolated test authority may exercise Automatic before rollout.
    // Public engineReady and the persisted activation CHECK stay false.
    'isolated_automatic' => env('DISCOUNT_ENGINE_ISOLATED_AUTOMATIC', false),

    // Failed typed-coupon redemptions allowed per decay window (see CouponAttemptGuard).
    'coupon_attempts' => [
        'per_user' => (int) env('DISCOUNT_COUPON_ATTEMPTS_PER_USER', 10),
        'per_ip' => (int) env('DISCOUNT_COUPON_ATTEMPTS_PER_IP', 40),
        'decay_seconds' => (int) env('DISCOUNT_COUPON_ATTEMPTS_DECAY', 300),
    ],
];
