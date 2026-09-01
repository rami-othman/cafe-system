<?php

$configuredOrigins = array_values(array_filter(array_map(
    'trim',
    explode(',', (string) env('CORS_ALLOWED_ORIGINS', '')),
)));
$superAdminOrigin = trim((string) env('SUPER_ADMIN_WEB_URL', ''));

// Operational and Super Admin clients remain separate deployable origins.
// Once CORS_ALLOWED_ORIGINS is supplied for staging, retain an explicitly
// configured Super Admin origin without falling back to a development default.
$allowedOrigins = array_values(array_unique(array_filter([
    ...$configuredOrigins,
    $superAdminOrigin,
])));

if ($allowedOrigins === []) {
    $allowedOrigins = ['http://localhost:3000'];
}

return [
    'paths' => ['api/*'],
    'allowed_methods' => ['*'],
    'allowed_origins' => $allowedOrigins,
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['Authorization', 'Content-Type', 'Accept', 'Origin', 'X-Requested-With'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => true,
];
