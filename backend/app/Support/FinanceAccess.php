<?php

namespace App\Support;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\HttpException;

final class FinanceAccess
{
    public const CATALOG = ['finance.view','finance.transactions.view','finance.cash_accounts.view','finance.cash_accounts.manage','finance.cash_transfer.create','finance.cash_transfer.reverse','finance.expenses.view','finance.expenses.create','finance.expenses.edit','finance.expenses.submit','finance.expenses.approve','finance.expenses.reject','finance.expenses.pay','finance.expenses.reverse','finance.suppliers.view','finance.suppliers.manage','finance.supplier_invoices.view','finance.supplier_invoices.create','finance.supplier_invoices.edit','finance.supplier_invoices.post','finance.supplier_invoices.reverse','finance.supplier_payments.view','finance.supplier_payments.create','finance.supplier_payments.reverse','finance.journals.view','finance.journals.create','finance.journals.post','finance.journals.reverse','finance.reconciliation.view','finance.reconciliation.manage','finance.reconciliation.complete','finance.daily_closing.view','finance.daily_closing.manage','finance.daily_closing.close','finance.reports.view','finance.accounts.view','finance.accounts.manage','finance.periods.view','finance.periods.manage','finance.periods.close','finance.periods.lock','finance.settings.view','finance.settings.manage'];
    public static function actor(Request $request): object { $tenant=(int)$request->attributes->get('tenant_id',0); $auth=$request->attributes->get('auth_user'); $id=is_array($auth)?(int)($auth['id']??0):0; if(!$tenant||!$id) throw new HttpException(401,'Unauthenticated.'); $user=DB::table('users')->where('tenant_id',$tenant)->where('id',$id)->where('is_active',true)->whereNull('deleted_at')->first(['id','tenant_id','role']); if(!$user) throw new HttpException(401,'Unauthenticated.'); return $user; }
    public static function permissions(Request $request): array { $actor=self::actor($request); return self::permissionsFor((int)$actor->tenant_id, (string)$actor->role); }
    public static function permissionsFor(int $tenantId, string $role): array { if ($role==='owner') return self::CATALOG; return DB::table('finance_role_permissions')->where('tenant_id',$tenantId)->where('role',$role)->pluck('permission')->filter(fn($permission)=>in_array($permission,self::CATALOG,true))->values()->all(); }
    public static function defaultPermissionsForRole(string $role): array { return $role === 'manager' ? self::CATALOG : []; }
    public static function allows(Request $request,string $permission): bool { $actor=self::actor($request); return $actor->role==='owner'||in_array($permission,self::permissions($request),true); }
    public static function authorize(Request $request,string $permission): void { if(!self::allows($request,$permission)) throw new HttpException(403,'FINANCE_PERMISSION_DENIED'); }
    public static function capabilities(Request $request): array { return self::permissions($request); }
}
