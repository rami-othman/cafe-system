<?php

namespace Tests\Feature;

use Symfony\Component\HttpFoundation\Request;
use Tests\TestCase;

class CloudReadinessConfigurationTest extends TestCase
{
    public function test_cors_allows_only_configured_origins_and_authorization_preflight(): void
    {
        putenv('CORS_ALLOWED_ORIGINS=https://allowed.example.test');
        $_ENV['CORS_ALLOWED_ORIGINS'] = 'https://allowed.example.test';
        $_SERVER['CORS_ALLOWED_ORIGINS'] = 'https://allowed.example.test';
        $this->refreshApplication();

        try {
            $this->assertSame(['https://allowed.example.test'], config('cors.allowed_origins'));

            $allowed = $this->withHeaders([
                'Origin' => 'https://allowed.example.test',
                'Access-Control-Request-Method' => 'POST',
                'Access-Control-Request-Headers' => 'Authorization, Content-Type, Accept',
            ])->options('/api/v1/auth/login');

            $allowed->assertNoContent();
            $allowed->assertHeader('Access-Control-Allow-Origin', 'https://allowed.example.test');
            $this->assertStringContainsStringIgnoringCase(
                'authorization',
                (string) $allowed->headers->get('Access-Control-Allow-Headers'),
            );

            $unknown = $this->withHeaders([
                'Origin' => 'https://unknown.example.test',
                'Access-Control-Request-Method' => 'POST',
            ])->options('/api/v1/auth/login');

            $this->assertNotSame(
                'https://unknown.example.test',
                $unknown->headers->get('Access-Control-Allow-Origin'),
            );
        } finally {
            putenv('CORS_ALLOWED_ORIGINS');
            unset($_ENV['CORS_ALLOWED_ORIGINS'], $_SERVER['CORS_ALLOWED_ORIGINS']);
        }
    }

    public function test_trusted_render_proxy_forwards_https_and_host_for_url_generation(): void
    {
        Request::setTrustedProxies(
            ['0.0.0.0/0'],
            Request::HEADER_X_FORWARDED_FOR
                | Request::HEADER_X_FORWARDED_HOST
                | Request::HEADER_X_FORWARDED_PORT
                | Request::HEADER_X_FORWARDED_PROTO,
        );

        try {
            $request = Request::create('http://container.internal/up', 'GET', [], [], [], [
                'REMOTE_ADDR' => '10.0.0.5',
                'HTTP_X_FORWARDED_PROTO' => 'https',
                'HTTP_X_FORWARDED_HOST' => 'staging.example.test',
            ]);

            $this->assertSame('https', $request->getScheme());
            $this->assertSame('staging.example.test', $request->getHost());
        } finally {
            Request::setTrustedProxies([], -1);
        }
    }
}
