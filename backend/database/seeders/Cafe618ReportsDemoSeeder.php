<?php

namespace Database\Seeders;

use App\Models\User;
use App\Services\ExpenseService;
use Illuminate\Database\Seeder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Report-ready operational history for the local Cafe 618 tenant.
 *
 * The detailed Reports screens consume dedicated reporting contracts in a
 * later backend phase.  This entry point prepares the source records those
 * contracts will use: real POS sales, cash/card payments, refunds, shifts,
 * cash transfers, reconciliations, daily closings, and overview history.
 *
 * Each delegated seeder is idempotent, so this command is safe to rerun in a
 * development database without duplicating the scenario.
 */
final class Cafe618ReportsDemoSeeder extends Seeder
{
    public function run(): void
    {
        if (! app()->environment(['local', 'development', 'testing'])) {
            throw new RuntimeException('Cafe618ReportsDemoSeeder is restricted to local, development, and testing environments.');
        }

        $this->call([
            Cafe618PosSalesDemoSeeder::class,
            Cafe618FinanceOperationsDemoSeeder::class,
            ReportsOverviewSeeder::class,
        ]);

        $this->seedCompanyWideExpense();
    }

    /**
     * Keep the reports fixture representative of the nullable branch_id
     * contract. The reports UI must show this row as company-wide rather than
     * dropping it from the all-branches view.
     */
    private function seedCompanyWideExpense(): void
    {
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $owner = User::query()->where('tenant_id', $tenantId)->where('role', 'owner')->first();
        $categoryId = (int) DB::table('expense_categories')
            ->where('tenant_id', $tenantId)
            ->where('code', 'CAFE618-OPERATIONS')
            ->whereNull('deleted_at')
            ->value('id');

        if (! $tenantId || ! $owner || ! $categoryId) {
            return;
        }

        $request = Request::create('/seed/cafe-618/reports/company-wide-expense', 'POST');
        $request->attributes->set('tenant_id', $tenantId);
        $request->attributes->set('auth_user', $owner);

        app(ExpenseService::class)->create($request, $tenantId, [
            'expenseCategoryId' => $categoryId,
            'amount' => '110.00',
            'expenseDate' => now()->startOfDay()->subDays(9)->toDateString(),
            'description' => 'Company-wide software and operations subscription',
            'idempotencyKey' => 'cafe-618-reports-company-wide-expense-'.now()->format('Ymd'),
        ], (int) $owner->id);
    }
}
