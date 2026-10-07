<?php

namespace App\Console\Commands;

use App\Services\FixedAssets\DepreciationCalculator;
use App\Services\FixedAssets\FixedAssetService;
use App\Support\Money;
use Illuminate\Console\Command;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Imports existing assets (e.g. from Phinix) as OPENING assets: card + cost + accumulated
 * depreciation + "depreciated until", without posting any journal entry (the balances are
 * already in the ledger). Dry run by default; prints a reconciliation per category against the
 * ledger balances of the category's asset / accumulated accounts.
 *
 * CSV header (UTF-8, comma): code,name,category,branch,acquisition_date,start_date,cost,accumulated,depreciated_until,life_months,salvage,method
 *   category = category code or Arabic name; branch = branch name (empty = head office);
 *   cost = original cost + additions; method = straight_line|declining_balance|none (default straight_line).
 */
class ImportOpeningAssets extends Command
{
    protected $signature = 'assets:import-opening {tenant} {file} {--apply : write the assets (otherwise dry run)}';

    protected $description = 'Import existing fixed assets as opening balances (no journal entries).';

    public function handle(FixedAssetService $assets): int
    {
        $tenant = (int) $this->argument('tenant');
        $file = (string) $this->argument('file');
        if (! is_readable($file)) {
            $this->error("Cannot read {$file}");

            return self::FAILURE;
        }
        $rows = $this->rows($file);
        $categories = DB::table('asset_categories')->where('tenant_id', $tenant)->whereNull('deleted_at')->get();
        $branches = DB::table('branches')->where('tenant_id', $tenant)->whereNull('deleted_at')->pluck('id', 'name');
        $owner = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->orderBy('id')->value('id');
        $problems = [];
        $plan = [];
        foreach ($rows as $i => $row) {
            $line = $i + 2;
            $category = $categories->first(fn ($c) => $c->code === trim($row['category'] ?? '') || $c->name_ar === trim($row['category'] ?? ''));
            if (! $category) {
                $problems[] = "سطر {$line}: الصنف «{$row['category']}» غير موجود.";

                continue;
            }
            $branchName = trim($row['branch'] ?? '');
            $branchId = $branchName === '' ? null : ($branches[$branchName] ?? null);
            if ($branchName !== '' && $branchId === null) {
                $problems[] = "سطر {$line}: الفرع «{$branchName}» غير موجود.";

                continue;
            }
            $method = trim($row['method'] ?? '') ?: 'straight_line';
            $life = (int) ($row['life_months'] ?? 0);
            if (DepreciationCalculator::depreciates($method) && $life <= 0) {
                $problems[] = "سطر {$line}: العمر بالأشهر مطلوب للقسط الثابت ({$row['name']}).";
            }
            $plan[] = [
                'code' => trim($row['code'] ?? ''), 'nameAr' => trim($row['name']), 'categoryId' => (int) $category->id, 'branchId' => $branchId,
                'acquisitionDate' => trim($row['acquisition_date']), 'depreciationStartDate' => trim($row['start_date'] ?? '') ?: trim($row['acquisition_date']),
                'acquisitionCost' => $this->amount($row['cost'] ?? '0'), 'openingAccumulated' => $this->amount($row['accumulated'] ?? '0'),
                'openingDepreciatedUntil' => trim($row['depreciated_until'] ?? '') ?: null, 'usefulLifeMonths' => $life,
                'salvageValue' => $this->amount($row['salvage'] ?? '0'), 'method' => $method, 'isOpening' => true, 'activate' => true,
                '_category' => $category,
            ];
        }
        $duplicates = collect($plan)->groupBy(fn ($p) => $p['nameAr'].'|'.$p['acquisitionCost'].'|'.$p['branchId'])->filter(fn ($g) => $g->count() > 1);
        foreach ($duplicates as $group) {
            $this->warn('تنبيه تكرار محتمل: «'.$group->first()['nameAr'].'» × '.$group->count().' بنفس الكلفة والفرع.');
        }

        $this->table(['الصنف', 'عدد', 'الكلفة', 'المجمع', 'رصيد حساب الأصل', 'رصيد المجمع'], collect($plan)->groupBy(fn ($p) => $p['categoryId'])->map(function ($group) use ($tenant) {
            $c = $group->first()['_category'];
            $balance = fn ($account) => $account ? Money::decimal(Money::cents((string) DB::table('journal_entry_lines as l')->join('journal_entries as e', 'e.id', '=', 'l.journal_entry_id')
                ->where('l.tenant_id', $tenant)->where('e.status', 'posted')->where('l.financial_account_id', $account)->sum(DB::raw('l.debit - l.credit')))) : '—';

            return [$c->name_ar, $group->count(), Money::decimal($group->sum(fn ($p) => Money::cents($p['acquisitionCost']))),
                Money::decimal($group->sum(fn ($p) => Money::cents($p['openingAccumulated']))), $balance($c->asset_account_id), $balance($c->accumulated_account_id)];
        })->values()->all());

        foreach ($problems as $problem) {
            $this->error($problem);
        }
        if ($problems !== []) {
            return self::FAILURE;
        }
        if (! $this->option('apply')) {
            $this->info('Dry run: '.count($plan).' assets ready. Re-run with --apply to write them.');

            return self::SUCCESS;
        }
        $request = Request::create('/console/assets-import', 'POST');
        DB::transaction(function () use ($plan, $assets, $request, $tenant, $owner): void {
            foreach ($plan as $data) {
                unset($data['_category']);
                $assets->create($request, $tenant, $data, $owner ?: null);
            }
        });
        $this->info('Imported '.count($plan).' opening assets.');

        return self::SUCCESS;
    }

    private function rows(string $file): array
    {
        $handle = fopen($file, 'r');
        $header = fgetcsv($handle);
        if (! $header) {
            throw new RuntimeException('Empty file.');
        }
        $header = array_map(fn ($h) => trim(preg_replace('/^\xEF\xBB\xBF/', '', (string) $h)), $header);
        $rows = [];
        while (($cells = fgetcsv($handle)) !== false) {
            if (count(array_filter($cells, fn ($c) => trim((string) $c) !== '')) === 0) {
                continue;
            }
            $rows[] = array_combine($header, array_pad($cells, count($header), ''));
        }
        fclose($handle);

        return $rows;
    }

    private function amount(string $value): string
    {
        $clean = str_replace([',', ' '], '', trim($value));

        return Money::decimal((int) round(((float) ($clean === '' ? '0' : $clean)) * 100));
    }
}
