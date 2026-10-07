<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\FinanceAccountMap;
use App\Services\OperationalAuditService;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * View and change which ledger account each kind of posting uses (revenue, tax, COGS, inventory, variances,
 * cash over/short). The owner picks the account; the server only accepts a leaf account of the right kind.
 */
final class AccountMappingController extends Controller
{
    /** key => [label, hint, [[group, normalBalance|null], ...]] */
    public const META = [
        'sales.revenue' => ['إيراد المبيعات', 'الحساب الذي يُرحَّل إليه ثمن البيع (قبل الخصم والضريبة).', [['revenue', 'credit']]],
        'sales.discount_given' => ['خصومات المبيعات', 'الخصم الممنوح للعملاء (يُرحَّل مدينًا).', [['revenue', 'debit'], ['expenses', 'debit']]],
        'sales.sales_returns' => ['مردودات المبيعات', 'المبيعات المرتجعة (يُرحَّل مدينًا).', [['revenue', 'debit']]],
        'sales.tax_payable' => ['ضريبة المبيعات المستحقة', 'الضريبة المحصَّلة من العملاء وهي التزام للدولة.', [['liabilities', 'credit']]],
        'sales.cost_of_goods_sold' => ['تكلفة المبيعات', 'تكلفة المواد المباعة (تُسجَّل عند كل بيع).', [['cost_of_sales', 'debit']]],
        'sales.inventory_asset' => ['المخزون', 'قيمة المواد في المستودعات.', [['assets', 'debit']]],
        'sales.accounts_receivable' => ['الذمم المدينة (العملاء)', 'الحساب العام لمديونية العملاء.', [['assets', 'debit']]],
        'sales.customer_credit' => ['أرصدة دائنة للعملاء', 'الأموال المحتفظ بها للعملاء (محافظ، دفعات مقدمة).', [['liabilities', 'credit']]],
        'sales.additional_charge_revenue' => ['إيراد الرسوم الإضافية', 'رسوم التوصيل والخدمة على فواتير المبيعات.', [['revenue', 'credit']]],
        'sales.manual_adjustment' => ['تسويات المبيعات اليدوية', 'التعديلات اليدوية على إجمالي فاتورة البيع.', [['revenue', 'credit']]],
        'inventory.variance' => ['فروقات وهدر المخزون', 'نقص أو زيادة الجرد والهدر.', [['expenses', 'debit'], ['cost_of_sales', 'debit']]],
        'inventory.opening_equity' => ['مقابل المخزون الافتتاحي', 'الطرف المقابل لقيد المخزون الافتتاحي (حقوق الملكية).', [['equity', 'credit']]],
        'cash.short' => ['عجز الصندوق (الافتراضي)', 'يُستخدم إن لم يحدد الفرع حساب العجز الخاص به.', [['expenses', 'debit']]],
        'cash.over' => ['زيادة الصندوق (الافتراضي)', 'يُستخدم إن لم يحدد الفرع حساب الزيادة الخاص به.', [['revenue', 'credit']]],
        'cash.drawer' => ['درج الكاشير (الافتراضي)', 'حساب درج الصندوق عند إنشاء فرع جديد.', [['assets', 'debit']]],
        'assets.gain' => ['أرباح رأسمالية', 'ربح بيع الأصول الثابتة (الافتراضي إن لم يحدده صنف الأصل).', [['revenue', 'credit']]],
        'assets.loss' => ['خسائر رأسمالية', 'خسارة بيع/استبعاد الأصول الثابتة (الافتراضي).', [['expenses', 'debit']]],
        'partners.distribution' => ['توزيعات أرباح الفروع', 'الطرف المدين عند توزيع نتيجة فرع على الشركاء (حقوق ملكية).', [['equity', 'debit']]],
        'branches.inter_branch' => ['جاري الفروع', 'حساب وسيط يوازن كل فرع عندما يتوزع قيد واحد على أكثر من فرع (نقل أصل، توزيع مصروف). مجموعه على مستوى الشركة صفر.', [['assets', 'debit'], ['liabilities', 'credit']]],
    ];

    public function __construct(private readonly FinanceAccountMap $map, private readonly OperationalAuditService $audit) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $rows = [];
        foreach (self::META as $key => [$label, $hint, $rules]) {
            $account = $this->map->account($tenantId, $key);
            $name = $account ? DB::table('financial_accounts')->where('id', $account->id)->value('name_ar') : null;
            $rows[] = [
                'key' => $key, 'label' => $label, 'hint' => $hint,
                'accountId' => $account ? (int) $account->id : null,
                'accountCode' => $account?->code, 'accountName' => $name,
                'allowedGroups' => array_values(array_unique(array_column($rules, 0))),
                'needsDefault' => ! $this->isUsable($tenantId, $key),
                'isCustom' => DB::table('sales_account_mappings')->where('tenant_id', $tenantId)->where('mapping_key', $key)->exists(),
            ];
        }

