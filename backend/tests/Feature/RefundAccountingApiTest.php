<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Phase 4 — Refund -> Finance posting. A refund is its own source-linked
 * business transaction (sourceEvent PAYMENT_REFUNDED), never a
 * JournalEntryService::reverse() of the original sale, and never returns
 * inventory automatically — payment_refunds carries no restock metadata, so
 * fabricating a stock-in would invent data the business flow never captured.
 */
class RefundAccountingApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_cash_refund_debits_sales_returns_and_credits_the_original_cash_account(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $orderId = $this->paidCashOrder($tenant, $headers, quantity: 2);
        $paidTotal = (float) DB::table('orders')->where('id', $orderId)->value('total');
        $drawerId = (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'CASH-DRAWER')->value('id');
        $balanceBefore = (float) $this->getJson('/api/v1/finance/cash-accounts/'.$drawerId.'/transactions', $headers)->json('data.location.balance');

        $refund = $this->postJson("/api/v1/orders/{$orderId}/refunds", ['type' => 'full', 'reason' => 'Customer complaint', 'idempotencyKey' => 'refund-cash-1'], $headers)
            ->assertCreated();
        $refundId = $refund->json('data.id');

        $entry = DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'payment_refund')->where('source_id', $refundId)->where('source_event', 'PAYMENT_REFUNDED')->first();
        $this->assertNotNull($entry);
        $this->assertSame('posted', $entry->status);
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $entry->id)->get();
        $this->assertCount(2, $lines);
        $this->assertSame(round($paidTotal, 2), round((float) $lines->sum('debit'), 2));
        $this->assertSame(round($paidTotal, 2), round((float) $lines->sum('credit'), 2));

        $salesReturnsId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '4020')->value('id');
        $cashAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $this->assertSame(round($paidTotal, 2), round((float) $lines->firstWhere('financial_account_id', $salesReturnsId)->debit, 2));
        $this->assertSame(round($paidTotal, 2), round((float) $lines->firstWhere('financial_account_id', $cashAccountId)->credit, 2));

        $balanceAfter = (float) $this->getJson('/api/v1/finance/cash-accounts/'.$drawerId.'/transactions', $headers)->json('data.location.balance');
        $this->assertSame(round($balanceBefore - $paidTotal, 2), round($balanceAfter, 2));
    }

    public function test_non_cash_refund_credits_the_original_card_account_not_cash(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $bankAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1030')->value('id');
        $cardMethodId = $this->postJson('/api/v1/finance/payment-methods', ['code' => 'CARD', 'name' => 'Card', 'type' => 'card', 'financialAccountId' => $bankAccountId, 'isActive' => true], $headers)
            ->assertCreated()->json('data.id');

        $orderId = $this->paidOrder($tenant, $headers, quantity: 1, method: 'card', paymentMethodId: $cardMethodId);
        $paidTotal = (float) DB::table('orders')->where('id', $orderId)->value('total');

        $refund = $this->postJson("/api/v1/orders/{$orderId}/refunds", ['type' => 'full', 'reason' => 'Wrong item', 'idempotencyKey' => 'refund-card-1'], $headers)
            ->assertCreated();

        $entry = DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'payment_refund')->where('source_id', $refund->json('data.id'))->first();
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $entry->id)->get();
        $this->assertSame(round($paidTotal, 2), round((float) $lines->firstWhere('financial_account_id', $bankAccountId)->credit, 2));
        $cashAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $this->assertNull($lines->firstWhere('financial_account_id', $cashAccountId));
    }

    public function test_partial_refund_posts_only_the_refunded_amount_and_can_be_followed_by_a_second_partial(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $orderId = $this->paidCashOrder($tenant, $headers, quantity: 3);
        $paidTotal = (float) DB::table('orders')->where('id', $orderId)->value('total');
        $firstAmount = round($paidTotal / 3, 2);

        $first = $this->postJson("/api/v1/orders/{$orderId}/refunds", ['type' => 'partial', 'amount' => $firstAmount, 'reason' => 'Partial A', 'idempotencyKey' => 'refund-partial-1'], $headers)
            ->assertCreated()->assertJsonPath('data.amount', $firstAmount);
        $firstEntry = DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'payment_refund')->where('source_id', $first->json('data.id'))->first();
        $firstLines = DB::table('journal_entry_lines')->where('journal_entry_id', $firstEntry->id)->get();
        $this->assertSame($firstAmount, round((float) $firstLines->sum('debit'), 2));

        $remaining = round($paidTotal - $firstAmount, 2);
        $second = $this->postJson("/api/v1/orders/{$orderId}/refunds", ['type' => 'partial', 'amount' => $remaining, 'reason' => 'Partial B', 'idempotencyKey' => 'refund-partial-2'], $headers)
            ->assertCreated();
        $this->assertNotSame($first->json('data.id'), $second->json('data.id'));
        $this->assertSame(2, DB::table('payment_refunds')->where('tenant_id', $tenant)->where('order_id', $orderId)->count());
        $this->assertSame(2, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'payment_refund')->whereIn('source_id', [$first->json('data.id'), $second->json('data.id')])->count());
    }

    public function test_duplicate_refund_posting_is_impossible_and_replay_returns_the_same_journal(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $orderId = $this->paidCashOrder($tenant, $headers, quantity: 1);

        $first = $this->postJson("/api/v1/orders/{$orderId}/refunds", ['type' => 'full', 'reason' => 'Refund replay test', 'idempotencyKey' => 'refund-replay-1'], $headers)
            ->assertCreated();
        $replay = $this->postJson("/api/v1/orders/{$orderId}/refunds", ['type' => 'full', 'reason' => 'Refund replay test', 'idempotencyKey' => 'refund-replay-1'], $headers)
            ->assertCreated();

        $this->assertSame($first->json('data.id'), $replay->json('data.id'));
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'payment_refund')->where('source_id', $first->json('data.id'))->count());
    }

    public function test_refund_never_returns_inventory_and_original_payment_history_stays_immutable(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);

        $itemId = (int) $this->postJson('/api/v1/inventory/items', [
            'nameAr' => 'مكون اختبار الاسترجاع', 'nameEn' => 'Refund Test Ingredient', 'sku' => 'REFUND-TEST-'.uniqid(),
            'itemType' => 'raw_material', 'unit' => 'kg', 'minimumStock' => '1.000', 'reorderLevel' => '1.000', 'latestUnitCost' => '2.0000', 'isActive' => true,
        ], $headers)->assertCreated()->json('data.id');
        $warehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->where('code', "BR-{$branchId}-MAIN")->value('id');
        $this->postJson('/api/v1/inventory/movements', ['warehouseId' => $warehouseId, 'itemId' => $itemId, 'type' => 'stock_in', 'quantity' => '10.000', 'unitCost' => '2.0000', 'reason' => 'Opening'], $headers)->assertCreated();

        $productId = (int) DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => 'Refund Test Product', 'price' => '10.00', 'cost_price' => 0, 'is_active' => true, 'is_stock_tracked' => false, 'inventory_controlled' => true, 'consumption_type' => 'bar', 'sort_order' => 0, 'created_at' => now(), 'updated_at' => now()]);
        $recipeId = (int) DB::table('recipes')->insertGetId(['tenant_id' => $tenant, 'product_id' => $productId, 'name' => 'Refund Test Recipe', 'version' => 1, 'is_active' => true, 'yield_quantity' => 1, 'yield_unit' => 'piece', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('recipe_lines')->insert(['tenant_id' => $tenant, 'recipe_id' => $recipeId, 'inventory_item_id' => $itemId, 'quantity' => '2.000', 'unit' => 'kg', 'wastage_percentage' => 0, 'line_number' => 1, 'created_at' => now(), 'updated_at' => now()]);

        $shiftId = $this->openShift($tenant, $branchId, $headers);
        $snapshot = $this->publishedSnapshot($tenant, $branchId, [$productId]);
        $order = $this->postJson('/api/v1/orders', [
            'branchId' => $branchId,
            'shiftId' => $shiftId,
            'orderType' => 'takeaway',
            'publishedMenuVersionId' => $snapshot['versionId'],
            'items' => [[
                'productId' => $productId,
                'placementId' => $snapshot['placements'][$productId],
                'variantId' => $snapshot['variants'][$productId],
                'quantity' => 1,
            ]],
        ], $headers)->assertCreated();
        $orderId = $order->json('data.id');
        $totals = $order->json('data.totals');
        $this->postJson("/api/v1/orders/{$orderId}/pay", ['method' => 'cash', 'amount' => $totals['total'], 'idempotencyKey' => 'refund-no-restock-pay-1'], $headers)->assertOk();
        $balanceAfterSale = (float) DB::table('stock_balances')->where('tenant_id', $tenant)->where('inventory_item_id', $itemId)->value('quantity_on_hand');
        $this->assertSame(8.0, $balanceAfterSale);
        $movementCountAfterSale = DB::table('stock_movements')->where('tenant_id', $tenant)->where('inventory_item_id', $itemId)->count();

        $paymentBefore = DB::table('payments')->where('order_id', $orderId)->first();
        $this->postJson("/api/v1/orders/{$orderId}/refunds", ['type' => 'full', 'reason' => 'Coffee spilled, cannot restock', 'idempotencyKey' => 'refund-no-restock-1'], $headers)->assertCreated();

        $balanceAfterRefund = (float) DB::table('stock_balances')->where('tenant_id', $tenant)->where('inventory_item_id', $itemId)->value('quantity_on_hand');
        $this->assertSame($balanceAfterSale, $balanceAfterRefund, 'A refund must never fabricate a stock return.');
        $this->assertSame($movementCountAfterSale, DB::table('stock_movements')->where('tenant_id', $tenant)->where('inventory_item_id', $itemId)->count());

        $paymentAfter = DB::table('payments')->where('order_id', $orderId)->first();
        $this->assertSame($paymentBefore->amount, $paymentAfter->amount);
        $this->assertSame($paymentBefore->status, $paymentAfter->status);
    }

    private function paidCashOrder(int $tenant, array $headers, int $quantity): int
    {
        return $this->paidOrder($tenant, $headers, $quantity, 'cash', null);
    }

    private function paidOrder(int $tenant, array $headers, int $quantity, string $method, ?int $paymentMethodId): int
    {
        $branchId = $this->downtownBranchId($tenant);
        $shiftId = $this->openShift($tenant, $branchId, $headers);
        $product = DB::table('products')->where('tenant_id', $tenant)->where('name', 'Cappuccino')->first();
        $modifiers = DB::table('product_modifier_group')
            ->join('modifier_groups', 'modifier_groups.id', '=', 'product_modifier_group.modifier_group_id')
            ->join('modifier_options', 'modifier_options.modifier_group_id', '=', 'modifier_groups.id')
            ->where('product_modifier_group.product_id', $product->id)
            ->where('modifier_groups.is_required', true)
            ->where('modifier_options.is_default', true)
            ->select(['modifier_groups.id as groupId', 'modifier_options.id as optionId'])
            ->get()
            ->map(fn ($modifier) => ['groupId' => $modifier->groupId, 'optionId' => $modifier->optionId])
            ->all();

        $order = $this->postJson('/api/v1/orders', [
            'branchId' => $branchId,
            'shiftId' => $shiftId,
            'orderType' => 'takeaway',
            'items' => [['productId' => $product->id, 'quantity' => $quantity, 'modifiers' => $modifiers]],
        ], $headers)->assertCreated();
        $orderId = $order->json('data.id');
        $totals = $order->json('data.totals');

        $payload = ['method' => $method, 'amount' => $totals['total'], 'idempotencyKey' => 'refund-fixture-pay-'.uniqid()];
        if ($paymentMethodId !== null) {
            $payload['paymentMethodId'] = $paymentMethodId;
        }
        $this->postJson("/api/v1/orders/{$orderId}/pay", $payload, $headers)->assertOk();

        return $orderId;
    }

    /**
     * Builds the minimal schema-v3 snapshot needed for an inventory-controlled product.
     *
     * @param list<int> $productIds
     * @return array{versionId:int, placements:array<int,int>, variants:array<int,int>}
     */
    private function publishedSnapshot(int $tenant, int $branchId, array $productIds): array
    {
        $now = now();
        DB::table('published_menu_versions')
            ->where('tenant_id', $tenant)->where('branch_id', $branchId)->where('channel', 'pos')->where('status', 'current')
            ->update(['status' => 'superseded', 'updated_at' => $now]);

        $menuId = DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => 'Refund accounting '.uniqid(), 'status' => 'published', 'created_at' => $now, 'updated_at' => $now]);
        $sectionId = DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menuId, 'name' => 'Published refunds', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $products = [];
        $placements = [];
        $variants = [];
        foreach ($productIds as $productId) {
            $product = DB::table('products')->where('tenant_id', $tenant)->where('id', $productId)->firstOrFail();
            $variant = DB::table('product_variants')->where('tenant_id', $tenant)->where('product_id', $productId)->where('is_active', true)->orderByDesc('is_default')->orderBy('id')->first();
            if ($variant === null) {
                $variantId = DB::table('product_variants')->insertGetId([
                    'tenant_id' => $tenant, 'product_id' => $productId, 'name' => 'Regular',
                    'base_price' => $product->price, 'cost_price' => $product->cost_price,
                    'is_default' => true, 'is_active' => true, 'sort_order' => 0,
                    'created_at' => $now, 'updated_at' => $now,
                ]);
                $variant = DB::table('product_variants')->where('id', $variantId)->firstOrFail();
            }

            $placementId = DB::table('menu_item_placements')->insertGetId([
                'tenant_id' => $tenant, 'menu_section_id' => $sectionId, 'product_id' => $productId,
                'is_visible' => true, 'sort_order' => 0, 'created_at' => $now, 'updated_at' => $now,
            ]);
            $placements[$productId] = $placementId;
            $variants[$productId] = (int) $variant->id;
            $baseRecipe = DB::table('recipes')->where('tenant_id', $tenant)->where('product_id', $productId)->where('is_active', true)->orderByDesc('version')->first();
            $components = $baseRecipe === null ? [] : DB::table('recipe_lines')->where('recipe_id', $baseRecipe->id)->orderBy('line_number')->get()
                ->map(fn (object $line) => ['materialId' => (int) $line->inventory_item_id, 'quantity' => (string) $line->quantity, 'unitCode' => (string) $line->unit, 'sortOrder' => (int) $line->line_number])->all();
            $products[] = ['placementId' => $placementId, 'productId' => $productId, 'name' => ['default' => $product->name], 'isVisible' => true,
                'productAvailabilityRules' => [], 'variants' => [['id' => $variant->id, 'name' => ['default' => $variant->name], 'effectivePrice' => (string) $product->price,
                    'baseRecipe' => $components, 'modifierRecipeAdjustments' => []]], 'modifierGroups' => []];
        }

        $publicationId = DB::table('menu_publications')->insertGetId(['tenant_id' => $tenant, 'status' => 'published', 'published_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        $versionId = DB::table('published_menu_versions')->insertGetId([
            'tenant_id' => $tenant, 'menu_publication_id' => $publicationId, 'branch_id' => $branchId, 'channel' => 'pos',
            'version_number' => (int) DB::table('published_menu_versions')->where('tenant_id', $tenant)->where('branch_id', $branchId)->where('channel', 'pos')->max('version_number') + 1,
            'payload_json' => json_encode(['context' => ['schemaVersion' => 3], 'menus' => [['id' => 1, 'availabilityRules' => [], 'sections' => [['id' => 1, 'products' => $products]]]]]),
            'checksum' => hash('sha256', uniqid('refund-accounting-', true)), 'status' => 'current', 'published_at' => $now, 'created_at' => $now, 'updated_at' => $now,
        ]);

        return compact('versionId', 'placements', 'variants');
    }

    private function openShift(int $tenant, int $branchId, array $headers): int
    {
        return (int) $this->postJson('/api/v1/shifts/current', ['branchId' => $branchId, 'openingCash' => 0], $headers)
            ->assertCreated()->json('data.id');
    }

    private function downtownBranchId(int $tenant): int
    {
        return (int) DB::table('branches')->where('tenant_id', $tenant)->where('name', 'Downtown')->value('id');
    }

    private function demoTenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        $plainToken = "refund-accounting-test-$tenantId-$userId";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'refund-accounting-test'], ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }
}
