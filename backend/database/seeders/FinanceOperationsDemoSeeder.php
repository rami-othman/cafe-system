<?php

namespace Database\Seeders;

use App\Domain\Inventory\InventoryPostingService;
use App\Domain\Inventory\WarehouseTransferService;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\PosOrderController;
use App\Http\Controllers\Api\RefundController;
use App\Services\CashTransferService;
use App\Services\AccountingPeriodService;
use App\Services\DailyClosingService;
use App\Services\ExpenseService;
use App\Services\FinancialReconciliationQueryService;
use App\Services\FinancialReconciliationService;
use App\Services\FinancialSetupService;
use App\Services\DefaultTenantRoleService;
use App\Services\SupplierInvoiceService;
use App\Services\SupplierPaymentService;
use App\Services\SupplierService;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Explicit development-only connected demo data.  Configuration records are
 * upserted by stable business keys; financial effects are always created by
 * the same services/controllers used by the application.
 */
final class FinanceOperationsDemoSeeder extends Seeder
{
    private const SLUG = 'cafe-618-finance-demo';

    /**
     * The POS sale/refund below always post their journal entries dated
     * "today" (PaymentController/RefundController stamp entryDate from
     * now()), so the cash-drawer close date must track today too — a fixed
     * historical date would silently drop out of the reconciliation window
     * once the wall clock passes it, breaking the hardcoded 95.60 actual
     * cash count with a false NON_ZERO_DIFFERENCE.
     */
    private function closeDate(): string { return now()->toDateString(); }

    public function run(): void
    {
        if (! app()->environment(['local', 'development', 'testing'])) {
            throw new RuntimeException('FinanceOperationsDemoSeeder is restricted to local, development, and testing environments.');
        }

        [$tenant, $owner, $branchA, $branchB] = $this->foundation();
        $request = $this->request($tenant, $owner);
        app(FinancialSetupService::class)->ensureForTenant($tenant, $branchA, $owner);
        app(FinancialSetupService::class)->ensureBranchMainWarehouse($tenant, $branchB, $owner);
        $this->bankPaymentMethod($tenant, $owner);

        [$central, $branchWarehouse] = $this->warehouses($tenant, $branchA);
        $beans = $this->item($tenant, $owner, 'DEMO-BEANS', 'Arabica Coffee Beans', 'kg');
        $milk = $this->item($tenant, $owner, 'DEMO-MILK', 'Fresh Milk', 'liter');
        $this->assignItem($tenant, $beans, $central); $this->assignItem($tenant, $beans, $branchWarehouse);
        $this->assignItem($tenant, $milk, $branchWarehouse);
        $this->inventory($request, $tenant, $owner, $central, $branchWarehouse, $beans, $milk, $branchA);

        [$product, $variant, $placement, $version] = $this->coffeeProduct($tenant, $owner, $branchA, $branchWarehouse, $beans, $milk);
        $this->saleAndRefund($tenant, $owner, $branchA, $product, $variant, $placement, $version);
        $this->expenses($request, $tenant, $owner, $branchA);
        $this->accountsPayable($request, $tenant, $owner, $branchA);
        $this->cashTransfer($request, $tenant, $owner, $branchA);
        $this->reconcileAndClose($request, $tenant, $owner, $branchA);
        $this->closePeriod($request, $tenant, $owner);
    }

