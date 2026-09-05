<?php

namespace App\Console\Commands;

use App\Services\FinancialIntegrityService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

final class CheckFinancialIntegrity extends Command
{
    protected $signature = 'finance:integrity {tenant : Tenant slug}';

    protected $description = 'Read-only cross-module financial integrity diagnostic for one tenant';

    public function handle(FinancialIntegrityService $integrity): int
    {
        $slug = (string) $this->argument('tenant');
        $tenantId = DB::table('tenants')->where('slug', $slug)->whereNull('deleted_at')->value('id');
        if (! $tenantId) {
            $this->components->error("Tenant [{$slug}] was not found.");

            return self::FAILURE;
        }

        $result = $integrity->inspect((int) $tenantId);
        $this->line(json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

        return $result['status'] === 'FAIL' ? self::FAILURE : self::SUCCESS;
    }
}
