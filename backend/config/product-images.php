<?php

return [
    // Local development remains self-contained. Staging selects
    // supabase-product-images through its environment, never through .env.
    'disk' => env('PRODUCT_IMAGE_DISK', 'product-images-local'),
];
