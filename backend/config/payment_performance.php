<?php

return [
    // An explicit, narrowly scoped diagnostics switch; safe to use without
    // enabling Laravel's user-visible APP_DEBUG exception pages.
    'enabled' => (bool) env('PAYMENT_PERFORMANCE_DEBUG', false),
];
