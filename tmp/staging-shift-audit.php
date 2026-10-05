<?php
require '/var/www/cafe-system-staging/backend/vendor/autoload.php';
$app = require '/var/www/cafe-system-staging/backend/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use Illuminate\Support\Facades\DB;
if (!app()->environment('staging') || DB::connection()->getDatabaseName() !== 'cafe618_staging') throw new RuntimeException('Wrong target');
$report = [];
$report['branches'] = DB::table('branches')->whereNull('deleted_at')->get(['id','tenant_id','name','pos_cash_financial_location_id','shift_close_destination_financial_location_id','shift_closing_float_amount']);
$report['locations'] = DB::table('financial_locations as l')->join('financial_accounts as a','a.id','=','l.financial_account_id')->get(['l.id','l.tenant_id','l.branch_id','l.code','l.name','l.type','l.is_active','a.code as account_code','a.id as account_id']);
$report['open_shifts'] = DB::table('shifts')->where('status','open')->whereNull('deleted_at')->get(['id','tenant_id','branch_id','user_id','financial_location_id','opening_cash','closing_float_amount','close_destination_financial_location_id','opened_at']);
$report['cash_methods'] = DB::table('payment_methods as p')->join('financial_accounts as a','a.id','=','p.financial_account_id')->where('p.type','cash')->get(['p.id','p.tenant_id','p.code','p.financial_location_id','a.code as account_code']);
$report['131_lines'] = DB::table('journal_entry_lines as l')->join('financial_accounts as a','a.id','=','l.financial_account_id')->join('journal_entries as e','e.id','=','l.journal_entry_id')->where('a.code','131')->get(['l.id','l.tenant_id','l.financial_location_id','l.debit','l.credit','e.id as journal_id','e.branch_id','e.source_type','e.source_id','e.status','e.description']);
foreach ($report['branches'] as $b) $report['readiness'][$b->id] = app(App\Services\ShiftDrawerReadinessService::class)->payload($b->tenant_id,$b->id);
$report['cash_balances'] = DB::select("SELECT a.id,a.code,a.name_ar,a.is_active,l.financial_location_id,SUM(CASE WHEN e.status='posted' THEN l.debit-l.credit ELSE 0 END) AS balance FROM financial_accounts a LEFT JOIN journal_entry_lines l ON l.financial_account_id=a.id LEFT JOIN journal_entries e ON e.id=l.journal_entry_id WHERE a.code IN ('1010','1020','131','132','139') AND a.tenant_id=1 GROUP BY a.id,l.financial_location_id ORDER BY a.code,l.financial_location_id");
$report['legacy_cash_lines'] = DB::table('journal_entry_lines as l')->join('financial_accounts as a','a.id','=','l.financial_account_id')->join('journal_entries as e','e.id','=','l.journal_entry_id')->whereIn('a.code',['1010','139'])->get(['l.id','a.code','l.financial_location_id','l.debit','l.credit','e.id as journal_id','e.branch_id','e.source_type','e.source_id','e.status','e.description']);
$report['shift_orders'] = DB::table('orders')->where('shift_id',21)->whereNull('deleted_at')->get(['id','branch_id','shift_id','status','total']);
$report['recent_shifts'] = DB::table('shifts')->orderByDesc('id')->limit(4)->get(['id','branch_id','user_id','financial_location_id','status','close_type','opening_cash','closing_cash','expected_cash','closing_float_amount','opened_at']);
$report['references'] = DB::select("SELECT table_name,column_name FROM information_schema.columns WHERE table_schema='public' AND (column_name LIKE '%financial_location_id' OR column_name LIKE '%financial_account_id' OR column_name LIKE '%account_id') ORDER BY table_name,column_name");
echo json_encode($report, JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR);

