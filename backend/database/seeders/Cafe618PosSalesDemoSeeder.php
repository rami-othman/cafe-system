<?php

namespace Database\Seeders;

use App\Domain\Inventory\InventoryPostingService;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\PosOrderController;
use App\Http\Controllers\Api\RefundController;
use App\Http\Controllers\Api\ShiftController;
use App\Models\User;
use App\Services\FinancialSetupService;
use App\Services\ShiftCashSummaryService;
use Illuminate\Database\Seeder;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * A compact, production-path POS history for Cafe 618.
 *
 * Orders, payments, consumption, COGS and refunds are deliberately created
 * through the same controllers/services used by live POS requests. Recipe and
 * published-menu rows are configuration prerequisites, never financial rows.
 */
final class Cafe618PosSalesDemoSeeder extends Seeder
{
    private int $tenantId;

    private int $ownerId;

    private int $branchId;

    private int $mainWarehouseId;

    private Carbon $today;

    private User $owner;

    public function run(): void
    {
        if (! app()->environment(['local', 'development', 'testing'])) {
            throw new RuntimeException('Cafe618PosSalesDemoSeeder is restricted to local, development, and testing environments.');
        }
        $this->today = now()->startOfDay();
        $this->tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $this->owner = User::query()->where('tenant_id', $this->tenantId)->where('role', 'owner')->firstOrFail();
        // Keep the POS consumption location aligned with the primary branch
        // used by Cafe618InventoryOperationsDemoSeeder's transfer scenarios.
        $branch = DB::table('branches')->where('tenant_id', $this->tenantId)->whereNull('deleted_at')->orderBy('id')->first();
        if (! $this->tenantId || ! $branch) {
            return;
        }
        $this->ownerId = (int) $this->owner->id;
        $this->branchId = (int) $branch->id;
        app(FinancialSetupService::class)->ensureForTenant($this->tenantId, $this->branchId, $this->ownerId);
        app(FinancialSetupService::class)->ensureBranchMainWarehouse($this->tenantId, $this->branchId, $this->ownerId);
        // The POS scenario reuses the standard demo products. Calling the
        // catalog seeder keeps this entry point usable on a fresh local DB
        // without creating a parallel product catalog.
        $this->call(MenuCatalogSeeder::class);
        $this->mainWarehouseId = (int) DB::table('warehouses')->where('tenant_id', $this->tenantId)->where('code', 'BR-'.$this->branchId.'-MAIN')->value('id');
        if (! $this->mainWarehouseId) {
            throw new RuntimeException('Cafe 618 POS branch main warehouse is missing.');
        }

        $schedule = $this->schedule();
        $products = $this->configureProductsAndRecipes();
        $this->provisionIngredients($schedule, $products);
        $menu = $this->publishedSnapshot($products);
        $this->ensureCardPaymentMethod();

        // A caller (e.g. a test that already froze time with Carbon::setTestNow()
        // to make its own idempotency-rerun assertions meaningful) must get its
        // exact frozen instant back, not real wall-clock time — clearing it
        // unconditionally here previously meant a second run of this seeder,
        // inside the same frozen test, silently computed a different "today"
        // and re-sold a full day's worth of orders under new idempotency keys.
        $previousTestNow = Carbon::hasTestNow() ? Carbon::getTestNow() : null;
        try {
            foreach ($schedule as $entry) {
                $daysAgo = $entry['daysAgo'];
                $index = $entry['index'];
                $at = $this->today->copy()->subDays($daysAgo)->setTime(8 + ($index % 9), 10 + (($index * 7) % 45));
                Carbon::setTestNow($at);
                $shift = $this->shift($daysAgo);
                $productId = $products[$entry['productKey']];
                $this->sale($daysAgo, $index, $shift, $menu, $productId, $entry['method'], $entry['quantity']);
                if ($daysAgo > 0) {
                    Carbon::setTestNow($at->copy()->setTime(21, 0));
                    $this->closeShift($shift);
                }
            }
        } finally {
            Carbon::setTestNow($previousTestNow);
        }
    }

    /** @return list<array{daysAgo:int,index:int,productKey:string,method:string,quantity:int}> */
    private function schedule(): array
    {
        $schedule = [];
        foreach ($this->saleDays() as $index => $daysAgo) {
            $schedule[] = [
                'daysAgo' => $daysAgo,
                'index' => $index,
                'productKey' => $index % 3 === 2 ? 'iced' : 'cappuccino',
                'method' => $index % 3 === 0 ? 'card' : 'cash',
                'quantity' => 1 + ($index % 2),
            ];
        }

        return $schedule;
    }

