<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;

/**
 * One place that knows every entity that can sit in the trash. Everything is a soft delete (deleted_at),
 * so listing and restoring are generic. Vouchers delegate to their own service because restoring one has rules.
 */
final class TrashRegistry
{
    /** type => [table, Arabic label]. Order is the order shown in the filter. */
    public const TYPES = [
        'vouchers' => ['finance_documents', 'سندات'],
        'expenses' => ['expenses', 'مصاريف'],
        'purchase_invoices' => ['supplier_invoices', 'فواتير مشتريات'],
        'customers' => ['customers', 'عملاء'],
        'customer_groups' => ['customer_groups', 'مجموعات العملاء'],
        'suppliers' => ['suppliers', 'موردون'],
        'products' => ['products', 'منتجات'],
        'product_variants' => ['product_variants', 'أحجام المنتجات'],
        'categories' => ['categories', 'تصنيفات'],
        'modifier_groups' => ['modifier_groups', 'مجموعات الإضافات'],
        'modifier_options' => ['modifier_options', 'خيارات الإضافات'],
        'menus' => ['menus', 'قوائم'],
        'inventory_items' => ['inventory_items', 'مواد مخزون'],
        'warehouses' => ['warehouses', 'مستودعات'],
        'discounts' => ['discounts', 'خصومات'],
        'expense_categories' => ['expense_categories', 'تصنيفات المصاريف'],
        'financial_accounts' => ['financial_accounts', 'حسابات'],
    ];

    public function __construct(private readonly FinanceDocumentService $documents, private readonly OperationalAuditService $audit) {}

    /** @return array<int, array{type:string,label:string,count:int}> */
    public function types(int $tenantId): array
    {
        $counts = $this->counts($tenantId);

        return array_map(fn (string $type): array => ['type' => $type, 'label' => self::TYPES[$type][1], 'count' => $counts[$type] ?? 0], array_keys(self::TYPES));
    }

    /** Number of trashed rows per type for this tenant (only types that have any), so the screen can show counts. */
    public function counts(int $tenantId): array
    {
        $counts = [];
        foreach (self::TYPES as $key => [$table]) {
            if (! Schema::hasTable($table) || ! Schema::hasColumn($table, 'deleted_at')) {
                continue;
            }
            $query = DB::table($table)->whereNotNull('deleted_at');
            if (Schema::hasColumn($table, 'tenant_id')) {
                $query->where('tenant_id', $tenantId);
            }
            $counts[$key] = (int) $query->count();
        }

        return $counts;
    }

    /** Title shown for a trashed row: the first non-empty of the usual name-like columns. */
    private function titleColumns(string $table): array
    {
        return array_values(array_filter(
            ['name_ar', 'name', 'document_number', 'internal_reference', 'code', 'description'],
            fn (string $column): bool => Schema::hasColumn($table, $column),
        ));
    }

    public function list(int $tenantId, ?string $type, ?string $search, int $page, int $perPage): array
    {
        $types = $type !== null && $type !== '' ? [$this->assertType($type)] : array_keys(self::TYPES);
        $items = [];
        $total = 0;
        foreach ($types as $key) {
            [$table, $label] = self::TYPES[$key];
            if (! Schema::hasTable($table) || ! Schema::hasColumn($table, 'deleted_at')) {
                continue;
            }
            $titles = $this->titleColumns($table);
            $query = DB::table($table)->whereNotNull('deleted_at');
            if (Schema::hasColumn($table, 'tenant_id')) {
                $query->where('tenant_id', $tenantId);
            }
            $rows = $query->orderByDesc('deleted_at')->limit(500)->get();
            foreach ($rows as $row) {
                $title = '';
                foreach ($titles as $column) {
                    if (trim((string) ($row->{$column} ?? '')) !== '') {
                        $title = trim((string) $row->{$column});
                        break;
                    }
                }
                $code = $row->document_number ?? $row->internal_reference ?? $row->code ?? null;
                $title = $title !== '' ? $title : "#{$row->id}";
                if ($search !== null && $search !== '' && mb_stripos($title.' '.($code ?? ''), $search) === false) {
                    continue;
                }
                $items[] = [
                    'type' => $key, 'typeLabel' => $label, 'id' => (int) $row->id, 'title' => $title,
                    'code' => $code !== null ? (string) $code : null,
                    'deletedAt' => $row->deleted_at,
                    'deletedBy' => isset($row->deleted_by) && $row->deleted_by ? (int) $row->deleted_by : null,
                ];
            }
        }
        usort($items, fn (array $a, array $b): int => strcmp((string) $b['deletedAt'], (string) $a['deletedAt']));
        $total = count($items);

        return ['data' => array_slice($items, ($page - 1) * $perPage, $perPage), 'total' => $total, 'page' => $page, 'perPage' => $perPage];
    }

