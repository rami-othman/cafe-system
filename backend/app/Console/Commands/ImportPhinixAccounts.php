<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use RuntimeException;

/** Imports the supplied account names and hierarchy, never balances or journals. */
final class ImportPhinixAccounts extends Command
{
    protected $signature = 'finance:import-phinix-accounts {tenantId : Existing tenant id} {--apply : Insert after a successful dry run}';

    protected $description = 'Validate and optionally import the supplied PHINIX account catalog; dry-run by default';

    public function handle(): int
    {
        $tenantId = (int) $this->argument('tenantId');
        if ($tenantId <= 0 || ! DB::table('tenants')->where('id', $tenantId)->exists()) {
            $this->error('The tenant does not exist.');

            return self::FAILURE;
        }
        $path = base_path('resources/finance/phinix_accounts.csv');
        try {
            $rows = $this->parse($path);
            $this->preflight($tenantId, $rows);
            $existing = $this->existingByCode($tenantId, $rows)->count();
            $this->table(['Catalog rows', 'Already present', 'To insert', 'SHA-256'], [[count($rows), $existing, count($rows) - $existing, hash_file('sha256', $path)]]);
            if (! $this->option('apply')) {
                $this->info('Dry run only. Use --apply to add missing accounts after reviewing the counts.');

                return self::SUCCESS;
            }
            $inserted = DB::transaction(function () use ($tenantId, $rows): int {
                // Recheck inside the transaction so existing accounting accounts are never overwritten.
                $this->preflight($tenantId, $rows);
                $hasCatalogSource = Schema::hasColumn('financial_accounts', 'catalog_source');
                if ($hasCatalogSource) {
                    foreach (array_chunk(array_column($rows, 'code'), 500) as $codes) {
                        DB::table('financial_accounts')->where('tenant_id', $tenantId)
                            ->whereIn('code', $codes)->whereNull('catalog_source')
                            ->update(['catalog_source' => 'phinix']);
                    }
                }
                $byCode = DB::table('financial_accounts')->where('tenant_id', $tenantId)->get(['id', 'code'])->keyBy('code');
                $count = 0;
                foreach ($rows as $row) {
                    if ($byCode->has($row['code'])) {
                        continue;
                    }
                    $parentId = $row['parentCode'] === null ? null : $byCode->get($row['parentCode'])?->id;
                    if ($row['parentCode'] !== null && $parentId === null) {
                        throw new RuntimeException("Parent account missing for code {$row['code']}.");
                    }
                    $payload = [
                        'tenant_id' => $tenantId,
                        'parent_account_id' => $parentId,
                        'code' => $row['code'],
                        'name_ar' => $row['name'],
                        // The source has no English names; retaining the supplied name is safer than inventing translations.
                        'name_en' => $row['name'],
                        'account_group' => $row['group'],
                        'normal_balance' => $row['normal'],
                        'is_active' => $row['isActive'],
                        'is_system_protected' => false,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ];
                    if ($hasCatalogSource) {
                        $payload['catalog_source'] = 'phinix';
                    }
                    $id = DB::table('financial_accounts')->insertGetId($payload);
                    $byCode->put($row['code'], (object) ['id' => $id]);
                    $count++;
                }

                return $count;
            });
            $this->info("Inserted {$inserted} account definitions. No journals, balances, mappings or cash locations were changed.");

            return self::SUCCESS;
        } catch (RuntimeException $error) {
            $this->error($error->getMessage());

            return self::FAILURE;
        }
    }

