<?php

namespace App\Console\Commands;

use App\Services\Staging\StagingInitializer;
use Illuminate\Console\Command;

class InitializeStaging extends Command
{
    protected $signature = 'staging:initialize {--confirm-staging : Required acknowledgement that this writes the approved staging database}';

    protected $description = 'Create the small, idempotent Cafe System 618 staging environment.';

    public function handle(StagingInitializer $initializer): int
    {
        if (! $this->option('confirm-staging')) {
            return $this->failStaging('Refusing to initialize staging without --confirm-staging.');
        }
        if (app()->environment() !== 'staging' || app()->environment('testing')) {
            return $this->failStaging('This command is restricted to APP_ENV=staging.');
        }
        if (config('database.default') !== 'pgsql') {
            return $this->failStaging('This command requires the PostgreSQL connection.');
        }
        if ($this->databaseHost() !== 'aws-0-eu-central-1.pooler.supabase.com' || $this->databaseName() !== 'postgres') {
            return $this->failStaging('This command is restricted to the approved Supabase staging Session Pooler database.');
        }

        $credentials = [
            'ownerPassword' => (string) env('STAGING_OWNER_PASSWORD'),
            'managerPassword' => (string) env('STAGING_MANAGER_PASSWORD'),
            'employeePassword' => (string) env('STAGING_EMPLOYEE_PASSWORD'),
            'ownerEmail' => (string) env('STAGING_OWNER_EMAIL', 'staging-owner@cafe618.invalid'),
            'managerEmail' => (string) env('STAGING_MANAGER_EMAIL', 'staging-manager@cafe618.invalid'),
            'employeeEmail' => (string) env('STAGING_EMPLOYEE_EMAIL', 'staging-cashier@cafe618.invalid'),
            'employeeUsername' => (string) env('STAGING_EMPLOYEE_USERNAME', 'staging-cashier'),
        ];
        if (collect($credentials)->only(['ownerPassword', 'managerPassword', 'employeePassword'])->contains(fn (string $value) => $value === '')) {
            return $this->failStaging('Set the three STAGING_*_PASSWORD environment values in ignored .env.staging before running this command.');
        }

        $tenant = $initializer->initialize($credentials);
        $this->info("Staging initializer completed for tenant {$tenant->id}. No credentials were printed.");

        return self::SUCCESS;
    }

    private function databaseHost(): string
    {
        $url = (string) config('database.connections.pgsql.url');
        $urlHost = $url === '' ? null : parse_url($url, PHP_URL_HOST);

        return (string) ($urlHost ?: config('database.connections.pgsql.host'));
    }

    private function databaseName(): string
    {
        $url = (string) config('database.connections.pgsql.url');
        $urlDatabase = $url === '' ? null : parse_url($url, PHP_URL_PATH);

        return ltrim((string) ($urlDatabase ?: config('database.connections.pgsql.database')), '/');
    }

    private function failStaging(string $message): int
    {
        $this->error($message);

        return self::FAILURE;
    }
}