    public function restore(Request $request, int $tenantId, string $type, int $id, int $actorId): void
    {
        $this->assertType($type);
        if ($type === 'vouchers') {
            $this->documents->restore($request, $tenantId, $id, $actorId);

            return;
        }
        [$table] = self::TYPES[$type];
        // Catalog entities are archived by "inactive + deleted"; their own restore undoes both (and re-syncs what depends on them).
        if ($this->restoreWithDomainRules($request, $tenantId, $type, $id)) {
            return;
        }
        $query = DB::table($table)->where('id', $id)->whereNotNull('deleted_at');
        if (Schema::hasColumn($table, 'tenant_id')) {
            $query->where('tenant_id', $tenantId);
        }
        $row = $query->first();
        abort_unless($row, 404, 'العنصر غير موجود في سلة المحذوفات.');
        try {
            DB::transaction(function () use ($table, $id, $tenantId, $type, $request, $actorId): void {
                $patch = ['deleted_at' => null, 'updated_at' => now()];
                // Archiving also switched the row off; bringing it back means it is usable again, not hidden as "inactive".
                if (Schema::hasColumn($table, 'is_active')) {
                    $patch['is_active'] = true;
                }
                DB::table($table)->where('id', $id)->update($patch);
                $this->audit->record($request, $tenantId, "{$type}.restored", $table, $id, [], [], null, $actorId);
            });
        } catch (\Illuminate\Database\QueryException) {
            // Typically a unique code/name that was reused after the delete.
            throw ValidationException::withMessages(['id' => 'تعذّرت الاستعادة: يوجد عنصر آخر بنفس الرمز أو الاسم. غيّر الرمز أولاً.']);
        }
    }

    private function restoreWithDomainRules(Request $request, int $tenantId, string $type, int $id): bool
    {
        $trashed = fn (string $model) => $model::withTrashed()->where('tenant_id', $tenantId)->whereKey($id)->whereNotNull('deleted_at')->first()
            ?? abort(404, 'العنصر غير موجود في سلة المحذوفات.');
        try {
            switch ($type) {
                case 'products':
                    app(\App\Services\Catalog\CatalogProductService::class)->restore($trashed(\App\Models\Product::class));
                    break;
                case 'product_variants':
                    $variant = $trashed(\App\Models\ProductVariant::class);
                    $hasDefault = \App\Models\ProductVariant::query()->where('product_id', $variant->product_id)->where('is_active', true)->where('is_default', true)->exists();
                    app(\App\Services\Catalog\ProductVariantService::class)->restore($variant, ! $hasDefault);
                    break;
                case 'modifier_groups':
                    app(\App\Services\Catalog\ModifierGroupService::class)->restore($trashed(\App\Models\ModifierGroup::class));
                    break;
                case 'modifier_options':
                    app(\App\Services\Catalog\ModifierGroupService::class)->restoreOption($trashed(\App\Models\ModifierOption::class));
                    break;
                case 'menus':
                    app(\App\Services\Menu\MenuCompositionService::class)->restoreMenu($trashed(\App\Models\Menu::class));
                    break;
                case 'customers':
                    app(\App\Services\Customer\CustomerService::class)->restore($request, $id);
                    break;
                case 'customer_groups':
                    app(\App\Services\Customer\CustomerGroupService::class)->restore($request, $id);
                    break;
                default:
                    return false;
            }
        } catch (\Illuminate\Database\QueryException) {
            throw ValidationException::withMessages(['id' => 'تعذّرت الاستعادة: يوجد عنصر آخر بنفس الرمز أو الاسم. غيّر الرمز أولاً.']);
        }

        return true;
    }

    private function assertType(string $type): string
    {
        if (! array_key_exists($type, self::TYPES)) {
            throw ValidationException::withMessages(['type' => 'نوع غير معروف.']);
        }

        return $type;
    }
}