    private function foundation(): array
    {
        $now = now();
        DB::table('tenants')->updateOrInsert(['slug' => self::SLUG], [
            'name' => 'Cafe 618 Finance Operations Demo', 'status' => 'active', 'plan' => 'development-demo',
            'email' => 'finance-demo@cafe618.local', 'timezone' => 'Asia/Damascus', 'currency' => 'SYP', 'updated_at' => $now, 'created_at' => $now,
        ]);
        $tenant = (int) DB::table('tenants')->where('slug', self::SLUG)->value('id');
        $roles = app(DefaultTenantRoleService::class)->ensureForTenant($tenant);
        $ownerRoleId = (int) $roles[DefaultTenantRoleService::OWNER]->id;
        $email = 'finance-demo-owner@cafe618.local';
        $owner = DB::table('users')->where('email', $email)->value('id');
        if (! $owner) {
            $owner = DB::table('users')->insertGetId(['tenant_id' => $tenant, 'tenant_role_id' => $ownerRoleId, 'name' => 'Finance Demo Owner', 'email' => $email, 'password' => bcrypt('development-only'), 'role' => 'owner', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        } else {
            DB::table('users')->where('id', $owner)->update(['tenant_id' => $tenant, 'tenant_role_id' => $ownerRoleId, 'role' => 'owner', 'is_active' => true, 'updated_at' => $now]);
        }
        $branchA = $this->branch($tenant, 'Demo Downtown', 'Downtown demonstration branch');
        $branchB = $this->branch($tenant, 'Demo Riverside', 'Riverside demonstration branch');
        foreach ([$branchA, $branchB] as $branchId) {
            DB::table('user_branches')->updateOrInsert(
                ['tenant_id' => $tenant, 'user_id' => $owner, 'branch_id' => $branchId],
                ['created_at' => $now, 'updated_at' => $now],
            );
        }

        return [$tenant, (int) $owner, $branchA, $branchB];
    }

    private function branch(int $tenant, string $name, string $address): int
    {
        $id = DB::table('branches')->where('tenant_id', $tenant)->where('name', $name)->whereNull('deleted_at')->value('id');
        if ($id) return (int) $id;
        return (int) DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => $name, 'address' => $address, 'timezone' => 'Asia/Damascus', 'currency' => 'SYP', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function request(int $tenant, int $owner): Request
    {
        $request = Request::create('/seed/finance-operations-demo', 'POST');
        $request->attributes->set('tenant_id', $tenant);
        $request->attributes->set('auth_user', $this->authUser($tenant, $owner));
        return $request;
    }

    private function authUser(int $tenant, int $userId): User
    {
        return User::query()
            ->where('tenant_id', $tenant)
            ->findOrFail($userId);
    }

    private function bankPaymentMethod(int $tenant, int $owner): void
    {
        $account = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1030')->value('id');
        $location = DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'BANK')->value('id');
        DB::table('payment_methods')->updateOrInsert(['tenant_id' => $tenant, 'code' => 'BANK'], ['name' => 'Bank Transfer', 'type' => 'bank', 'financial_account_id' => $account, 'financial_location_id' => $location, 'is_active' => true, 'sort_order' => 2, 'created_by' => $owner, 'updated_by' => $owner, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function warehouses(int $tenant, int $branch): array
    {
        $central = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', 'CENTRAL')->value('id');
        $branchMain = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', 'BR-'.$branch.'-MAIN')->value('id');
        if (! $central || ! $branchMain) throw new RuntimeException('Finance demo warehouses were not configured.');
        return [$central, $branchMain];
    }

    private function item(int $tenant, int $owner, string $sku, string $name, string $unit): int
    {
        DB::table('inventory_items')->updateOrInsert(['tenant_id' => $tenant, 'sku' => $sku], ['name' => $name, 'name_ar' => $name, 'name_en' => $name, 'catalog_identity' => strtolower($sku), 'item_type' => 'raw_material', 'category' => 'Demo cafe ingredients', 'unit' => $unit, 'minimum_stock' => '1.000', 'reorder_level' => '1.000', 'cost_per_unit' => '0.0000', 'latest_unit_cost' => '0.0000', 'is_active' => true, 'created_by' => $owner, 'updated_by' => $owner, 'created_at' => now(), 'updated_at' => now()]);
        return (int) DB::table('inventory_items')->where('tenant_id', $tenant)->where('sku', $sku)->value('id');
    }

    private function assignItem(int $tenant, int $item, int $warehouse): void
    {
        DB::table('inventory_item_warehouses')->updateOrInsert(['tenant_id' => $tenant, 'inventory_item_id' => $item, 'warehouse_id' => $warehouse], ['created_at' => now(), 'updated_at' => now()]);
    }

    private function inventory(Request $request, int $tenant, int $owner, int $central, int $branchWarehouse, int $beans, int $milk, int $branch): void
    {
        $posting = app(InventoryPostingService::class);
        $post = fn (array $data) => $posting->post($request, $tenant, $data, $owner);
        $post(['warehouseId' => $central, 'itemId' => $beans, 'type' => 'opening_balance', 'quantity' => '10.000', 'unit' => 'kg', 'unitCost' => '12.0000', 'occurredAt' => '2026-07-01 08:00:00', 'idempotencyKey' => 'finance-demo-beans-opening']);
        $post(['warehouseId' => $central, 'itemId' => $beans, 'type' => 'stock_in', 'quantity' => '5.000', 'unit' => 'kg', 'unitCost' => '18.0000', 'occurredAt' => '2026-07-08 08:00:00', 'idempotencyKey' => 'finance-demo-beans-second-batch']);
        $post(['warehouseId' => $branchWarehouse, 'branchId' => $branch, 'itemId' => $milk, 'type' => 'opening_balance', 'quantity' => '30.000', 'unit' => 'liter', 'unitCost' => '2.0000', 'occurredAt' => '2026-07-01 08:00:00', 'idempotencyKey' => 'finance-demo-milk-opening']);
        // The transfer workflow creates its paired outbound/inbound movements;
        // neither is a Finance event because this is internal relocation.
        $transfer = app(WarehouseTransferService::class);
        $transferId = $transfer->create($request, $tenant, ['sourceWarehouseId' => $central, 'destinationWarehouseId' => $branchWarehouse, 'lines' => [['itemId' => $beans, 'requestedQuantity' => '4.000', 'unit' => 'kg']], 'notes' => 'Demo internal bean transfer', 'idempotencyKey' => 'finance-demo-beans-transfer'], $owner);
        $transfer->action($request, $tenant, $transferId, 'submit', ['idempotencyKey' => 'finance-demo-beans-transfer-submit'], $owner);
        $transfer->action($request, $tenant, $transferId, 'approve', ['idempotencyKey' => 'finance-demo-beans-transfer-approve'], $owner);
        $transfer->action($request, $tenant, $transferId, 'dispatch', ['idempotencyKey' => 'finance-demo-beans-transfer-dispatch'], $owner);
        $transfer->receive($request, $tenant, $transferId, ['idempotencyKey' => 'finance-demo-beans-transfer-receive', 'lines' => [['itemId' => $beans, 'receivedQuantity' => '4.000', 'unit' => 'kg']]], $owner);
        $post(['warehouseId' => $branchWarehouse, 'branchId' => $branch, 'itemId' => $milk, 'type' => 'waste', 'quantity' => '1.000', 'unit' => 'liter', 'reason' => 'Expired milk', 'occurredAt' => '2026-07-16 17:00:00', 'idempotencyKey' => 'finance-demo-milk-waste']);
        $post(['warehouseId' => $branchWarehouse, 'branchId' => $branch, 'itemId' => $beans, 'type' => 'stock_count_variance', 'countDirection' => 'out', 'quantity' => '0.200', 'unit' => 'kg', 'reason' => 'Count shortage', 'occurredAt' => '2026-07-20 20:00:00', 'idempotencyKey' => 'finance-demo-beans-count-shortage']);
    }

    private function coffeeProduct(int $tenant, int $owner, int $branch, int $warehouse, int $beans, int $milk): array
    {
        DB::table('products')->updateOrInsert(['tenant_id' => $tenant, 'sku' => 'DEMO-LATTE'], ['name' => 'Demo Latte', 'description' => 'Finance operations demo drink', 'price' => '35.00', 'cost_price' => '0.00', 'is_active' => true, 'is_stock_tracked' => true, 'inventory_controlled' => true, 'consumption_type' => 'bar', 'created_at' => now(), 'updated_at' => now()]);
        $product = (int) DB::table('products')->where('tenant_id', $tenant)->where('sku', 'DEMO-LATTE')->value('id');
        DB::table('product_inventory_settings')->updateOrInsert(['tenant_id' => $tenant, 'product_id' => $product, 'branch_id' => $branch], ['warehouse_id' => $warehouse, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('recipes')->updateOrInsert(['tenant_id' => $tenant, 'product_id' => $product, 'version' => 1], ['name' => 'Demo Latte recipe', 'is_active' => true, 'yield_quantity' => '1.000', 'yield_unit' => 'piece', 'created_by' => $owner, 'created_at' => now(), 'updated_at' => now()]);
        $recipe = (int) DB::table('recipes')->where('tenant_id' , $tenant)->where('product_id', $product)->where('version', 1)->value('id');
        foreach ([[$beans, '0.020'], [$milk, '0.200']] as $number => [$item, $quantity]) {
            DB::table('recipe_lines')->updateOrInsert(['recipe_id' => $recipe, 'inventory_item_id' => $item], ['tenant_id' => $tenant, 'quantity' => $quantity, 'wastage_percentage' => '0.000', 'line_number' => $number + 1, 'created_at' => now(), 'updated_at' => now()]);
        }
        DB::table('product_variants')->updateOrInsert(['tenant_id' => $tenant, 'product_id' => $product, 'is_default' => true], ['name' => 'Regular', 'sku' => 'DEMO-LATTE-REGULAR', 'base_price' => '35.00', 'cost_price' => '0.00', 'is_active' => true, 'sort_order' => 0, 'created_at' => now(), 'updated_at' => now()]);
        $variant = (int) DB::table('product_variants')->where('tenant_id', $tenant)->where('product_id', $product)->where('is_default', true)->value('id');
        $menu = DB::table('menus')->where('tenant_id', $tenant)->where('name', 'Finance Demo POS')->value('id');
        if (! $menu) $menu = DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => 'Finance Demo POS', 'status' => 'draft', 'priority' => 0, 'created_at' => now(), 'updated_at' => now()]);
        $section = DB::table('menu_sections')->where('menu_id', $menu)->where('name', 'Coffee')->value('id');
        if (! $section) $section = DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menu, 'name' => 'Coffee', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $placement = DB::table('menu_item_placements')->where('tenant_id', $tenant)->where('menu_section_id', $section)->where('product_id', $product)->value('id');
        if (! $placement) $placement = DB::table('menu_item_placements')->insertGetId(['tenant_id' => $tenant, 'menu_section_id' => $section, 'product_id' => $product, 'is_visible' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('menu_assignments')->updateOrInsert(['tenant_id' => $tenant, 'menu_id' => $menu, 'branch_id' => $branch, 'channel' => 'pos'], ['is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $version = DB::table('published_menu_versions')->where('tenant_id', $tenant)->where('branch_id', $branch)->where('channel', 'pos')->where('status', 'current')->value('id');
        if (! $version) {
            $publication = DB::table('menu_publications')->insertGetId(['tenant_id' => $tenant, 'status' => 'published', 'published_by' => $owner, 'published_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
            $payload = [
                'context' => ['tenantId' => $tenant, 'branchId' => $branch, 'schemaVersion' => 3],
                'menus' => [[
                    'id' => (int) $menu, 'scopeOrder' => 0, 'name' => ['default' => 'Finance Demo POS'],
                    'description' => null, 'availabilityRules' => [],
                    'sections' => [[
                        'id' => (int) $section, 'name' => ['default' => 'Coffee'], 'description' => null, 'sortOrder' => 0,
                        'products' => [[
                            'placementId' => (int) $placement, 'productId' => $product,
                            'categoryId' => (int) DB::table('products')->where('id', $product)->value('category_id'),
                            'name' => ['default' => 'Demo Latte'], 'description' => null, 'imageUrl' => null,
                            'sortOrder' => 0, 'isFeatured' => false, 'isVisible' => true, 'productAvailabilityRules' => [],
                            'variants' => [[
                                'id' => $variant, 'name' => ['default' => 'Regular'], 'sku' => 'DEMO-LATTE-REGULAR',
                                'barcode' => null, 'sortOrder' => 0, 'isDefault' => true,
                                'basePrice' => '35.00', 'effectivePrice' => '35.00',
                                'baseRecipe' => [
                                    ['materialId' => $beans, 'quantity' => '0.020', 'unitCode' => 'kg'],
                                    ['materialId' => $milk, 'quantity' => '0.200', 'unitCode' => 'liter'],
                                ],
                                'modifierRecipeAdjustments' => [],
                            ]],
                            'modifierGroups' => [],
                        ]],
                    ]],
                ]],
            ];
            $version = DB::table('published_menu_versions')->insertGetId(['tenant_id' => $tenant, 'menu_publication_id' => $publication, 'branch_id' => $branch, 'channel' => 'pos', 'version_number' => 1, 'payload_json' => json_encode($payload, JSON_THROW_ON_ERROR), 'checksum' => hash('sha256', json_encode($payload, JSON_THROW_ON_ERROR)), 'status' => 'current', 'published_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        }

        return [$product, $variant, (int) $placement, (int) $version];
    }

    private function saleAndRefund(int $tenant, int $owner, int $branch, int $product, int $variant, int $placement, int $version): void
    {
        if (DB::table('orders')->where('tenant_id', $tenant)->where('branch_id', $branch)->where('notes', 'Finance demo latte sale')->exists()) {
            return;
        }

        $authUser = $this->authUser($tenant, $owner);
        $shiftId = $this->ensureSaleShift($tenant, $owner, $branch);
        $orderRequest = Request::create('/api/v1/pos/orders', 'POST', ['branchId' => $branch, 'shiftId' => $shiftId, 'orderType' => 'takeaway', 'publishedMenuVersionId' => $version, 'items' => [['productId' => $product, 'placementId' => $placement, 'variantId' => $variant, 'quantity' => 2]], 'note' => 'Finance demo latte sale', 'idempotencyKey' => 'finance-demo-latte-sale']);
        $orderRequest->attributes->set('tenant_id', $tenant); $orderRequest->attributes->set('auth_user', $authUser);
        $orderId = (int) app(PosOrderController::class)->store($orderRequest)->getData(true)['data']['id'];
        $paymentRequest = Request::create('/api/v1/pos/orders/'.$orderId.'/payment', 'POST', ['method' => 'cash', 'paymentMethodId' => DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id'), 'amount' => '75.60', 'idempotencyKey' => 'finance-demo-latte-payment']);
        $paymentRequest->attributes->set('tenant_id', $tenant); $paymentRequest->attributes->set('auth_user', $authUser);
        app(PaymentController::class)->pay($paymentRequest, $orderId);
        $refundRequest = Request::create('/api/v1/pos/orders/'.$orderId.'/refund', 'POST', ['type' => 'partial', 'amount' => '10.00', 'reason' => 'Demo customer adjustment', 'idempotencyKey' => 'finance-demo-latte-refund']);
        $refundRequest->attributes->set('tenant_id', $tenant); $refundRequest->attributes->set('auth_user', $authUser);
        app(RefundController::class)->store($refundRequest, $orderId);
    }

    private function ensureSaleShift(int $tenant, int $owner, int $branch): int
    {
        $existing = DB::table('shifts')
            ->where('tenant_id', $tenant)
            ->where('branch_id', $branch)
            ->where('notes', 'Finance demo close shift')
            ->value('id');
        if ($existing) {
            return (int) $existing;
        }

        $now = now();
        return (int) DB::table('shifts')->insertGetId([
            'tenant_id' => $tenant, 'branch_id' => $branch, 'user_id' => $owner,
            'opening_cash' => '30.00', 'status' => 'open', 'opened_at' => $this->closeDate().' 08:00:00',
            'notes' => 'Finance demo close shift', 'created_at' => $now, 'updated_at' => $now,
        ]);
    }

    private function expenses(Request $request, int $tenant, int $owner, int $branch): void
    {
        $account = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '6120')->value('id');
        DB::table('expense_categories')->updateOrInsert(['tenant_id' => $tenant, 'code' => 'DEMO-UTILITIES'], ['name' => 'Demo Utilities', 'financial_account_id' => $account, 'is_active' => true, 'sort_order' => 1, 'created_by' => $owner, 'updated_by' => $owner, 'created_at' => now(), 'updated_at' => now()]);
        $category = (int) DB::table('expense_categories')->where('tenant_id', $tenant)->where('code', 'DEMO-UTILITIES')->value('id');
        $this->postExpense($request, $tenant, $owner, $branch, $category, '45.00', '2026-07-18', 'July electricity', 'finance-demo-expense-electricity');

        // A realistic monthly run gives every Finance list enough connected
        // records to exercise its 10-row pagination in development.
        for ($day = 1; $day <= 12; $day++) {
            $date = '2026-08-'.str_pad((string) $day, 2, '0', STR_PAD_LEFT);
            $this->postExpense(
                $request,
                $tenant,
                $owner,
                $branch,
                $category,
                number_format(12 + $day, 2, '.', ''),
                $date,
                'August operating expense #'.$day,
                'finance-demo-expense-august-'.$day,
                false,
            );
        }
    }

    private function postExpense(Request $request, int $tenant, int $owner, int $branch, int $category, string $amount, string $date, string $description, string $idempotencyKey, bool $pay = true): void
    {
        $service = app(ExpenseService::class);
        $expense = $service->create($request, $tenant, ['branchId' => $branch, 'expenseCategoryId' => $category, 'amount' => $amount, 'expenseDate' => $date, 'description' => $description, 'idempotencyKey' => $idempotencyKey], $owner);
        if ($expense->status === 'draft') $expense = $service->transition($request, $tenant, $expense->id, 'submit', [], $owner);
        if ($expense->status === 'pending_approval') $expense = $service->transition($request, $tenant, $expense->id, 'approve', [], $owner);
        if ($pay && $expense->status === 'approved') $service->pay($request, $tenant, $expense->id, ['paymentMethodId' => DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'CASH')->value('id'), 'financialLocationId' => DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id'), 'paymentDate' => $date, 'idempotencyKey' => $idempotencyKey.'-pay'], $owner);
    }

    private function accountsPayable(Request $request, int $tenant, int $owner, int $branch): void
    {
        $supplierA = $this->supplier($request, $tenant, $owner, 'Demo Bean Roasters', 'beans-demo@supplier.local');
        $supplierB = $this->supplier($request, $tenant, $owner, 'Demo Dairy & Bakery', 'dairy-demo@supplier.local');
        $bankMethod = (int) DB::table('payment_methods')->where('tenant_id', $tenant)->where('code', 'BANK')->value('id');
        $bankLocation = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'BANK')->value('id');

        // Supplier A: one partially-paid invoice and one outstanding invoice.
        $partial = $this->postedInvoice($request, $tenant, $owner, ['branchId' => $branch, 'supplierId' => $supplierA, 'invoiceNumber' => 'DEMO-BEAN-2026-07', 'invoiceDate' => '2026-07-05', 'dueDate' => '2026-08-04', 'invoiceType' => 'inventory', 'subtotal' => '180.00', 'idempotencyKey' => 'finance-demo-ap-invoice']);
        $this->payment($request, $tenant, $owner, $branch, $supplierA, $partial->id, '90.00', '2026-07-25', $bankMethod, $bankLocation, 'finance-demo-ap-payment');
        $this->postedInvoice($request, $tenant, $owner, ['branchId' => $branch, 'supplierId' => $supplierA, 'invoiceNumber' => 'DEMO-BEAN-UNPAID-2026-08', 'invoiceDate' => '2026-08-12', 'dueDate' => '2026-09-11', 'invoiceType' => 'inventory', 'subtotal' => '125.00', 'idempotencyKey' => 'finance-demo-ap-unpaid']);

        // Supplier B: one paid-in-full invoice and one deliberately overdue outstanding invoice.
        $paid = $this->postedInvoice($request, $tenant, $owner, ['branchId' => $branch, 'supplierId' => $supplierB, 'invoiceNumber' => 'DEMO-DAIRY-PAID-2026-07', 'invoiceDate' => '2026-07-09', 'dueDate' => '2026-07-24', 'invoiceType' => 'inventory', 'subtotal' => '60.00', 'idempotencyKey' => 'finance-demo-ap-full']);
        $this->payment($request, $tenant, $owner, $branch, $supplierB, $paid->id, '60.00', '2026-07-22', $bankMethod, $bankLocation, 'finance-demo-ap-full-payment');
        $this->postedInvoice($request, $tenant, $owner, ['branchId' => $branch, 'supplierId' => $supplierB, 'invoiceNumber' => 'DEMO-DAIRY-OVERDUE-2026-07', 'invoiceDate' => '2026-07-02', 'dueDate' => '2026-07-12', 'invoiceType' => 'inventory', 'subtotal' => '75.00', 'idempotencyKey' => 'finance-demo-ap-overdue']);
    }

    private function cashTransfer(Request $request, int $tenant, int $owner, int $branch): void
    {
        app(CashTransferService::class)->create($request, $tenant, ['branchId' => $branch, 'fromFinancialLocationId' => DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id'), 'toFinancialLocationId' => DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'BANK')->value('id'), 'amount' => '25.00', 'transferDate' => '2026-07-26', 'description' => 'Demo cash banking transfer', 'idempotencyKey' => 'finance-demo-cash-bank-transfer'], $owner);
        app(CashTransferService::class)->create($request, $tenant, ['branchId' => $branch, 'fromFinancialLocationId' => DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'BANK')->value('id'), 'toFinancialLocationId' => DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id'), 'amount' => '100.00', 'transferDate' => '2026-08-31', 'description' => 'Demo branch opening cash transfer', 'idempotencyKey' => 'finance-demo-bank-cash-opening'], $owner);
    }

    private function supplier(Request $request, int $tenant, int $owner, string $name, string $email): int
    {
        $id = DB::table('suppliers')->where('tenant_id', $tenant)->where('email', $email)->value('id');
        return $id ? (int) $id : app(SupplierService::class)->create($request, $tenant, ['name' => $name, 'email' => $email, 'paymentTermsDays' => 30], $owner);
    }

    private function postedInvoice(Request $request, int $tenant, int $owner, array $data): object
    {
        $service = app(SupplierInvoiceService::class);
        $invoice = $service->create($request, $tenant, $data, $owner);
        if ($invoice->status === 'draft') $invoice = $service->post($request, $tenant, $invoice->id, ['idempotencyKey' => $data['idempotencyKey'].'-post'], $owner);
        return $invoice;
    }

    private function payment(Request $request, int $tenant, int $owner, int $branch, int $supplier, int $invoice, string $amount, string $date, int $method, int $location, string $key): void
    {
        $status = DB::table('supplier_invoices')->where('tenant_id', $tenant)->where('id', $invoice)->value('status');
        if (in_array($status, ['posted', 'partially_paid'], true)) app(SupplierPaymentService::class)->pay($request, $tenant, ['branchId' => $branch, 'supplierId' => $supplier, 'paymentMethodId' => $method, 'financialLocationId' => $location, 'paymentDate' => $date, 'amount' => $amount, 'allocations' => [['invoiceId' => $invoice, 'amount' => $amount]], 'idempotencyKey' => $key], $owner);
    }

    private function reconcileAndClose(Request $request, int $tenant, int $owner, int $branch): void
    {
        // Financial locations are one-to-one with their ledger account in
        // the current schema, so use the canonical Cash Drawer location.
        $location = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        $shift = DB::table('shifts')->where('tenant_id', $tenant)->where('branch_id', $branch)->where('notes', 'Finance demo close shift')->first();
        if (! $shift) {
            DB::table('shifts')->insert(['tenant_id' => $tenant, 'branch_id' => $branch, 'user_id' => $owner, 'opening_cash' => '30.00', 'closing_cash' => '95.60', 'expected_cash' => '95.60', 'cash_difference' => '0.00', 'status' => 'closed', 'opened_at' => $this->closeDate().' 08:00:00', 'closed_at' => $this->closeDate().' 22:00:00', 'notes' => 'Finance demo close shift', 'created_at' => now(), 'updated_at' => now()]);
        } elseif ($shift->status === 'open') {
            DB::table('shifts')->where('id', $shift->id)->update(['closing_cash' => '95.60', 'expected_cash' => '95.60', 'cash_difference' => '0.00', 'status' => 'closed', 'closed_at' => $this->closeDate().' 22:00:00', 'updated_at' => now()]);
        }

        $reconciliations = app(FinancialReconciliationService::class);
        $session = $reconciliations->create($request, $tenant, ['type' => 'cash', 'financialLocationId' => $location, 'dateFrom' => $this->closeDate(), 'dateTo' => $this->closeDate(), 'actualCashCount' => '95.60', 'notes' => 'Demo cash reconciliation', 'idempotencyKey' => 'finance-demo-cash-reconciliation'], $owner);
        if ($session->status !== 'completed') $reconciliations->complete($request, $tenant, $session->id, $owner, app(FinancialReconciliationQueryService::class));

        $closings = app(DailyClosingService::class);
        $closing = $closings->getOrCreate($request, $tenant, $branch, $this->closeDate(), $owner);
        if ($closing->status !== 'closed') {
            $preview = $closings->preview($request, $tenant, $branch, $this->closeDate(), $owner);
            $closings->close($request, $tenant, $closing->id, ['actualCash' => $preview['cash']['expectedCash'], 'notes' => 'Finance demo completed close'], $owner);
        }
    }

    private function closePeriod(Request $request, int $tenant, int $owner): void
    {
        $period = DB::table('accounting_periods')->where('tenant_id', $tenant)->where('name', 'Finance Demo July-August 2026')->first();
        $service = app(AccountingPeriodService::class);
        if (! $period) $period = $service->create($request, $tenant, ['name' => 'Finance Demo July-August 2026', 'startDate' => '2026-07-01', 'endDate' => $this->closeDate(), 'notes' => 'Closed deterministic Finance Operations demo period'], $owner);
        if ($period->status === 'open') {
            $readiness = $service->readiness($tenant, $period->id);
            if (! $readiness['canClose']) throw new RuntimeException('Finance demo accounting period readiness failed: '.json_encode($readiness['blockers'], JSON_THROW_ON_ERROR));
            $service->close($request, $tenant, $period->id, $owner);
        }
    }
}
