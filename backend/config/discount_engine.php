<?php

return [
    // Only the isolated test authority may exercise Automatic before rollout.
    // Public engineReady and the persisted activation CHECK stay false.
    'isolated_automatic' => env('DISCOUNT_ENGINE_ISOLATED_AUTOMATIC', false),
];
