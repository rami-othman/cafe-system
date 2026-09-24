<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Customer-reported regression: a closed shift's counted cash must actually
 * reach the main safe — not just flip the shift to "closed". This exercises
 * the full path a real cashier follows (POS cash sale -> shift close -> cash
 * custody transfer -> main safe ledger), through the same HTTP API the UI
 * uses for the drawer/safe balances, not direct DB assertions alone.
 */
final class CashSaleMainSafeTransferRegressionTest extends TestCase
{
    use RefreshDatabase;

    public function test_pos_cash_sale_then_shift_close_moves_exactly_the_counted_cash_minus_float_to_the_main_safe(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branch = $this->downtownBranchId($tenant);
        $safe = $this->mainSafeId($tenant);
        $drawer = $this->drawerId($branch);
        $this->configureClose($branch, $headers, $safe, '20.00');

        $shift = $this->openShift($tenant, $branch, $headers);
        $firstTotal = $this->cashSale($tenant, $branch, $shift, $headers, 4);
        $secondTotal = $this->cashSale($tenant, $branch, $shift, $headers, 3);
        $countedCash = round($firstTotal + $secondTotal, 2);
        $this->assertGreaterThan(20.00, $countedCash, 'Fixture must clear the configured float for this regression to be meaningful.');

        $drawerBefore = $this->locationBalance($drawer, $headers);
        $safeBefore = $this->locationBalance($safe, $headers);
        $this->assertSame($countedCash, $drawerBefore, 'Drawer ledger must equal the real cash sales before close.');

        $closed = $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => (string) $countedCash], $headers)->assertOk();
        $transferId = $closed->json('data.closeTransferId');
        $this->assertNotNull($transferId, 'A real cash sale that clears the float must produce a close transfer.');

        $expectedTransfer = round($countedCash - 20.00, 2);
        $transfer = DB::table('cash_transfers')->where('tenant_id', $tenant)->where('id', $transferId)->sole();
        $this->assertSame(1, DB::table('cash_transfers')->where('tenant_id', $tenant)->where('shift_id', $shift)->count(), 'Exactly one transfer must exist for this shift.');
        $this->assertSame($drawer, (int) $transfer->from_financial_location_id);
        $this->assertSame($safe, (int) $transfer->to_financial_location_id);
        $this->assertSame(number_format($expectedTransfer, 2, '.', ''), $transfer->amount);

        $drawerAfter = $this->locationBalance($drawer, $headers);
        $safeAfter = $this->locationBalance($safe, $headers);
        $this->assertSame(round($drawerBefore - $expectedTransfer, 2), $drawerAfter, 'Drawer ledger must decrease by exactly the transferred amount.');
        $this->assertSame(round($safeBefore + $expectedTransfer, 2), $safeAfter, 'Main safe ledger must increase by exactly the transferred amount.');

        // The same account/movements API the UI reads from must expose the transfer on both sides.
        $drawerTransactions = $this->getJson("/api/v1/finance/cash-accounts/{$drawer}/transactions", $headers)->assertOk()->json('data.transactions');
        $safeTransactions = $this->getJson("/api/v1/finance/cash-accounts/{$safe}/transactions", $headers)->assertOk()->json('data.transactions');
        $this->assertTrue($this->transactionsReferenceTransfer($drawerTransactions, $transfer), 'Drawer movements API must show the close transfer.');
        $this->assertTrue($this->transactionsReferenceTransfer($safeTransactions, $transfer), 'Main safe movements API must show the close transfer.');

        // The shift report the UI/history reads from must carry the same closeTransferId.
        $shiftNumber = DB::table('shifts')->where('id', $shift)->value('shift_number');
        $report = $this->getJson("/api/v1/shifts/{$shiftNumber}/report", $headers)->assertOk();
        $report->assertJsonPath('data.closeTransferId', $transferId);

        // Retry must not duplicate the transfer or move money twice.
        $retry = $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => (string) $countedCash], $headers)->assertOk();
        $this->assertSame($transferId, $retry->json('data.closeTransferId'));
        $this->assertSame(1, DB::table('cash_transfers')->where('tenant_id', $tenant)->where('shift_id', $shift)->count());
        $this->assertSame($drawerAfter, $this->locationBalance($drawer, $headers));
        $this->assertSame($safeAfter, $this->locationBalance($safe, $headers));
    }

    public function test_a_mismatched_close_leaves_the_shift_open_and_creates_no_transfer(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branch = $this->downtownBranchId($tenant);
        $safe = $this->mainSafeId($tenant);
        $this->configureClose($branch, $headers, $safe, '0.00');

        $shift = $this->openShift($tenant, $branch, $headers);
        $this->cashSale($tenant, $branch, $shift, $headers, 1);

        // Counted cash does not match the real drawer ledger (cashier miscounted / skimmed).
        $this->postJson("/api/v1/shifts/{$shift}/close", ['closingCash' => '999999.00'], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('closingCash');

        $this->assertSame('open', DB::table('shifts')->where('id', $shift)->value('status'), 'A failed transfer must never leave a falsely closed shift.');
        $this->assertSame(0, DB::table('cash_transfers')->where('tenant_id', $tenant)->where('shift_id', $shift)->count());
        $this->assertNull(DB::table('shifts')->where('id', $shift)->value('close_transfer_id'));
    }

    public function test_a_branch_without_a_valid_close_destination_cannot_open_a_new_shift(): void
    {
        $this->seed();
        $tenant = $this->demoTenantId();
        $headers = $this->headers($tenant);
        $branch = $this->downtownBranchId($tenant);
        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", ['shiftCloseDestinationFinancialLocationId' => null], $headers)->assertOk();

        $this->postJson('/api/v1/shifts/current', ['branchId' => $branch, 'openingCash' => 0], $headers)
            ->assertUnprocessable()->assertJsonValidationErrors('shiftCloseDestinationFinancialLocationId');
        $this->assertSame(0, DB::table('shifts')->where('tenant_id', $tenant)->where('branch_id', $branch)->count());
    }

    private function transactionsReferenceTransfer(array $transactions, object $transfer): bool
    {
        foreach ($transactions as $row) {
            if (($row['sourceType'] ?? null) === 'cash_transfer' && (int) ($row['journalEntryId'] ?? 0) === (int) $transfer->journal_entry_id) {
                return true;
            }
        }

        return false;
    }

    private function locationBalance(int $location, array $headers): float
    {
        return (float) $this->getJson("/api/v1/finance/cash-accounts/{$location}/transactions", $headers)
            ->assertOk()->json('data.location.balance');
    }

    private function cashSale(int $tenant, int $branch, int $shift, array $headers, int $quantity): float
    {
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
            'branchId' => $branch,
            'shiftId' => $shift,
            'orderType' => 'takeaway',
            'items' => [['productId' => $product->id, 'quantity' => $quantity, 'modifiers' => $modifiers]],
        ], $headers)->assertCreated();
        $orderId = $order->json('data.id');
        $total = (float) $order->json('data.totals.total');

        $this->postJson("/api/v1/orders/{$orderId}/pay", [
            'method' => 'cash', 'amount' => $total, 'idempotencyKey' => 'safe-transfer-regression-'.uniqid(),
        ], $headers)->assertOk();

        return $total;
    }

    private function configureClose(int $branch, array $headers, int $destination, string $float): void
    {
        $this->putJson("/api/v1/cafe-configuration/branches/{$branch}", [
            'shiftCloseDestinationFinancialLocationId' => $destination, 'shiftClosingFloatAmount' => $float,
        ], $headers)->assertOk();
    }

    private function openShift(int $tenant, int $branch, array $headers): int
    {
        return (int) $this->postJson('/api/v1/shifts/current', ['branchId' => $branch, 'openingCash' => 0], $headers)
            ->assertCreated()->json('data.id');
    }

    private function drawerId(int $branch): int
    {
        return (int) DB::table('branches')->where('id', $branch)->value('pos_cash_financial_location_id');
    }

    private function mainSafeId(int $tenant): int
    {
        return (int) DB::table('financial_locations')->where('tenant_id', $tenant)->where('code', 'MAIN-SAFE')->value('id');
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
        $plainToken = "safe-transfer-regression-test-$tenantId-$userId";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'safe-transfer-regression-test'], ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }
}