        return response()->json(['data' => $rows]);
    }

    public function update(Request $request, string $key): JsonResponse
    {
        if (! array_key_exists($key, self::META)) {
            throw ValidationException::withMessages(['key' => 'نوع الربط غير معروف.']);
        }
        $tenantId = TenantContext::id($request);
        $data = $request->validate(['accountId' => ['required', 'integer']]);
        $account = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('id', (int) $data['accountId'])
            ->where('is_active', true)->whereNull('deleted_at')->first(['id', 'code', 'name_ar', 'account_group', 'normal_balance']);
        if (! $account) {
            throw ValidationException::withMessages(['accountId' => 'الحساب غير موجود أو غير مفعّل.']);
        }
        $problem = $this->problem($tenantId, $key, $account);
        if ($problem !== null) {
            throw ValidationException::withMessages(['accountId' => $problem]);
        }
        $before = $this->map->account($tenantId, $key)?->code;
        DB::table('sales_account_mappings')->updateOrInsert(
            ['tenant_id' => $tenantId, 'mapping_key' => $key],
            ['financial_account_id' => $account->id, 'updated_at' => now(), 'created_at' => now()],
        );
        $this->audit->record($request, $tenantId, 'finance.account_mapping.changed', 'account_mapping', (int) $account->id,
            ['key' => $key, 'code' => $before], ['key' => $key, 'code' => $account->code], null, FinancialActor::id($request, $tenantId));

        return response()->json(['data' => ['key' => $key, 'accountId' => (int) $account->id, 'accountCode' => $account->code, 'accountName' => $account->name_ar]]);
    }

    /** Why $account cannot serve $key (Arabic), or null when it is acceptable. */
    private function problem(int $tenantId, string $key, object $account): ?string
    {
        $allowed = false;
        foreach (self::META[$key][2] as [$group, $normal]) {
            if ($account->account_group === $group && ($normal === null || $account->normal_balance === $normal)) {
                $allowed = true;
            }
        }
        if (! $allowed) {
            return 'هذا الحساب لا يناسب هذا النوع (المجموعة أو طبيعة الرصيد غير صحيحة).';
        }
        if (DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('parent_account_id', $account->id)->whereNull('deleted_at')->exists()) {
            return 'اختر حسابًا فرعيًا (نهائيًا) وليس حسابًا رئيسيًا.';
        }
        if ($key !== 'cash.drawer' && DB::table('financial_locations')->where('tenant_id', $tenantId)->where('financial_account_id', $account->id)->exists()) {
            return 'لا يمكن ربط هذا النوع بحساب صندوق أو خزنة.';
        }

        return null;
    }

    /** Is the account currently serving $key usable (exists, right kind, final)? */
    private function isUsable(int $tenantId, string $key): bool
    {
        $account = $this->map->account($tenantId, $key);
        if (! $account) {
            return false;
        }
        $row = DB::table('financial_accounts')->where('id', $account->id)->first(['id', 'account_group', 'normal_balance']);

        return $row !== null && $this->problem($tenantId, $key, $row) === null;
    }

    /**
     * Gives every posting kind its default account from the imported chart. Missing accounts of the new chart are
     * created, then each mapping that is empty or unusable (e.g. points at a header account) is set to its default.
     * With overwrite=true every mapping is reset. Nothing is posted; history is untouched.
     */
    public function applyDefaults(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $overwrite = $request->boolean('overwrite');
        $remap = app(\App\Services\PhinixRemapService::class);
        if ($remap->isPhinixTenant($tenantId)) {
            $remap->remapConfiguration($tenantId, true);
        }
        $set = [];
        foreach (self::META as $key => $meta) {
            $code = \App\Services\PhinixRemapService::MAPPINGS[$key] ?? null;
            if ($code === null || (! $overwrite && $this->isUsable($tenantId, $key))) {
                continue;
            }
            $target = DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', $code)
                ->where('is_active', true)->whereNull('deleted_at')->first(['id', 'code', 'account_group', 'normal_balance']);
            if (! $target || $this->problem($tenantId, $key, $target) !== null) {
                continue;
            }
            DB::table('sales_account_mappings')->updateOrInsert(
                ['tenant_id' => $tenantId, 'mapping_key' => $key],
                ['financial_account_id' => $target->id, 'updated_at' => now(), 'created_at' => now()],
            );
            $set[] = $key;
        }
        if ($set !== []) {
            $this->audit->record($request, $tenantId, 'finance.account_mapping.defaults_applied', 'account_mapping', 0,
                [], ['keys' => $set, 'overwrite' => $overwrite], null, FinancialActor::id($request, $tenantId));
        }

        return response()->json(['data' => ['applied' => $set, 'count' => count($set)]]);
    }
}
