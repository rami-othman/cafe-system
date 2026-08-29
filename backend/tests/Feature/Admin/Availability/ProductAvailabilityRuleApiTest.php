<?php

namespace Tests\Feature\Admin\Availability;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ProductAvailabilityRuleApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_product_and_variant_rules_are_tenant_scoped_and_validate_references(): void
    {
        $tenantId = $this->tenant('alpha');
        [$productId, $variantId] = $this->product($tenantId, 'Latte');
        $branchId = $this->branch($tenantId);
        $this->putJson($this->rulesUrl($productId), ['rules' => [
            ['productVariantId' => null, 'branchId' => null, 'channel' => null, 'dayOfWeek' => 0, 'startTime' => '07:00', 'endTime' => '12:00'],
            ['productVariantId' => $variantId, 'branchId' => $branchId, 'channel' => 'delivery', 'startDate' => '2026-08-01', 'endDate' => '2026-08-31', 'priority' => 1],
        ]], $this->headers($tenantId))->assertOk()->assertJsonPath('data.productId', $productId)->assertJsonCount(2, 'data.rules');
        $this->getJson($this->rulesUrl($productId), $this->headers($tenantId))->assertOk()->assertJsonPath('data.rules.0.productVariantId', null);

        $otherTenantId = $this->tenant('beta');
        $this->getJson($this->rulesUrl($productId), $this->headers($otherTenantId))->assertNotFound();
        $this->putJson($this->rulesUrl($productId), ['rules' => []], $this->headers($otherTenantId))->assertNotFound();
        [, $foreignVariantId] = $this->product($otherTenantId, 'Foreign');
        $this->putJson($this->rulesUrl($productId), ['rules' => [[
            'productVariantId' => $foreignVariantId,
        ]]], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('rules.0.productVariantId');
        $this->putJson($this->rulesUrl($productId), ['rules' => [[
            'branchId' => $this->branch($otherTenantId),
        ]]], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('rules.0.branchId');
        DB::table('branches')->where('id', $branchId)->update(['deleted_at' => now()]);
        $this->putJson($this->rulesUrl($productId), ['rules' => [[
            'branchId' => $branchId,
        ]]], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('rules.0.branchId');
    }

    public function test_rule_validation_supports_all_scopes_and_rejects_invalid_schedule_shapes(): void
    {
        $tenantId = $this->tenant('alpha');
        [$productId, $variantId] = $this->product($tenantId, 'Tea');
        $branchId = $this->branch($tenantId);
        $this->putJson($this->rulesUrl($productId), ['rules' => [
            ['productVariantId' => null, 'dayOfWeek' => 0, 'startTime' => '22:00', 'endTime' => '02:00'],
            ['branchId' => $branchId],
            ['channel' => 'delivery'],
            ['branchId' => $branchId, 'channel' => 'delivery'],
            ['productVariantId' => $variantId, 'startDate' => '2026-08-01', 'endDate' => '2026-08-31'],
        ]], $this->headers($tenantId))->assertOk()->assertJsonCount(5, 'data.rules');
        $invalid = fn (array $rule, string $field) => $this->putJson($this->rulesUrl($productId), ['rules' => [$rule]], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors($field);
        $invalid(['dayOfWeek' => 7], 'rules.0.dayOfWeek');
        $invalid(['startTime' => '08:00'], 'rules.0.startTime');
        $invalid(['startTime' => '08:00', 'endTime' => '08:00'], 'rules.0.endTime');
        $invalid(['startDate' => '2026-08-02', 'endDate' => '2026-08-01'], 'rules.0.endDate');
        $invalid(['id' => 1], 'rules.0.id');
        $this->putJson($this->rulesUrl($productId), ['rules' => [
            ['branchId' => null, 'channel' => null],
            ['branchId' => null, 'channel' => null],
        ]], $this->headers($tenantId))->assertUnprocessable()->assertJsonValidationErrors('rules.1');
    }

    public function test_synchronization_updates_archives_restores_and_preserves_other_products(): void
    {
        $tenantId = $this->tenant('alpha');
        [$productId] = $this->product($tenantId, 'Mocha');
        [$otherProductId] = $this->product($tenantId, 'Espresso');
        $first = ['channel' => 'delivery', 'priority' => 0];
        $this->putJson($this->rulesUrl($productId), ['rules' => [$first]], $this->headers($tenantId))->assertOk();
        $ruleId = DB::table('product_availability_rules')->where('product_id', $productId)->value('id');
        $this->putJson($this->rulesUrl($otherProductId), ['rules' => [['channel' => 'delivery']]], $this->headers($tenantId))->assertOk();
        $this->putJson($this->rulesUrl($productId), ['rules' => [array_replace($first, ['priority' => 5])]], $this->headers($tenantId))->assertOk();
        $this->assertDatabaseHas('product_availability_rules', ['id' => $ruleId, 'priority' => 5, 'deleted_at' => null]);
        $this->putJson($this->rulesUrl($productId), ['rules' => [
            array_replace($first, ['priority' => 9]),
            ['branchId' => $this->branch($this->tenant('foreign'))],
        ]], $this->headers($tenantId))->assertUnprocessable();
        $this->assertDatabaseHas('product_availability_rules', ['id' => $ruleId, 'priority' => 5, 'deleted_at' => null]);

        $this->putJson($this->rulesUrl($productId), ['rules' => []], $this->headers($tenantId))->assertOk();
        $this->assertSoftDeleted('product_availability_rules', ['id' => $ruleId]);
        $this->assertDatabaseHas('product_availability_rules', ['product_id' => $otherProductId, 'deleted_at' => null]);
        $this->putJson($this->rulesUrl($productId), ['rules' => [$first]], $this->headers($tenantId))->assertOk();
        $this->assertDatabaseHas('product_availability_rules', ['id' => $ruleId, 'deleted_at' => null, 'priority' => 0]);
        $this->assertDatabaseHas('menu_audit_logs', ['tenant_id' => $tenantId, 'action' => 'synchronized', 'menu_publication_id' => null]);
    }

    public function test_preview_resolves_schedules_precedence_priority_and_overnight_windows(): void
    {
        $tenantId = $this->tenant('alpha');
        [$productId, $variantId] = $this->product($tenantId, 'Americano');
        $branchId = $this->branch($tenantId, 'Downtown', 'Asia/Damascus');
        $otherBranchId = $this->branch($tenantId, 'Airport', 'Asia/Damascus');
        $preview = fn (string $at, array $query = []) => $this->getJson($this->previewUrl($productId, ['dateTime' => $at] + $query), $this->headers($tenantId));
        $preview('2026-08-02T08:00:00', ['timezone' => 'UTC'])->assertOk()->assertJsonPath('data.isScheduledAvailable', true)->assertJsonPath('data.reason', 'no_schedule_restriction');

        $this->putJson($this->rulesUrl($productId), ['rules' => [
            ['dayOfWeek' => 0, 'startTime' => '07:00', 'endTime' => '12:00'],
        ]], $this->headers($tenantId))->assertOk();
        $preview('2026-08-02T08:00:00', ['timezone' => 'UTC'])->assertOk()->assertJsonPath('data.isScheduledAvailable', true)->assertJsonPath('data.matchedLevel', 'product');
        $preview('2026-08-02T13:00:00', ['timezone' => 'UTC'])->assertOk()->assertJsonPath('data.isScheduledAvailable', false)->assertJsonPath('data.reason', 'outside_schedule');

        $this->putJson($this->rulesUrl($productId), ['rules' => [
            ['startDate' => '2026-08-01', 'endDate' => '2026-08-31'],
            ['dayOfWeek' => 0, 'startTime' => '22:00', 'endTime' => '02:00', 'priority' => 1],
        ]], $this->headers($tenantId))->assertOk();
        $preview('2026-08-10T13:00:00', ['timezone' => 'UTC'])->assertOk()->assertJsonPath('data.isScheduledAvailable', true);
        $preview('2026-09-06T23:00:00', ['timezone' => 'UTC'])->assertOk()->assertJsonPath('data.isScheduledAvailable', true);
        $preview('2026-09-07T01:00:00', ['timezone' => 'UTC'])->assertOk()->assertJsonPath('data.isScheduledAvailable', true);

        $this->putJson($this->rulesUrl($productId), ['rules' => [
            ['startTime' => '00:00', 'endTime' => '23:59'],
            ['productVariantId' => $variantId, 'startTime' => '10:00', 'endTime' => '12:00'],
            ['branchId' => $branchId, 'startTime' => '08:00', 'endTime' => '09:00'],
            ['channel' => 'delivery', 'startTime' => '00:00', 'endTime' => '23:59'],
            ['branchId' => $branchId, 'channel' => 'delivery', 'startTime' => '14:00', 'endTime' => '15:00', 'priority' => 3],
            ['branchId' => $otherBranchId, 'startTime' => '00:00', 'endTime' => '23:59'],
        ]], $this->headers($tenantId))->assertOk();
        $preview('2026-08-02T13:00:00', ['productVariantId' => $variantId, 'timezone' => 'UTC'])->assertOk()->assertJsonPath('data.isScheduledAvailable', false)->assertJsonPath('data.matchedLevel', 'variant');
        $preview('2026-08-02T11:00:00', ['productVariantId' => $variantId, 'timezone' => 'UTC'])->assertOk()->assertJsonPath('data.isScheduledAvailable', true);
        $preview('2026-08-02T13:00:00', ['branchId' => $branchId, 'channel' => 'delivery'])->assertOk()->assertJsonPath('data.isScheduledAvailable', false)->assertJsonPath('data.matchedScope', 'branch_channel');
        $preview('2026-08-02T14:30:00', ['branchId' => $branchId, 'channel' => 'delivery'])->assertOk()->assertJsonPath('data.isScheduledAvailable', true)->assertJsonPath('data.matchedScope', 'branch_channel');
        $preview('2026-08-02T13:00:00', ['branchId' => $branchId, 'channel' => 'pos'])->assertOk()->assertJsonPath('data.isScheduledAvailable', false)->assertJsonPath('data.matchedScope', 'branch');

        $this->putJson($this->rulesUrl($productId), ['rules' => [
            ['channel' => 'delivery', 'startTime' => '00:00', 'endTime' => '23:58', 'priority' => 1],
            ['channel' => 'delivery', 'startTime' => '00:01', 'endTime' => '23:59', 'priority' => 5],
            ['branchId' => $otherBranchId, 'startTime' => '00:00', 'endTime' => '23:59'],
            ['branchId' => $branchId, 'isActive' => false],
        ]], $this->headers($tenantId))->assertOk();
        $rules = $this->getJson($this->rulesUrl($productId), $this->headers($tenantId))->json('data.rules');
        $highPriorityId = collect($rules)->first(fn (array $rule) => $rule['channel'] === 'delivery' && $rule['priority'] === 5)['id'];
        $preview('2026-08-02T13:00:00', ['channel' => 'delivery', 'timezone' => 'UTC'])->assertOk()->assertJsonPath('data.matchedRuleId', $highPriorityId);
        $preview('2026-08-02T13:00:00', ['branchId' => $branchId])->assertOk()->assertJsonPath('data.reason', 'no_schedule_restriction');
        $this->putJson($this->rulesUrl($productId), ['rules' => []], $this->headers($tenantId))->assertOk();
        $preview('2026-08-02T13:00:00', ['channel' => 'delivery', 'timezone' => 'UTC'])->assertOk()->assertJsonPath('data.reason', 'no_schedule_restriction');
    }

    private function rulesUrl(int $productId): string
    {
        return "/api/v1/admin/catalog/products/{$productId}/availability-rules";
    }

    private function previewUrl(int $productId, array $query): string
    {
        return "/api/v1/admin/catalog/products/{$productId}/availability-preview?".http_build_query($query);
    }

    private function tenant(string $slug): int
    {
        return DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function branch(int $tenantId, string $name = 'Downtown', string $timezone = 'UTC'): int
    {
        return DB::table('branches')->insertGetId(['tenant_id' => $tenantId, 'name' => $name, 'timezone' => $timezone, 'created_at' => now(), 'updated_at' => now()]);
    }

    private function product(int $tenantId, string $name): array
    {
        $productId = $this->postJson('/api/v1/admin/catalog/products', [
            'name' => $name,
            'variants' => [['name' => 'Regular', 'basePrice' => 4, 'isDefault' => true, 'isActive' => true]],
        ], $this->headers($tenantId))->assertCreated()->json('data.id');

        return [$productId, (int) DB::table('product_variants')->where('product_id', $productId)->value('id')];
    }

    private function headers(int $tenantId): array
    {
        return ['X-Tenant-Id' => (string) $tenantId];
    }
}
