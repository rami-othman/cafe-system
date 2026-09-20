<?php

namespace App\Support;

use App\Models\User;
use App\Services\DefaultTenantRoleService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\HttpException;

final class FinanceAccess
{
    public const CATALOG = ['finance.cash_sources.view','finance.view','finance.transactions.view','finance.cash_accounts.view','finance.cash_accounts.manage','finance.cash_transfer.create','finance.cash_transfer.reverse','finance.vouchers.view','finance.vouchers.create','finance.vouchers.edit','finance.vouchers.approve','finance.vouchers.post','finance.vouchers.reverse','finance.receipts.create','finance.payments.create','finance.transfers.create','finance.expenses.view','finance.expenses.create','finance.expenses.edit','finance.expenses.submit','finance.expenses.approve','finance.expenses.reject','finance.expenses.pay','finance.expenses.reverse','finance.suppliers.view','finance.suppliers.manage','finance.supplier_invoices.view','finance.supplier_invoices.create','finance.supplier_invoices.edit','finance.supplier_invoices.post','finance.supplier_invoices.reverse','finance.supplier_payments.view','finance.supplier_payments.create','finance.supplier_payments.reverse','finance.purchases.view','finance.purchases.create','finance.purchases.edit','finance.purchases.post','finance.purchases.receive','finance.sales.view','finance.sales.create','finance.sales.edit','finance.sales.post','finance.sales.reverse','finance.sales.override_price','finance.sales.adjust_total','finance.customers.view','finance.customers.create','finance.customers.edit','finance.customer_payments.view','finance.customer_payments.create','finance.customer_payments.reverse','finance.sales_credit_notes.view','finance.sales_credit_notes.create','finance.sales_credit_notes.post','finance.customer_refunds.view','finance.customer_refunds.create','finance.journals.view','finance.journals.create','finance.journals.post','finance.journals.reverse','finance.reconciliation.view','finance.reconciliation.manage','finance.reconciliation.complete','finance.daily_closing.view','finance.daily_closing.manage','finance.daily_closing.close','finance.reports.view','finance.accounts.view','finance.accounts.manage','finance.periods.view','finance.periods.manage','finance.periods.close','finance.periods.lock','finance.settings.view','finance.settings.manage'];
    public static function actor(Request $request): User { $tenant=(int)$request->attributes->get('tenant_id',0); $auth=$request->attributes->get('auth_user'); if(!$tenant || ! $auth instanceof User) throw new HttpException(401,'Unauthenticated.'); $user=User::query()->with('tenantRole')->where('tenant_id',$tenant)->where('id',$auth->id)->where('is_active',true)->first(); if(!$user) throw new HttpException(401,'Unauthenticated.'); return $user; }
    public static function permissions(Request $request): array { $actor=self::actor($request); return self::permissionsFor((int)$actor->tenant_id, app(DefaultTenantRoleService::class)->canonicalLegacyRole($actor->effectiveRoleCode())); }
    /**
     * Owner is the only role with an implicit, code-granted permission set
     * (the full catalog). Every other role — including manager — is governed
     * entirely by finance_role_permissions, which FinanceRolePermissionController
     * treats as the authoritative, owner-editable list for that role
     * (see its `replace` endpoint). The one exception is cashier's baseline:
     * commit f58c61c gave cashiers a fixed set of document workflows that is
     * always active without per-tenant seeding, unioned with any tenant-specific
     * extras in the table. Manager has no such code-granted baseline — union'ing
     * defaultPermissionsForRole('manager') here would silently make the
     * finance_role_permissions table inert for managers (see
     * FinanceRolePermissionController::replace's "Only an owner can modify
     * Finance role permissions" contract and the "grant X to existing managers"
     * migrations, which only make sense if manager permissions are truly
     * table-driven).
     */
    public static function permissionsFor(int $tenantId, string $role): array { if ($role==='owner') return self::CATALOG; $granted = DB::table('finance_role_permissions')->where('tenant_id',$tenantId)->where('role',$role)->pluck('permission')->filter(fn($permission)=>in_array($permission,self::CATALOG,true))->values()->all(); if ($role === 'manager') return array_values(array_unique($granted)); return array_values(array_unique([...self::defaultPermissionsForRole($role), ...$granted])); }
    /** Also used by migrations/tests as the full permission set to seed for a "fully trusted manager" fixture. It is not applied live for manager — see permissionsFor(). */
    public static function defaultPermissionsForRole(string $role): array {
        if ($role === 'manager') return self::CATALOG;
        // A cashier has only the document workflows exposed by the limited
        // Finance shell. No journals, accounts, reports, reconciliation,
        // financial settings, reversal, or approval permission is granted.
        if ($role === 'cashier') return ['finance.cash_sources.view',
            // Note: finance.vouchers.view, finance.purchases.view and
            // finance.sales.view are deliberately excluded from the baseline
            // — a cashier can create/edit/post/receive their own operational
            // documents (and read them back via the create/post/preview
            // response bodies) without being able to browse the vouchers,
            // purchases or sales list/show endpoints, which stay a
            // per-tenant grant (see CashierDashboardApiTest).
            'finance.vouchers.create', 'finance.vouchers.post',
            'finance.receipts.create', 'finance.payments.create',
            'finance.purchases.create', 'finance.purchases.edit', 'finance.purchases.post', 'finance.purchases.receive',
            'finance.supplier_invoices.view', 'finance.supplier_invoices.create', 'finance.supplier_invoices.edit', 'finance.supplier_invoices.post',
            'finance.sales.create', 'finance.sales.edit', 'finance.sales.post',
            'finance.customers.view', 'finance.suppliers.view',
        ];
        return [];
    }
    public static function allows(Request $request,string $permission): bool { $actor=self::actor($request); return $actor->effectiveRoleCode()==='owner'||in_array($permission,self::permissions($request),true); }
    public static function authorize(Request $request,string $permission): void { if(!self::allows($request,$permission)) throw new HttpException(403,'FINANCE_PERMISSION_DENIED'); }
    public static function capabilities(Request $request): array { return self::permissions($request); }
}
