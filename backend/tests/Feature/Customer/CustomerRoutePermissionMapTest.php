<?php

namespace Tests\Feature\Customer;

use Tests\TestCase;

class CustomerRoutePermissionMapTest extends TestCase
{
    public function test_every_customer_sensitive_route_has_the_narrow_customer_capability(): void
    {
        $expected = [
            'GET api/v1/customer-management/capabilities' => null,
            'GET api/v1/customers' => 'customer.lookup',
            'POST api/v1/customers/quick-create' => 'customer.quick_create',
            'PUT api/v1/customers/{customer}/groups' => 'customer.memberships',
            'GET api/v1/customer-groups' => 'customer.memberships',
            'GET api/v1/admin/customer-management/customers' => 'customer.manage',
            'POST api/v1/admin/customer-management/customers' => 'customer.manage',
            'GET api/v1/admin/customer-management/customers/{customer}' => 'customer.manage',
            'PUT api/v1/admin/customer-management/customers/{customer}' => 'customer.manage',
            'POST api/v1/admin/customer-management/customers/{customer}/activate' => 'customer.manage',
            'POST api/v1/admin/customer-management/customers/{customer}/deactivate' => 'customer.manage',
            'POST api/v1/admin/customer-management/customers/{customer}/archive' => 'customer.manage',
            'POST api/v1/admin/customer-management/customers/{customer}/restore' => 'customer.manage',
            'GET api/v1/admin/customer-management/customer-groups' => 'customer.manage',
            'POST api/v1/admin/customer-management/customer-groups' => 'customer.manage',
            'GET api/v1/admin/customer-management/customer-groups/{group}' => 'customer.manage',
            'PUT api/v1/admin/customer-management/customer-groups/{group}' => 'customer.manage',
            'POST api/v1/admin/customer-management/customer-groups/{group}/archive' => 'customer.manage',
            'POST api/v1/admin/customer-management/customer-groups/{group}/restore' => 'customer.manage',
            'GET api/v1/admin/customer-management/customer-groups/{group}/members' => 'customer.manage',
            'GET api/v1/admin/customer-management/customer-groups/{group}/eligible-members' => 'customer.manage',
            'POST api/v1/admin/customer-management/customer-groups/{group}/members' => 'customer.manage',
            'DELETE api/v1/admin/customer-management/customer-groups/{group}/members/{customer}' => 'customer.manage',
            'GET api/v1/admin/customer-management/role-permissions/manager' => 'customer.permission',
            'PUT api/v1/admin/customer-management/role-permissions/manager' => 'customer.permission',
        ];
        $routes = collect($this->app['router']->getRoutes())->flatMap(function ($route) {
            return collect($route->methods())->reject(fn (string $method) => in_array($method, ['HEAD', 'OPTIONS'], true))->mapWithKeys(fn (string $method) => [$method.' '.$route->uri() => $route]);
        });
        foreach ($expected as $key => $permission) {
            $this->assertTrue($routes->has($key), "Missing Customer route: {$key}");
            if ($permission !== null) {
                $this->assertContains('customer.permission:'.$permission, $routes[$key]->gatherMiddleware(), "Wrong Customer middleware: {$key}");
            }
            $this->assertContains('api.token', $routes[$key]->gatherMiddleware(), "Missing authentication middleware: {$key}");
        }
    }
}
