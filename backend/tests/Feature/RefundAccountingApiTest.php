<?php

namespace Tests\Feature;

use App\Models\Branch;
use App\Models\ProductVariant;
use App\Services\Catalog\RecipeConfigurationService;
use App\Services\FinancialAccountBalanceQuery;
use App\Services\Menu\PublishedMenuSnapshotBuilder;
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

    public function test_cash_refund_after_sale_shift_closes_is_blocked_without_changing_closed_summary(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $orderId = $this->paidCashOrder($tenant, $headers, quantity: 1);
        $order = DB::table('orders')->where('id', $orderId)->first();
        $shiftId = (int) $order->shift_id;
        $safe = DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        DB::table('shifts')->where('id', $shiftId)->update([
            'close_destination_financial_location_id' => $safe, 'closing_float_amount' => '0.00',
        ]);
        $this->postJson("/api/v1/shifts/{$shiftId}/close", ['closingCash' => $order->total], $headers)->assertOk();
        $before = DB::table('shifts')->where('id', $shiftId)->first();
        $refundCount = DB::table('payment_refunds')->where('order_id', $orderId)->count();

        $this->postJson("/api/v1/orders/{$orderId}/refunds", [
            'type' => 'full', 'reason' => 'Late cash refund', 'idempotencyKey' => 'late-cash-refund',
        ], $headers)->assertUnprocessable();
        $this->assertSame($refundCount, DB::table('payment_refunds')->where('order_id', $orderId)->count());
        $this->assertSame($before->expected_cash, DB::table('shifts')->where('id', $shiftId)->value('expected_cash'));
        $this->assertSame('closed', DB::table('shifts')->where('id', $shiftId)->value('status'));
    }

    public function test_card_refund_after_sale_shift_closes_remains_available(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $bankAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1030')->value('id');
        $cardMethodId = $this->postJson('/api/v1/finance/payment-methods', [
            'code' => 'LATE-CARD', 'name' => 'Late card', 'type' => 'card',
            'financialAccountId' => $bankAccountId, 'isActive' => true,
        ], $headers)->assertCreated()->json('data.id');
        $orderId = $this->paidOrder($tenant, $headers, 1, 'card', $cardMethodId);
        $shiftId = (int) DB::table('orders')->where('id', $orderId)->value('shift_id');
        $safe = DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
        DB::table('shifts')->where('id', $shiftId)->update([
            'close_destination_financial_location_id' => $safe, 'closing_float_amount' => '0.00',
        ]);
        $this->postJson("/api/v1/shifts/{$shiftId}/close", ['closingCash' => '0.00'], $headers)->assertOk();
        $this->postJson("/api/v1/orders/{$orderId}/refunds", [
            'type' => 'full', 'reason' => 'Late card refund', 'idempotencyKey' => 'late-card-refund',
        ], $headers)->assertCreated();
    }

    public function test_cash_refund_debits_sales_returns_and_credits_the_original_cash_account(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $orderId = $this->paidCashOrder($tenant, $headers, quantity: 2);
        $order = DB::table('orders')->where('id', $orderId)->first();
        $paidTotal = (float) $order->total;
        $shiftId = (int) DB::table('orders')->where('id', $orderId)->value('shift_id');
        $drawerId = (int) DB::table('shifts')->where('id', $shiftId)->value('financial_location_id');
        $balanceBefore = (float) $this->getJson('/api/v1/finance/cash-accounts/'.$drawerId.'/transactions', $headers)->json('data.location.balance');
        $this->assertSame(round($paidTotal, 2), round($balanceBefore, 2));

        $refund = $this->postJson("/api/v1/orders/{$orderId}/refunds", ['type' => 'full', 'reason' => 'Customer complaint', 'idempotencyKey' => 'refund-cash-1'], $headers)
            ->assertCreated();
        $refundId = $refund->json('data.id');

        $entry = DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'payment_refund')->where('source_id', $refundId)->where('source_event', 'PAYMENT_REFUNDED')->first();
        $this->assertNotNull($entry);
        $this->assertSame('posted', $entry->status);
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $entry->id)->get();
        $this->assertCount((float) $order->tax_total > 0 ? 3 : 2, $lines);
        $this->assertSame(round($paidTotal, 2), round((float) $lines->sum('debit'), 2));
        $this->assertSame(round($paidTotal, 2), round((float) $lines->sum('credit'), 2));

        $salesReturnsId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '4020')->value('id');
        $cashAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $this->assertSame(round($paidTotal - (float) $order->tax_total, 2), round((float) $lines->firstWhere('financial_account_id', $salesReturnsId)->debit, 2));
        $this->assertSame(round($paidTotal, 2), round((float) $lines->firstWhere('financial_account_id', $cashAccountId)->credit, 2));
        $this->assertSame($drawerId, (int) $lines->firstWhere('financial_account_id', $cashAccountId)->financial_location_id);
        $this->assertNull($lines->firstWhere('financial_account_id', $salesReturnsId)->financial_location_id);

        $balanceAfter = (float) $this->getJson('/api/v1/finance/cash-accounts/'.$drawerId.'/transactions', $headers)->json('data.location.balance');
        $this->assertSame(round($balanceBefore - $paidTotal, 2), round($balanceAfter, 2));
    }

    public function test_cash_sale_and_partial_refund_change_only_the_shift_drawer_and_replay_once(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $orderId = $this->paidCashOrder($tenant, $headers, quantity: 10);
        $order = DB::table('orders')->where('id', $orderId)->first();
        $this->assertGreaterThan(30, (float) $order->total);
        $drawer = DB::table('shifts')->where('id', $order->shift_id)->value('financial_location_id');
        $cashAccount = (int) DB::table('financial_locations')->where('id', $drawer)->value('financial_account_id');
        $sale = DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'pos_order')->where('source_id', $orderId)->sole();
        $saleLines = DB::table('journal_entry_lines')->where('journal_entry_id', $sale->id)->get();
        $cashLine = $saleLines->firstWhere('financial_account_id', $cashAccount);
        $this->assertSame((int) $drawer, (int) $cashLine->financial_location_id);
        $this->assertSame((float) $order->total, (float) $cashLine->debit);
        $this->assertEquals($saleLines->sum('debit'), $saleLines->sum('credit'));
        $this->assertSame(1, $saleLines->whereNotNull('financial_location_id')->count());
        $payment = DB::table('payments')->where('order_id', $orderId)->sole();
        $this->postJson("/api/v1/orders/{$orderId}/pay", [
            'method' => 'cash', 'amount' => (float) $order->total, 'idempotencyKey' => $payment->idempotency_key,
        ], $headers)->assertOk()->assertJsonPath('data.payment.id', $payment->id);
        $this->assertSame(1, DB::table('journal_entries')->where('source_type', 'pos_order')->where('source_id', $orderId)->count());
        $balances = app(FinancialAccountBalanceQuery::class);
        $accountBeforeRefund = (float) $balances->summary($tenant, $cashAccount)['balance'];
        $drawerBeforeRefund = (float) $balances->summary($tenant, $cashAccount, locationId: (int) $drawer)['balance'];

        $payload = ['type' => 'partial', 'amount' => 30, 'reason' => 'Partial cash return', 'idempotencyKey' => 'cash-drawer-partial'];
        $first = $this->postJson("/api/v1/orders/{$orderId}/refunds", $payload, $headers)->assertCreated();
        $this->postJson("/api/v1/orders/{$orderId}/refunds", $payload, $headers)->assertCreated()
            ->assertJsonPath('data.id', $first->json('data.id'));
        $refund = DB::table('journal_entries')->where('source_type', 'payment_refund')->where('source_id', $first->json('data.id'))->sole();
        $refundLines = DB::table('journal_entry_lines')->where('journal_entry_id', $refund->id)->get();
        $this->assertSame((int) $drawer, (int) $refundLines->firstWhere('financial_account_id', $cashAccount)->financial_location_id);
        $this->assertSame(30.0, (float) $refundLines->firstWhere('financial_account_id', $cashAccount)->credit);
        $this->assertEquals($refundLines->sum('debit'), $refundLines->sum('credit'));
        $this->assertSame(1, $refundLines->whereNotNull('financial_location_id')->count());
        $this->assertEquals((float) $order->total - 30, (float) $this->getJson('/api/v1/finance/cash-accounts/'.$drawer.'/transactions', $headers)->json('data.location.balance'));
        $accountAfterRefund = (float) $balances->summary($tenant, $cashAccount)['balance'];
        $drawerAfterRefund = (float) $balances->summary($tenant, $cashAccount, locationId: (int) $drawer)['balance'];
        $this->assertSame(-30.0, round($accountAfterRefund - $accountBeforeRefund, 2));
        $this->assertSame(-30.0, round($drawerAfterRefund - $drawerBeforeRefund, 2));
        $this->assertSame(round($accountBeforeRefund - $drawerBeforeRefund, 2), round($accountAfterRefund - $drawerAfterRefund, 2));
        $this->assertSame(1, DB::table('journal_entries')->where('source_type', 'payment_refund')->where('source_id', $first->json('data.id'))->count());
    }

    public function test_historical_cash_sale_without_proven_location_keeps_refund_unlocated(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $orderId = $this->paidCashOrder($tenant, $headers, quantity: 1);
        $sale = DB::table('journal_entries')->where('source_type', 'pos_order')->where('source_id', $orderId)->sole();
        DB::table('journal_entry_lines')->where('journal_entry_id', $sale->id)->update(['financial_location_id' => null]);

        $refundId = $this->postJson("/api/v1/orders/{$orderId}/refunds", ['type' => 'full', 'reason' => 'Historical sale', 'idempotencyKey' => 'historical-cash-refund'], $headers)
            ->assertCreated()->json('data.id');
        $entry = DB::table('journal_entries')->where('source_type', 'payment_refund')->where('source_id', $refundId)->sole();
        $this->assertSame(0, DB::table('journal_entry_lines')->where('journal_entry_id', $entry->id)->whereNotNull('financial_location_id')->count());
    }

    public function test_invalid_shift_drawer_rolls_back_cash_payment_and_inventory_consumption(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $orderId = $this->paidOrder($tenant, $headers, 1, 'cash', null, false);
        $order = DB::table('orders')->where('id', $orderId)->first();
        $originalDrawer = DB::table('shifts')->where('id', $order->shift_id)->value('financial_location_id');
        $otherBranchDrawer = DB::table('financial_locations')->where('tenant_id', $tenant)
            ->where('branch_id', '<>', $order->branch_id)->where('type', 'cash_drawer')->value('id');
        $this->assertNotNull($otherBranchDrawer);

        $bankAccount = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1030')->value('id');
        $originalAccount = DB::table('financial_locations')->where('id', $originalDrawer)->value('financial_account_id');
        foreach ([$otherBranchDrawer, null, $originalDrawer] as $badDrawer) {
            DB::table('shifts')->where('id', $order->shift_id)->update(['financial_location_id' => $badDrawer]);
            if ($badDrawer === $originalDrawer) {
                DB::table('financial_locations')->where('id', $originalDrawer)->update(['financial_account_id' => $bankAccount]);
            }
            $this->postJson("/api/v1/orders/{$orderId}/pay", [
                'method' => 'cash', 'amount' => $order->total, 'idempotencyKey' => 'invalid-drawer-'.($badDrawer ?? 'missing'),
            ], $headers)->assertUnprocessable();
            $this->assertSame(0, DB::table('payments')->where('order_id', $orderId)->count());
            $this->assertSame(0, DB::table('journal_entries')->where('source_type', 'pos_order')->where('source_id', $orderId)->count());
            $this->assertSame(0, DB::table('sale_consumptions')->where('order_id', $orderId)->count());
        }
        DB::table('shifts')->where('id', $order->shift_id)->update(['financial_location_id' => $originalDrawer]);
        DB::table('financial_locations')->where('id', $originalDrawer)->update(['financial_account_id' => $originalAccount]);
    }

    public function test_zero_balance_completion_has_no_cash_line_or_location(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $orderId = $this->paidOrder($tenant, $headers, 1, 'cash', null, false);
        $subtotal = DB::table('orders')->where('id', $orderId)->value('subtotal');
        DB::table('orders')->where('id', $orderId)->update(['discount_total' => $subtotal, 'tax_total' => 0, 'total' => 0]);

        $this->postJson("/api/v1/orders/{$orderId}/pay", ['amount' => 0, 'idempotencyKey' => 'zero-balance-no-drawer'], $headers)
            ->assertOk()->assertJsonPath('data.payment.method', 'zero_balance');
        $entry = DB::table('journal_entries')->where('source_type', 'pos_order')->where('source_id', $orderId)->sole();
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $entry->id)->get();
        $this->assertEquals($lines->sum('debit'), $lines->sum('credit'));
        $this->assertSame(0, $lines->whereNotNull('financial_location_id')->count());
        $cashAccount = DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $this->assertSame(0, $lines->where('financial_account_id', $cashAccount)->count());
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
        $drawer = DB::table('shifts')->where('id', DB::table('orders')->where('id', $orderId)->value('shift_id'))->value('financial_location_id');
        $cardSale = DB::table('journal_entries')->where('source_type', 'pos_order')->where('source_id', $orderId)->sole();
        $this->assertSame(0, DB::table('journal_entry_lines')->where('journal_entry_id', $cardSale->id)->whereNotNull('financial_location_id')->count());
        $this->assertEquals(0, $this->getJson('/api/v1/finance/cash-accounts/'.$drawer.'/transactions', $headers)->json('data.location.balance'));

        $refund = $this->postJson("/api/v1/orders/{$orderId}/refunds", ['type' => 'full', 'reason' => 'Wrong item', 'idempotencyKey' => 'refund-card-1'], $headers)
            ->assertCreated();

        $entry = DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'payment_refund')->where('source_id', $refund->json('data.id'))->first();
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $entry->id)->get();
        $this->assertSame(round($paidTotal, 2), round((float) $lines->firstWhere('financial_account_id', $bankAccountId)->credit, 2));
        $cashAccountId = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '1010')->value('id');
        $this->assertNull($lines->firstWhere('financial_account_id', $cashAccountId));
        $this->assertEquals(0, $this->getJson('/api/v1/finance/cash-accounts/'.$drawer.'/transactions', $headers)->json('data.location.balance'));
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

    public function test_refund_reverses_tax_from_the_order_snapshot_without_restocking_inventory(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        DB::table('tenants')->where('id', $tenant)->update(['tax_rate' => '0.100000']);
        $orderId = $this->paidCashOrder($tenant, $headers, quantity: 1);
        $order = DB::table('orders')->where('id', $orderId)->first();

        $refund = $this->postJson("/api/v1/orders/{$orderId}/refunds", ['type' => 'full', 'reason' => 'Tax snapshot refund', 'idempotencyKey' => 'refund-tax-snapshot'], $headers)->assertCreated();
        $entry = DB::table('journal_entries')->where('tenant_id', $tenant)->where('source_type', 'payment_refund')->where('source_id', $refund->json('data.id'))->sole();
        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $entry->id)->get();
        $salesReturns = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '4020')->value('id');
        $taxPayable = (int) DB::table('financial_accounts')->where('tenant_id', $tenant)->where('code', '2010')->value('id');

        $this->assertSame((float) $order->subtotal, (float) $lines->firstWhere('financial_account_id', $salesReturns)->debit);
        $this->assertSame((float) $order->tax_total, (float) $lines->firstWhere('financial_account_id', $taxPayable)->debit);
        $this->assertSame((float) $order->total, (float) $lines->sum('credit'));
    }

    public function test_refund_never_returns_inventory_and_original_payment_history_stays_immutable(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branchId = $this->downtownBranchId($tenant);

        $warehouseId = (int) DB::table('branches')->where('tenant_id', $tenant)->where('id', $branchId)->value('pos_inventory_warehouse_id');
        $itemId = (int) $this->postJson('/api/v1/inventory/items', [
            'nameAr' => 'مكون اختبار الاسترجاع', 'nameEn' => 'Refund Test Ingredient', 'sku' => 'REFUND-TEST-'.uniqid(),
            'itemType' => 'raw_material', 'unit' => 'kg', 'minimumStock' => '1.000', 'reorderLevel' => '1.000', 'latestUnitCost' => '2.0000', 'warehouseIds' => [$warehouseId], 'isActive' => true,
        ], $headers)->assertCreated()->json('data.id');
        $this->postJson('/api/v1/inventory/movements', ['warehouseId' => $warehouseId, 'itemId' => $itemId, 'type' => 'stock_in', 'quantity' => '10.000', 'unitCost' => '2.0000', 'reason' => 'Opening'], $headers)->assertCreated();

        $productId = (int) DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => 'Refund Test Product', 'price' => '10.00', 'cost_price' => 0, 'is_active' => true, 'is_stock_tracked' => true, 'inventory_controlled' => false, 'consumption_type' => 'bar', 'sort_order' => 0, 'created_at' => now(), 'updated_at' => now()]);
        $variant = ProductVariant::create(['tenant_id' => $tenant, 'product_id' => $productId, 'name' => 'Regular', 'base_price' => '10.00', 'is_default' => true, 'is_active' => true]);
        app(RecipeConfigurationService::class)->replaceRecipe($variant,
            [['materialId' => $itemId, 'quantity' => '2.000', 'unitCode' => 'kg']]);

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
        $this->assertSame('4.00', DB::table('orders')->where('id', $orderId)->value('cogs_total'));
        $this->assertSame(1, DB::table('sale_consumptions')->where('order_id', $orderId)->count());
    }

    private function paidCashOrder(int $tenant, array $headers, int $quantity): int
    {
        return $this->paidOrder($tenant, $headers, $quantity, 'cash', null);
    }

    private function paidOrder(int $tenant, array $headers, int $quantity, string $method, ?int $paymentMethodId, bool $pay = true): int
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
        if ($pay) {
            $this->postJson("/api/v1/orders/{$orderId}/pay", $payload, $headers)->assertOk();
        }

        return $orderId;
    }

    /**
     * Builds a payment fixture from canonical Menu recipes using the production snapshot builder.
     *
     * @param  list<int>  $productIds
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

        }

        $publicationId = DB::table('menu_publications')->insertGetId(['tenant_id' => $tenant, 'status' => 'published', 'published_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        $versionId = DB::table('published_menu_versions')->insertGetId([
            'tenant_id' => $tenant, 'menu_publication_id' => $publicationId, 'branch_id' => $branchId, 'channel' => 'pos',
            'version_number' => (int) DB::table('published_menu_versions')->where('tenant_id', $tenant)->where('branch_id', $branchId)->where('channel', 'pos')->max('version_number') + 1,
            'payload_json' => json_encode(app(PublishedMenuSnapshotBuilder::class)->build($tenant, Branch::findOrFail($branchId), 'pos', [$menuId])),
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
