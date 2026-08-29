<?php

namespace Tests\Feature;

use Tests\TestCase;

class TestingDatabaseConfigurationTest extends TestCase
{
    public function test_testing_environment_uses_the_isolated_postgresql_database(): void
    {
        $connection = config('database.default');
        $database = config("database.connections.{$connection}.database");

        $this->assertSame('testing', config('app.env'));
        $this->assertSame('pgsql', $connection);
        $this->assertSame('cafe_system_618_testing', $database);
        $this->assertNotSame('cafe_system_618', $database);
        $this->assertMatchesRegularExpression('/(?:_testing|_test)$/', $database);
    }
}
