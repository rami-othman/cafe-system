<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use LogicException;

class TestingDatabaseSafetyServiceProvider extends ServiceProvider
{
    /**
     * Stop testing commands before they can migrate or truncate a non-test database.
     */
    public function register(): void
    {
        if (! $this->app->environment('testing')) {
            return;
        }

        $connection = config('database.default');
        $database = config("database.connections.{$connection}.database");

        if ($database === 'cafe_system_618') {
            throw new LogicException('Unsafe testing database configuration: cafe_system_618 is the development database and must never be used for tests.');
        }

        // Allows both the shared `..._testing` database and dedicated
        // isolated-lifecycle databases derived from it, e.g.
        // `..._testing_migrations` (see Tests\Concerns\UsesIsolatedMigrationDatabase).
        if (! is_string($database) || ! preg_match('/_test(?:ing)?(?:_\w+)?$/', $database)) {
            throw new LogicException(sprintf(
                'Unsafe testing database configuration: connection [%s] resolves to [%s]. Testing requires a database name ending in _testing or _test (optionally suffixed, e.g. _testing_migrations).',
                $connection,
                is_scalar($database) ? (string) $database : get_debug_type($database),
            ));
        }
    }
}
