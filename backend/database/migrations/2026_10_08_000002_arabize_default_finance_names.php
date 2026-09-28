<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('financial_accounts')->where('code', '1010')
            ->where('name_en', 'Cash Drawer')->where('name_ar', 'درج النقدية')
            ->update(['name_ar' => 'صندوق نقطة البيع']);
        DB::table('financial_accounts')->where('code', '2000')
            ->where('name_en', 'Accounts Payable')->where('name_ar', 'الحسابات الدائنة')
            ->update(['name_ar' => 'الذمم الدائنة – الموردون']);

        foreach ([
            ['CASH-DRAWER', 'Cash Drawer', 'صندوق نقطة البيع'],
            ['MAIN-SAFE', 'Main Safe', 'الخزنة الرئيسية'],
            ['BANK', 'Bank', 'البنك'],
        ] as [$code, $english, $arabic]) {
            DB::table('financial_locations')->where('code', $code)->where('name', $english)
                ->update(['name' => $arabic]);
        }
        $drawers = DB::table('financial_locations as l')->join('branches as b', function ($join): void {
            $join->on('b.id', '=', 'l.branch_id')->on('b.tenant_id', '=', 'l.tenant_id');
        })->where('l.code', 'like', 'CASH-DRAWER-BR-%')
            ->get(['l.id', 'l.code', 'l.branch_id', 'l.name', 'b.name as branch_name']);
        foreach ($drawers as $drawer) {
            if ($drawer->code === 'CASH-DRAWER-BR-'.$drawer->branch_id && $drawer->name === $drawer->branch_name.' Cash Drawer') {
                DB::table('financial_locations')->where('id', $drawer->id)
                    ->where('name', $drawer->name)->update(['name' => 'صندوق '.$drawer->branch_name]);
            }
        }
        DB::table('payment_methods')->where('code', 'CASH')->where('name', 'Cash')
            ->update(['name' => 'نقدي']);
    }

    public function down(): void
    {
        // Historical names and user edits are intentionally not rewritten.
    }
};
