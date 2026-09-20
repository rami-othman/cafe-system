<?php

namespace Tests\Concerns;

/**
 * For the handful of tests that need `DatabaseMigrations`' real
 * migrate:fresh/migrate:rollback lifecycle (testing migrations/commands
 * themselves) or that fork separate worker processes needing to see
 * committed rows across real connections — both incompatible with
 * `RefreshDatabase`'s wrapping transaction.
 *
 * Running that lifecycle against the same physical database the rest of
 * the suite shares via `RefreshDatabase` corrupts its schema mid-run (a
 * `migrate:fresh` mid-suite drops tables other tests' transactions still
 * expect to exist). Pointing these tests at their own database keeps the
 * lifecycle real without ever touching the shared schema.
 *
 * Must be combined with `Illuminate\Foundation\Testing\DatabaseMigrations`
 * on the test class; this only redirects which connection that trait
 * operates on, via its `beforeRefreshingDatabase()` hook.
 */
trait UsesIsolatedMigrationDatabase
{
    protected function beforeRefreshingDatabase()
    {
        config(['database.default' => 'pgsql_migrations']);
    }
}