    /**
     * Provisions each recipe ingredient this schedule will actually consume,
     * with a 50% safety margin, so this seeder is self-sufficient regardless
     * of whatever opening stock another seeder (e.g.
     * Cafe618InventoryOperationsDemoSeeder) happens to provide at this
     * warehouse. Idempotent per material: reruns never receive twice.
     *
     * @param  list<array{daysAgo:int,index:int,productKey:string,method:string,quantity:int}>  $schedule
     * @param  array{cappuccino:int, iced:int}  $products
     */
    private function provisionIngredients(array $schedule, array $products): void
    {
        $unitsSold = ['cappuccino' => 0, 'iced' => 0];
        foreach ($schedule as $entry) {
            $unitsSold[$entry['productKey']] += $entry['quantity'];
        }

        $needed = [];
        foreach ($unitsSold as $key => $units) {
            if ($units === 0) {
                continue;
            }
            $recipeId = (int) DB::table('recipes')->where('tenant_id', $this->tenantId)->where('product_id', $products[$key])->where('version', 1)->value('id');
            foreach (DB::table('recipe_lines')->where('recipe_id', $recipeId)->get() as $line) {
                $itemId = (int) $line->inventory_item_id;
                $needed[$itemId] ??= ['unit' => $line->unit, 'quantity' => 0.0];
                $needed[$itemId]['quantity'] += (float) $line->quantity * $units;
            }
        }

        $posting = app(InventoryPostingService::class);
        foreach ($needed as $itemId => $info) {
            $quantity = ceil($info['quantity'] * 1.5 * 1000) / 1000;
            $unitCost = (string) (DB::table('inventory_items')->where('id', $itemId)->value('latest_unit_cost') ?: '1.0000');
            $posting->post($this->request('/api/v1/inventory/movements', []), $this->tenantId, [
                'warehouseId' => $this->mainWarehouseId,
                'itemId' => $itemId,
                'type' => 'stock_in',
                'quantity' => number_format($quantity, 3, '.', ''),
                'unit' => $info['unit'],
                'unitCost' => $unitCost,
                'branchId' => $this->branchId,
                'reason' => 'Cafe 618 POS demo — projected ingredient replenishment',
                'referenceType' => 'cafe618_pos_demo_provisioning',
                'referenceId' => $itemId,
                'idempotencyKey' => 'cafe618-pos-demo-provision-'.$itemId,
            ], $this->ownerId);
        }
    }

    /** @return array{cappuccino:int, iced:int} */
    private function configureProductsAndRecipes(): array
    {
        $products = [];
        foreach (['cappuccino' => 'Cappuccino', 'iced' => 'Iced Caramel Macchiato'] as $key => $name) {
            $id = (int) DB::table('products')->where('tenant_id', $this->tenantId)->where('name', $name)->value('id');
            if (! $id) {
                throw new RuntimeException("Cafe 618 menu product {$name} is missing.");
            }
            // is_stock_tracked is the canonical "Track Inventory" flag; setting
            // it (rather than the legacy inventory_controlled column directly)
            // is the same production-supported configuration a real product
            // edit would perform — see CatalogProductService::productPayload(),
            // which mirrors inventory_controlled from this value on every write.
            DB::table('products')->where('id', $id)->update(['is_stock_tracked' => true, 'updated_at' => now()]);
            DB::table('product_inventory_settings')->updateOrInsert(
                ['tenant_id' => $this->tenantId, 'product_id' => $id, 'branch_id' => $this->branchId],
                ['warehouse_id' => $this->mainWarehouseId, 'created_at' => now(), 'updated_at' => now()],
            );
            $products[$key] = $id;
        }
        $materials = DB::table('inventory_items')->where('tenant_id', $this->tenantId)->whereIn('sku', ['INV-BEANS', 'INV-MILK-FRESH', 'INV-CUP-12OZ', 'INV-VANILLA', 'INV-CARAMEL'])->pluck('id', 'sku');
        foreach (['INV-BEANS', 'INV-MILK-FRESH', 'INV-CUP-12OZ', 'INV-VANILLA', 'INV-CARAMEL'] as $sku) {
            if (! isset($materials[$sku])) {
                throw new RuntimeException("Cafe 618 POS recipe material {$sku} is missing.");
            }
        }
        $this->recipe($products['cappuccino'], 'Cafe 618 Cappuccino Recipe', [
            [$materials['INV-BEANS'], '0.018', 'kg'], [$materials['INV-MILK-FRESH'], '0.180', 'liter'], [$materials['INV-CUP-12OZ'], '1.000', 'piece'],
        ]);
        $this->recipe($products['iced'], 'Cafe 618 Iced Caramel Recipe', [
            [$materials['INV-BEANS'], '0.018', 'kg'], [$materials['INV-MILK-FRESH'], '0.220', 'liter'], [$materials['INV-CUP-12OZ'], '1.000', 'piece'], [$materials['INV-VANILLA'], '0.020', 'bottle'], [$materials['INV-CARAMEL'], '0.020', 'bottle'],
        ]);

        return $products;
    }