    /** @return array<int, array{code:string,name:string,parentCode:?string,group:string,normal:string,isContra:bool,categoryOverride:bool,isActive:bool,isPartyDetail:bool}> */
    private function parse(string $path): array
    {
        $file = fopen($path, 'rb');
        if ($file === false) {
            throw new RuntimeException('Catalog file is unavailable.');
        }
        try {
            $header = fgetcsv($file);
            if ($header === false) {
                throw new RuntimeException('Catalog is empty.');
            }
            $header[0] = preg_replace('/^\xEF\xBB\xBF/', '', $header[0]);
            if ($header !== ['الحساب', 'الحساب الرئيسي', 'ختامي']) {
                throw new RuntimeException('Unexpected catalog header.');
            }
            $rows = [];
            $stack = [];
            $codes = [];
            $line = 1;
            while (($cells = fgetcsv($file)) !== false) {
                $line++;
                if (count($cells) !== 3 || ! preg_match('/^( *)([0-9]{1,40})-(.+)$/u', $cells[0], $match)) {
                    throw new RuntimeException("Invalid account row {$line}.");
                }
                $spaces = strlen($match[1]);
                $depth = intdiv($spaces, 3);
                $code = $match[2];
                $name = trim($match[3]);
                if ($spaces < 3 || $spaces % 3 !== 0 || $depth > count($stack) + 1 || $name === '' || isset($codes[$code])) {
                    throw new RuntimeException("Invalid hierarchy or duplicate code at row {$line}.");
                }
                while (count($stack) >= $depth) {
                    array_pop($stack);
                }
                $parent = $stack === [] ? null : $stack[count($stack) - 1];
                if (trim($cells[1]) !== ($parent['name'] ?? '')) {
                    throw new RuntimeException("Parent name differs at row {$line}.");
                }
                if (! in_array($cells[2], ['الميزانية', 'المتاجرة', 'الأرباح والخسائر'], true)) {
                    throw new RuntimeException("Unknown statement section at row {$line}.");
                }
                $categoryOverride = $code === '211';
                $isPartyDetail = $parent !== null &&
                    (in_array($parent['code'], ['121', '223'], true) || $parent['isPartyDetail']);
                $isActive = ! $isPartyDetail;
                $group = $categoryOverride ? 'equity' : ($parent['group'] ?? match ($code) {
                    '1' => 'assets', '2' => 'liabilities', '3' => 'cost_of_sales',
                    '4', '6' => 'revenue', '5' => 'expenses',
                    default => throw new RuntimeException("Unknown root code at row {$line}."),
                });
                $normal = $parent['normal'] ?? (in_array($group, ['assets', 'cost_of_sales', 'expenses'], true) ? 'debit' : 'credit');
                $isContra = in_array($code, ['32', '34', '42', '43'], true) || str_starts_with($name, 'مجمع اهتلاك');
                if ($isContra) {
                    $normal = $normal === 'debit' ? 'credit' : 'debit';
                }
                $row = compact('code', 'name', 'group', 'normal', 'isContra', 'categoryOverride', 'isActive', 'isPartyDetail')
                    + ['parentCode' => $parent['code'] ?? null];
                $rows[] = $row;
                $codes[$code] = true;
                $stack[] = $row;
            }
            if (count($rows) !== 5075) {
                throw new RuntimeException('Catalog row count differs from the reviewed source.');
            }

            return $rows;
        } finally {
            fclose($file);
        }
    }

    private function preflight(int $tenantId, array $rows): void
    {
        $existing = $this->existingByCode($tenantId, $rows);
        $byId = $existing->keyBy('id');
        foreach ($rows as $row) {
            $found = $existing->get($row['code']);
            if (! $found) {
                continue;
            }
            $parentCode = $found->parent_account_id ? ($byId->get($found->parent_account_id)?->code
                ?? DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', $found->parent_account_id)->value('code')) : null;
            if ($found->deleted_at !== null || $found->name_ar !== $row['name'] || $found->account_group !== $row['group']
                || $found->normal_balance !== $row['normal'] || $parentCode !== $row['parentCode']) {
                throw new RuntimeException("Existing account {$row['code']} conflicts with the source catalog; nothing was imported.");
            }
        }
    }

    private function existingByCode(int $tenantId, array $rows): \Illuminate\Support\Collection
    {
        $existing = collect();
        foreach (array_chunk(array_column($rows, 'code'), 500) as $codes) {
            foreach (DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereIn('code', $codes)
                ->get(['id', 'code', 'name_ar', 'account_group', 'normal_balance', 'parent_account_id', 'deleted_at']) as $account) {
                $existing->put($account->code, $account);
            }
        }

        return $existing;
    }
}
