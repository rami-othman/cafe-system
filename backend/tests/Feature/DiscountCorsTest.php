<?php

namespace Tests\Feature;

use Tests\TestCase;

class DiscountCorsTest extends TestCase
{
    public function test_approved_origin_preflight_allows_locale_and_bearer_headers(): void
    {
        config(['cors.allowed_origins' => ['http://localhost:18000', 'http://localhost:18001']]);
        foreach (['/api/v1/auth/login' => 'POST', '/api/v1/discounts' => 'GET', '/api/v1/orders/1/payment-quote' => 'POST'] as $path => $method) {
            $response = $this->withHeaders([
                'Origin' => 'http://localhost:18000',
                'Access-Control-Request-Method' => $method,
                'Access-Control-Request-Headers' => 'authorization,content-type,x-app-locale,x-discount-contract',
            ])->options($path);
            $response->assertNoContent()->assertHeader('Access-Control-Allow-Origin', 'http://localhost:18000');
            foreach (['authorization', 'content-type', 'x-app-locale', 'x-discount-contract'] as $header) {
                $this->assertStringContainsStringIgnoringCase($header, (string) $response->headers->get('Access-Control-Allow-Headers'));
            }
            $this->assertNotContains('*', config('cors.allowed_headers'));
        }
    }

    public function test_unapproved_origin_does_not_receive_access_even_with_locale_header(): void
    {
        config(['cors.allowed_origins' => ['http://localhost:18000', 'http://localhost:18001']]);
        foreach (['/api/v1/auth/login', '/api/v1/discounts'] as $path) {
            $response = $this->withHeaders([
                'Origin' => 'https://unapproved.example.test',
                'Access-Control-Request-Method' => 'GET',
                'Access-Control-Request-Headers' => 'authorization,x-app-locale',
            ])->options($path);
            $response->assertHeaderMissing('Access-Control-Allow-Origin');
        }
    }

    public function test_cors_does_not_bypass_discount_authentication(): void
    {
        config(['cors.allowed_origins' => ['http://localhost:18000', 'http://localhost:18001']]);
        foreach (['en', 'ar'] as $locale) {
            // Use call, not TestCase::json, which provisions a testing token.
            $response = $this->call('GET', '/api/v1/discounts', server: [
                'HTTP_ORIGIN' => 'http://localhost:18000',
                'HTTP_X_APP_LOCALE' => $locale,
                'HTTP_ACCEPT' => 'application/json',
            ]);
            $response->assertUnauthorized()->assertHeader('Access-Control-Allow-Origin', 'http://localhost:18000');
        }
    }
}