    private function recipe(int $productId, string $name, array $lines): void
    {
        DB::table('recipes')->updateOrInsert(['tenant_id' => $this->tenantId, 'product_id' => $productId, 'version' => 1], ['name' => $name, 'is_active' => true, 'yield_quantity' => '1.000', 'yield_unit' => 'piece', 'created_by' => $this->ownerId, 'created_at' => now(), 'updated_at' => now()]);
        $recipeId = (int) DB::table('recipes')->where('tenant_id', $this->tenantId)->where('product_id', $productId)->where('version', 1)->value('id');
        foreach ($lines as $number => [$materialId, $quantity, $unit]) {
            DB::table('recipe_lines')->updateOrInsert(['recipe_id' => $recipeId, 'inventory_item_id' => $materialId], ['tenant_id' => $this->tenantId, 'quantity' => $quantity, 'unit' => $unit, 'wastage_percentage' => '0.000', 'line_number' => $number + 1, 'created_at' => now(), 'updated_at' => now()]);
        }
    }

    /** @param array{cappuccino:int, iced:int} $products @return array{versionId:int,placements:array<int,int>,variants:array<int,int>} */
    private function publishedSnapshot(array $products): array
    {
        $checksum = hash('sha256', 'cafe-618-pos-demo-menu-v1');
        $existing = DB::table('published_menu_versions')->where('tenant_id', $this->tenantId)->where('branch_id', $this->branchId)->where('channel', 'pos')->where('checksum', $checksum)->first();
        if ($existing) {
            $payload = json_decode((string) $existing->payload_json, true, flags: JSON_THROW_ON_ERROR);
            $placements = [];
            $variants = [];
            foreach ($payload['menus'][0]['sections'][0]['products'] as $product) {
                $placements[(int) $product['productId']] = (int) $product['placementId'];
                $variants[(int) $product['productId']] = (int) $product['variants'][0]['id'];
            }

            return ['versionId' => (int) $existing->id, 'placements' => $placements, 'variants' => $variants];
        }
        $now = now();
        $menuId = (int) DB::table('menus')->insertGetId(['tenant_id' => $this->tenantId, 'name' => 'Cafe 618 POS Demo Menu', 'name_en' => 'Cafe 618 POS Demo Menu', 'status' => 'published', 'created_at' => $now, 'updated_at' => $now]);
        $sectionId = (int) DB::table('menu_sections')->insertGetId(['tenant_id' => $this->tenantId, 'menu_id' => $menuId, 'name' => 'Coffee', 'name_en' => 'Coffee', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $snapshotProducts = [];
        $placements = [];
        $variants = [];
        foreach ($products as $productId) {
            $product = DB::table('products')->where('id', $productId)->first();
            $variant = DB::table('product_variants')->where('tenant_id', $this->tenantId)->where('product_id', $productId)->where('is_active', true)->orderByDesc('is_default')->orderBy('id')->first();
            $placementId = (int) DB::table('menu_item_placements')->insertGetId(['tenant_id' => $this->tenantId, 'menu_section_id' => $sectionId, 'product_id' => $productId, 'is_visible' => true, 'sort_order' => count($snapshotProducts), 'created_at' => $now, 'updated_at' => $now]);
            $recipe = DB::table('recipes')->where('tenant_id', $this->tenantId)->where('product_id', $productId)->where('is_active', true)->orderByDesc('version')->first();
            $components = DB::table('recipe_lines')->where('recipe_id', $recipe->id)->orderBy('line_number')->get()->map(fn (object $line) => ['materialId' => (int) $line->inventory_item_id, 'quantity' => (string) $line->quantity, 'unitCode' => (string) $line->unit])->all();
            $snapshotProducts[] = ['placementId' => $placementId, 'productId' => $productId, 'name' => ['default' => $product->name], 'isVisible' => true, 'productAvailabilityRules' => [], 'variants' => [['id' => $variant->id, 'name' => ['default' => $variant->name], 'effectivePrice' => (string) $product->price, 'baseRecipe' => $components, 'modifierRecipeAdjustments' => []]], 'modifierGroups' => []];
            $placements[$productId] = $placementId;
            $variants[$productId] = (int) $variant->id;
        }
        $publicationId = (int) DB::table('menu_publications')->insertGetId(['tenant_id' => $this->tenantId, 'status' => 'published', 'published_by' => $this->ownerId, 'published_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        DB::table('published_menu_versions')->where('tenant_id', $this->tenantId)->where('branch_id', $this->branchId)->where('channel', 'pos')->where('status', 'current')->update(['status' => 'superseded', 'updated_at' => $now]);
        $versionId = (int) DB::table('published_menu_versions')->insertGetId(['tenant_id' => $this->tenantId, 'menu_publication_id' => $publicationId, 'branch_id' => $this->branchId, 'channel' => 'pos', 'version_number' => (int) DB::table('published_menu_versions')->where('tenant_id', $this->tenantId)->where('branch_id', $this->branchId)->where('channel', 'pos')->max('version_number') + 1, 'payload_json' => json_encode(['context' => ['schemaVersion' => 3], 'menus' => [['id' => $menuId, 'availabilityRules' => [], 'sections' => [['id' => $sectionId, 'products' => $snapshotProducts]]]]]), 'checksum' => $checksum, 'status' => 'current', 'published_at' => $now, 'created_at' => $now, 'updated_at' => $now]);

        return compact('versionId', 'placements', 'variants');
    }

    private function sale(int $daysAgo, int $index, int $shiftId, array $menu, int $productId, string $method, int $quantity): void
    {
        $key = 'cafe-618-pos-'.$this->today->format('Ymd').'-'.$daysAgo.'-'.$index;
        $existing = DB::table('orders')->where('tenant_id', $this->tenantId)->where('idempotency_key', $key)->first();
        if ($existing) {
            return;
        }
        $request = $this->request('/api/v1/orders', ['branchId' => $this->branchId, 'shiftId' => $shiftId, 'orderType' => 'takeaway', 'publishedMenuVersionId' => $menu['versionId'], 'items' => [['productId' => $productId, 'placementId' => $menu['placements'][$productId], 'variantId' => $menu['variants'][$productId], 'quantity' => $quantity]], 'idempotencyKey' => $key]);
        $order = app(PosOrderController::class)->store($request)->getData(true)['data'];
        $payment = app(PaymentController::class)->pay($this->request('/api/v1/orders/'.$order['id'].'/pay', ['method' => $method, 'paymentMethodId' => $method === 'card' ? $this->paymentMethod('CARD') : $this->paymentMethod('CASH'), 'amount' => $order['totals']['total'], 'reference' => strtoupper($method).'-'.$daysAgo.'-'.$index, 'idempotencyKey' => $key.'-payment']), (int) $order['id']);
        if ($index === 4 || $index === 13) {
            $type = $index === 4 ? 'partial' : 'full';
            app(RefundController::class)->store($this->request('/api/v1/orders/'.$order['id'].'/refund', ['type' => $type, 'amount' => $type === 'partial' ? '1.00' : null, 'reason' => 'Cafe 618 demo '.$type.' refund', 'idempotencyKey' => $key.'-refund']), (int) $order['id']);
        }
        unset($payment);
    }

    private function shift(int $daysAgo): int
    {
        $note = 'Cafe 618 POS demo shift '.$this->today->format('Ymd').'-'.$daysAgo;
        $existing = DB::table('shifts')->where('tenant_id', $this->tenantId)->where('notes', $note)->value('id');
        if ($existing) {
            return (int) $existing;
        }
        $id = (int) app(ShiftController::class)->open($this->request('/api/v1/shifts/current', ['branchId' => $this->branchId, 'openingCash' => 50]))->getData(true)['data']['id'];
        DB::table('shifts')->where('id', $id)->update(['notes' => $note, 'updated_at' => now()]);

        return $id;
    }

    private function closeShift(int $shiftId): void
    {
        $shift = DB::table('shifts')->where('id', $shiftId)->first();
        if (! $shift || $shift->status !== 'open') {
            return;
        }
        $expected = app(ShiftCashSummaryService::class)->summarize($this->tenantId, $shift)['expectedCash'];
        app(ShiftController::class)->close($this->request('/api/v1/shifts/'.$shiftId.'/close', ['closingCash' => $expected, 'note' => $shift->notes]), $shiftId);
    }

    private function ensureCardPaymentMethod(): void
    {
        $account = DB::table('financial_accounts')->where('tenant_id', $this->tenantId)->where('code', '1030')->value('id');
        DB::table('payment_methods')->updateOrInsert(['tenant_id' => $this->tenantId, 'code' => 'CARD'], ['name' => 'Card', 'type' => 'card', 'financial_account_id' => $account, 'financial_location_id' => null, 'is_active' => true, 'sort_order' => 2, 'created_by' => $this->ownerId, 'updated_by' => $this->ownerId, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function paymentMethod(string $code): int
    {
        return (int) DB::table('payment_methods')->where('tenant_id', $this->tenantId)->where('code', $code)->where('is_active', true)->value('id');
    }

    private function request(string $uri, array $data): Request
    {
        $request = Request::create($uri, 'POST', $data);
        $request->attributes->set('tenant_id', $this->tenantId);
        $request->attributes->set('auth_user', $this->owner);

        return $request;
    }

    /** @return list<int> */
    private function saleDays(): array
    {
        return [59, 56, 53, 50, 47, 44, 41, 38, 35, 32, 29, 26, 23, 20, 17, 14, 11, 8, 6, 4, 2, 0];
    }
}
