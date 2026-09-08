<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class DailyReportApiTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Previously this test depended on the legacy PosDemoSeeder, which
     * DatabaseSeeder no longer runs (superseded by the Cafe618* seeders — see
     * DatabaseSeeder's own comment on that exclusion). Rather than re-couple
     * this test to whatever narrative a particular demo seeder happens to
     * produce on a given report date, it builds one deterministic order,
     * discount and refund itself through the real POS/payment/refund APIs and
     * asserts the daily report reflects exactly that — the same "current real
     * seeded behavior" the report actually needs to prove, without depending
     * on incidental seeder output.
     */
    public function test_daily_report_uses_real_pos_activity_for_the_report_date(): void
    {
        Carbon::setTestNow('2030-06-15 12:00:00');
        try {
            $this->seed();
            $tenantId = $this->demoTenantId();
            $headers = $this->headers($tenantId);
            $branchId = $this->downtownBranchId($tenantId);

            $product = DB::table('products')->where('tenant_id', $tenantId)->where('name', 'Cappuccino')->first();
            $snapshot = $this->publishedSnapshot($tenantId, $branchId, $product->id);

            $shiftId = $this->postJson('/api/v1/shifts/current', ['branchId' => $branchId, 'openingCash' => 0], $headers)
                ->assertCreated()->json('data.id');

            $order = $this->postJson('/api/v1/orders', [
                'branchId' => $branchId,
                'shiftId' => $shiftId,
                'orderType' => 'takeaway',
                'publishedMenuVersionId' => $snapshot['versionId'],
                'items' => [[
                    'productId' => $product->id,
                    'placementId' => $snapshot['placementId'],
                    'variantId' => $snapshot['variantId'],
                    'quantity' => 1,
                ]],
            ], $headers)->assertCreated();
            $orderId = $order->json('data.id');

            $this->putJson("/api/v1/orders/{$orderId}/discount", [
                'type' => 'percentage',
                'value' => '10',
                'reason' => 'Student Discount',
            ], $headers)->assertOk();

            $total = $this->getJson("/api/v1/orders/{$orderId}", $headers)->json('data.totals.total');

            $this->postJson("/api/v1/orders/{$orderId}/pay", [
                'method' => 'card',
                'amount' => $total,
                'idempotencyKey' => 'daily-report-payment-1',
            ], $headers)->assertOk()->assertJsonPath('data.payment.status', 'completed');

            $this->postJson("/api/v1/orders/{$orderId}/refunds", [
                'type' => 'full',
                'reason' => 'Customer Request',
                'idempotencyKey' => 'daily-report-refund-1',
            ], $headers)->assertCreated();

            $response = $this->getJson(
                '/api/v1/reports/daily?branchId='.$branchId.'&date='.now()->toDateString(),
                $headers,
            );

            $response->assertOk()
                ->assertJsonPath('data.hasData', true)
                ->assertJsonPath('data.branch.id', $branchId)
                ->assertJsonPath('data.kpis.totalOrders', 1)
                ->assertJsonPath('data.refunds.0.reason', 'Customer Request')
                ->assertJsonPath('data.discounts.0.name', 'Student Discount')
                ->assertJsonPath('data.transactions.0.payment', 'card');

            $this->assertCount(24, $response->json('data.hourlySales'));
            $this->assertCount(1, array_filter(
                $response->json('data.hourlySales'),
                fn (array $point) => $point['isPeak'],
            ));
        } finally {
            Carbon::setTestNow();
        }
    }

    /** @return array{versionId:int,placementId:int,variantId:int} */
    private function publishedSnapshot(int $tenant, int $branchId, int $productId): array
    {
        $now = now();
        $product = DB::table('products')->where('tenant_id', $tenant)->where('id', $productId)->firstOrFail();
        $variant = DB::table('product_variants')->where('tenant_id', $tenant)->where('product_id', $productId)->where('is_active', true)->orderByDesc('is_default')->orderBy('id')->firstOrFail();

        DB::table('published_menu_versions')
            ->where('tenant_id', $tenant)->where('branch_id', $branchId)->where('channel', 'pos')->where('status', 'current')
            ->update(['status' => 'superseded', 'updated_at' => $now]);

        $menuId = DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => 'Daily report test menu', 'status' => 'published', 'created_at' => $now, 'updated_at' => $now]);
        $sectionId = DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menuId, 'name' => 'Coffee', 'is_active' => true, 'created_at' => $now, 'updated_at' => $now]);
        $placementId = DB::table('menu_item_placements')->insertGetId(['tenant_id' => $tenant, 'menu_section_id' => $sectionId, 'product_id' => $productId, 'is_visible' => true, 'sort_order' => 0, 'created_at' => $now, 'updated_at' => $now]);
        $products = [['placementId' => $placementId, 'productId' => $productId, 'name' => ['default' => $product->name], 'isVisible' => true,
            'productAvailabilityRules' => [], 'variants' => [['id' => $variant->id, 'name' => ['default' => $variant->name], 'effectivePrice' => (string) $product->price, 'baseRecipe' => [], 'modifierRecipeAdjustments' => []]], 'modifierGroups' => []]];

        $publicationId = DB::table('menu_publications')->insertGetId(['tenant_id' => $tenant, 'status' => 'published', 'published_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
        $versionId = DB::table('published_menu_versions')->insertGetId([
            'tenant_id' => $tenant, 'menu_publication_id' => $publicationId, 'branch_id' => $branchId, 'channel' => 'pos',
            'version_number' => (int) DB::table('published_menu_versions')->where('tenant_id', $tenant)->where('branch_id', $branchId)->where('channel', 'pos')->max('version_number') + 1,
            'payload_json' => json_encode(['context' => ['schemaVersion' => 3], 'menus' => [['id' => $menuId, 'availabilityRules' => [], 'sections' => [['id' => $sectionId, 'products' => $products]]]]]),
            'checksum' => hash('sha256', uniqid('daily-report-', true)), 'status' => 'current', 'published_at' => $now, 'created_at' => $now, 'updated_at' => $now,
        ]);

        return ['versionId' => $versionId, 'placementId' => $placementId, 'variantId' => (int) $variant->id];
    }

    private function demoTenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
    }

    private function downtownBranchId(int $tenantId): int
    {
        return (int) DB::table('branches')->where('tenant_id', $tenantId)->where('name', 'Downtown')->value('id');
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        $plainToken = 'daily-report-test-token';
        DB::table('api_tokens')->updateOrInsert(
            ['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'daily-report-test'],
            ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()],
        );

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }
}
