<?php

namespace Database\Seeders;

use App\Services\FinancialSetupService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class FinancialInventoryFoundationSeeder extends Seeder
{
    public function run(): void
    {
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $managerId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('email', 'manager@cafe618.local')->value('id');
        app(FinancialSetupService::class)->ensureForTenant($tenantId, null, $managerId);

        $now = now();
        $branches = DB::table('branches')->where('tenant_id', $tenantId)->whereNull('deleted_at')->orderBy('id')->get();
        foreach ($branches as $branch) {
            app(FinancialSetupService::class)->ensureBranchMainWarehouse($tenantId, (int) $branch->id, $managerId);
            foreach ([
                ['suffix' => 'BAR', 'name' => 'البار - '.$branch->name, 'type' => 'bar', 'notes' => 'موقع استهلاك وتجهيز المشروبات.'],
                ['suffix' => 'KITCHEN', 'name' => 'المطبخ - '.$branch->name, 'type' => 'kitchen', 'notes' => 'موقع استهلاك وتجهيز الطعام.'],
            ] as $location) {
                DB::table('warehouses')->updateOrInsert(
                    ['tenant_id' => $tenantId, 'code' => 'BR-'.$branch->id.'-'.$location['suffix']],
                    [
                        'branch_id' => $branch->id,
                        'name' => $location['name'],
                        'type' => $location['type'],
                        'is_active' => true,
                        'notes' => $location['notes'],
                        'created_by' => $managerId,
                        'updated_by' => $managerId,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ],
                );
            }
        }

        foreach ($branches as $branch) {
            foreach (['BAR' => 'Bar', 'KITCHEN' => 'Kitchen'] as $suffix => $label) {
                DB::table('warehouses')
                    ->where('tenant_id', $tenantId)
                    ->where('code', 'BR-'.$branch->id.'-'.$suffix)
                    ->update([
                        'name' => $branch->name.' — '.$label,
                        'notes' => $label === 'Bar'
                            ? 'Beverage preparation and consumption location.'
                            : 'Food preparation and consumption location.',
                        'updated_at' => $now,
                    ]);
            }
        }

        $entryId = DB::table('journal_entries')->where('tenant_id', $tenantId)->where('entry_number', 'SETUP-OPENING-0001')->value('id');
        if ($entryId) {
            return;
        }

        $entryId = DB::table('journal_entries')->insertGetId([
            'tenant_id' => $tenantId,
            'entry_number' => 'SETUP-OPENING-0001',
            'entry_date' => '2026-08-16',
            'source_type' => 'foundation_seed',
            'description' => 'قيد افتتاحي تجريبي لإعداد النظام المالي.',
            'status' => 'posted',
            'created_by' => $managerId,
            'posted_by' => $managerId,
            'posted_at' => '2026-08-16 09:00:00',
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $accounts = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereIn('code', ['1010', '1020', '3000'])->pluck('id', 'code');
        foreach ([
            ['code' => '1010', 'debit' => '2500.00', 'credit' => '0.00', 'description' => 'رصيد درج النقدية الافتتاحي.'],
            ['code' => '1020', 'debit' => '10000.00', 'credit' => '0.00', 'description' => 'رصيد الخزنة الافتتاحي.'],
            ['code' => '3000', 'debit' => '0.00', 'credit' => '12500.00', 'description' => 'رأس المال الافتتاحي.'],
        ] as $number => $line) {
            DB::table('journal_entry_lines')->insert([
                'tenant_id' => $tenantId,
                'journal_entry_id' => $entryId,
                'financial_account_id' => $accounts[$line['code']],
                'line_number' => $number + 1,
                'description' => $line['description'],
                'debit' => $line['debit'],
                'credit' => $line['credit'],
                'created_by' => $managerId,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }
}
