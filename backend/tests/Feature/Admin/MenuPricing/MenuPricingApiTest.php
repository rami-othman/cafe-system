<?php

namespace Tests\Feature\Admin\MenuPricing;

use App\Models\User;
use App\Services\Menu\PublishedMenuSnapshotBuilder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class MenuPricingApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_manual_set_and_reset_apply_atomically_without_touching_shared_prices(): void
    {
        $s = $this->scope();
        DB::table('menu_variant_prices')->insert(['tenant_id' => $s['tenant'], 'menu_id' => $s['menu'], 'product_variant_id' => $s['second'], 'branch_id' => $s['branch'], 'channel' => 'pos', 'price' => '12.00', 'created_at' => now(), 'updated_at' => now()]);
        $preview = $this->postJson($this->previewUrl($s), ['branchId' => $s['branch'], 'channel' => 'pos', 'operation' => 'manual_changes', 'items' => [
            ['variantId' => $s['variant'], 'action' => 'set', 'price' => '13.00'], ['variantId' => $s['second'], 'action' => 'reset'],
        ]], $this->headers($s['tenant']))->assertCreated()->assertJsonPath('data.summary.overridesToCreateCount', 1)->assertJsonPath('data.summary.overridesToRemoveCount', 1);
        $id = $preview->json('data.id'); $fingerprint = $preview->json('data.fingerprint');
        $this->postJson($this->applyUrl($s, $id), ['previewFingerprint' => $fingerprint, 'confirmReviewedResults' => true], $this->headers($s['tenant']))->assertOk()->assertJsonPath('data.status', 'applied');
        $this->assertDatabaseHas('menu_variant_prices', ['tenant_id' => $s['tenant'], 'menu_id' => $s['menu'], 'product_variant_id' => $s['variant'], 'price' => '13.00']);
        $this->assertDatabaseMissing('menu_variant_prices', ['tenant_id' => $s['tenant'], 'menu_id' => $s['menu'], 'product_variant_id' => $s['second']]);
        $this->assertDatabaseHas('product_variants', ['id' => $s['variant'], 'base_price' => '10.00']);
        $this->assertDatabaseHas('products', ['id' => $s['product'], 'price' => '10.00']);
        $this->assertDatabaseHas('menu_price_adjustment_items', ['menu_price_adjustment_id' => $id, 'product_variant_id' => $s['second'], 'configuration_effect' => 'remove_override']);
    }

    public function test_bulk_scope_is_not_narrowed_by_overview_and_opposite_direction_requires_acknowledgement(): void
    {
        $s = $this->scope();
        DB::table('product_variants')->where('id', $s['variant'])->update(['base_price' => '12300.00']);
        DB::table('product_variants')->where('id', $s['second'])->update(['base_price' => '12400.00']);
        $this->getJson("/api/v1/admin/menus/{$s['menu']}/pricing?branchId={$s['branch']}&channel=pos&search=no-match", $this->headers($s['tenant']))->assertOk()->assertJsonCount(0, 'data.items');
        $preview = $this->postJson($this->previewUrl($s), ['branchId' => $s['branch'], 'channel' => 'pos', 'operation' => 'percentage_increase', 'amount' => '2', 'roundingMode' => 'round_down', 'roundingStep' => '1000.00'], $this->headers($s['tenant']))
            ->assertCreated()->assertJsonPath('data.summary.eligibleVariantCount', 2)->assertJsonPath('data.summary.oppositeDirectionCount', 2);
        $this->postJson($this->applyUrl($s, $preview->json('data.id')), ['previewFingerprint' => $preview->json('data.fingerprint'), 'confirmReviewedResults' => true], $this->headers($s['tenant']))
            ->assertStatus(422)->assertJsonPath('code', 'MENU_PRICING_OPPOSITE_DIRECTION_ACKNOWLEDGEMENT_REQUIRED');
        $this->postJson($this->applyUrl($s, $preview->json('data.id')), ['previewFingerprint' => $preview->json('data.fingerprint'), 'confirmReviewedResults' => true, 'acknowledgeOppositeDirection' => true], $this->headers($s['tenant']))->assertOk();
        $this->assertDatabaseCount('menu_variant_prices', 2);
    }

    public function test_menu_prices_are_isolated_and_snapshots_keep_each_menu_price(): void
    {
        $s = $this->scope();
        $other = DB::table('menus')->insertGetId(['tenant_id' => $s['tenant'], 'name' => 'Other', 'status' => 'draft', 'created_at' => now(), 'updated_at' => now()]);
        $section = DB::table('menu_sections')->insertGetId(['tenant_id' => $s['tenant'], 'menu_id' => $other, 'name' => 'Other section', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('menu_item_placements')->insert(['tenant_id' => $s['tenant'], 'menu_section_id' => $section, 'product_id' => $s['product'], 'is_visible' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('menu_variant_prices')->insert(['tenant_id' => $s['tenant'], 'menu_id' => $s['menu'], 'product_variant_id' => $s['variant'], 'branch_id' => $s['branch'], 'channel' => 'pos', 'price' => '11.00', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('menu_variant_prices')->insert(['tenant_id' => $s['tenant'], 'menu_id' => $other, 'product_variant_id' => $s['variant'], 'branch_id' => $s['branch'], 'channel' => 'pos', 'price' => '12.00', 'created_at' => now(), 'updated_at' => now()]);
        $payload = app(PublishedMenuSnapshotBuilder::class)->build($s['tenant'], \App\Models\Branch::findOrFail($s['branch']), 'pos', [$s['menu'], $other]);
        $this->assertSame('11.00', $payload['menus'][0]['sections'][0]['products'][0]['variants'][0]['effectivePrice']);
        $this->assertSame('12.00', $payload['menus'][1]['sections'][0]['products'][0]['variants'][0]['effectivePrice']);
    }

    public function test_employee_is_denied(): void
    {
        $s = $this->scope();
        $employee = User::query()->create(['tenant_id' => $s['tenant'], 'name' => 'Employee', 'email' => 'pricing-employee@example.test', 'password' => 'testing-password', 'role' => 'employee', 'is_active' => true, 'must_change_password' => false]);
        DB::table('user_branches')->insert(['tenant_id' => $s['tenant'], 'user_id' => $employee->id, 'branch_id' => $s['branch'], 'created_at' => now(), 'updated_at' => now()]);
        $headers = ['Authorization' => 'Bearer '.$this->authenticateTenantUser($s['tenant'], $employee)];
        $this->getJson("/api/v1/admin/menus/{$s['menu']}/pricing?branchId={$s['branch']}&channel=pos", $headers)->assertForbidden()->assertJsonPath('code', 'MENU_PRICING_FORBIDDEN');
    }

    public function test_source_change_makes_preview_stale_and_validation_has_a_stable_code(): void
    {
        $s = $this->scope();
        $this->postJson($this->previewUrl($s), ['branchId' => $s['branch'], 'channel' => 'pos', 'operation' => 'fixed_increase', 'amount' => '1', 'roundingMode' => 'no_rounding', 'items' => []], $this->headers($s['tenant']))
            ->assertUnprocessable()->assertJsonPath('code', 'MENU_PRICING_VALIDATION_FAILED');
        $preview = $this->postJson($this->previewUrl($s), ['branchId' => $s['branch'], 'channel' => 'pos', 'operation' => 'fixed_increase', 'amount' => '1', 'roundingMode' => 'no_rounding', 'roundingStep' => null], $this->headers($s['tenant']))->assertCreated();
        DB::table('product_variants')->where('id', $s['variant'])->update(['base_price' => '11.00', 'updated_at' => now()->addSecond()]);
        $this->postJson($this->applyUrl($s, $preview->json('data.id')), ['previewFingerprint' => $preview->json('data.fingerprint'), 'confirmReviewedResults' => true], $this->headers($s['tenant']))
            ->assertStatus(409)->assertJsonPath('code', 'MENU_PRICING_PREVIEW_STALE');
        $this->assertDatabaseCount('menu_variant_prices', 0);
    }

    public function test_apply_revalidates_archived_menu_and_inactive_or_archived_branch_without_writes(): void
    {
        $archivedMenu = $this->scope();
        $preview = $this->previewFixedIncrease($archivedMenu);
        DB::table('menus')->where('id', $archivedMenu['menu'])->update(['status' => 'archived', 'deleted_at' => now(), 'updated_at' => now()]);
        $this->applyPreview($archivedMenu, $preview)->assertStatus(409)->assertJsonPath('code', 'MENU_PRICING_CONTEXT_INVALID');
        $this->assertDatabaseMissing('menu_variant_prices', ['tenant_id' => $archivedMenu['tenant'], 'menu_id' => $archivedMenu['menu']]);

        $inactiveBranch = $this->scope();
        $preview = $this->previewFixedIncrease($inactiveBranch);
        DB::table('branches')->where('id', $inactiveBranch['branch'])->update(['is_active' => false, 'updated_at' => now()]);
        $this->applyPreview($inactiveBranch, $preview)->assertStatus(409)->assertJsonPath('code', 'MENU_PRICING_CONTEXT_INVALID');
        $this->assertDatabaseMissing('menu_variant_prices', ['tenant_id' => $inactiveBranch['tenant'], 'menu_id' => $inactiveBranch['menu']]);

        $archivedBranch = $this->scope();
        $preview = $this->previewFixedIncrease($archivedBranch);
        DB::table('branches')->where('id', $archivedBranch['branch'])->update(['is_active' => false, 'deleted_at' => now(), 'updated_at' => now()]);
        $this->applyPreview($archivedBranch, $preview)->assertStatus(409)->assertJsonPath('code', 'MENU_PRICING_CONTEXT_INVALID');
        $this->assertDatabaseMissing('menu_variant_prices', ['tenant_id' => $archivedBranch['tenant'], 'menu_id' => $archivedBranch['menu']]);
    }

    public function test_malformed_manual_items_are_rejected_as_menu_pricing_validation_errors_without_a_500(): void
    {
        $s = $this->scope();
        $base = ['branchId' => $s['branch'], 'channel' => 'pos', 'operation' => 'manual_changes'];
        foreach ([
            ['items' => 'invalid-array'],
            ['items' => [123]],
            ['items' => [['variantId' => $s['variant'], 'action' => 'set']]],
            ['items' => [['variantId' => $s['variant'], 'action' => 'set', 'price' => null]]],
            ['items' => [['variantId' => $s['variant'], 'action' => 'reset', 'price' => '1.00']]],
            ['items' => [['variantId' => $s['variant'], 'action' => 'set', 'price' => '11.00'], ['variantId' => $s['variant'], 'action' => 'reset']]],
            ['items' => [['variantId' => $s['variant'], 'action' => 'replace', 'price' => '11.00']]],
        ] as $invalid) {
            $this->postJson($this->previewUrl($s), $base + $invalid, $this->headers($s['tenant']))
                ->assertUnprocessable()->assertJsonPath('code', 'MENU_PRICING_VALIDATION_FAILED');
        }
    }

    public function test_rounding_steps_are_canonicalized_exactly_and_invalid_steps_are_rejected(): void
    {
        $s = $this->scope();
        $payload = ['branchId' => $s['branch'], 'channel' => 'pos', 'operation' => 'fixed_increase', 'amount' => str_repeat('0', 100).'1', 'roundingMode' => 'round_up', 'roundingStep' => str_repeat('0', 100).'0.05'];
        $this->postJson($this->previewUrl($s), $payload, $this->headers($s['tenant']))->assertCreated()
            ->assertJsonPath('data.amount', '1')->assertJsonPath('data.roundingStep', '0.05');
        $this->assertDatabaseHas('menu_price_adjustments', ['tenant_id' => $s['tenant'], 'amount' => '1', 'rounding_step' => '0.05']);

        foreach (['0', '-1', '0.001', '10000000000'] as $step) {
            $this->postJson($this->previewUrl($s), ['branchId' => $s['branch'], 'channel' => 'pos', 'operation' => 'fixed_increase', 'amount' => '1', 'roundingMode' => 'round_up', 'roundingStep' => $step], $this->headers($s['tenant']))->assertUnprocessable();
        }
    }

    public function test_overview_and_durable_adjustment_items_include_localized_identity_labels(): void
    {
        $s = $this->scope();
        DB::table('products')->where('id', $s['product'])->update(['name_ar' => 'قهوة', 'name_en' => 'Coffee EN']);
        DB::table('product_variants')->where('id', $s['variant'])->update(['name_ar' => 'عادي', 'name_en' => 'Regular EN']);
        $this->getJson("/api/v1/admin/menus/{$s['menu']}/pricing?branchId={$s['branch']}&channel=pos&search=قهوة", $this->headers($s['tenant']))
            ->assertOk()->assertJsonPath('data.items.0.productId', $s['product'])->assertJsonPath('data.items.0.productNameAr', 'قهوة')->assertJsonPath('data.items.0.productNameEn', 'Coffee EN')
            ->assertJsonPath('data.items.0.variantNameAr', 'عادي')->assertJsonPath('data.items.0.variantNameEn', 'Regular EN')->assertJsonPath('data.items.0.isDefault', true);
        $preview = $this->postJson($this->previewUrl($s), ['branchId' => $s['branch'], 'channel' => 'pos', 'operation' => 'manual_changes', 'items' => [['variantId' => $s['variant'], 'action' => 'set', 'price' => '11.00'], ['variantId' => $s['second'], 'action' => 'set', 'price' => '13.00']]], $this->headers($s['tenant']))
            ->assertCreated()->assertJsonPath('data.items.0.productNameAr', 'قهوة')->assertJsonPath('data.items.0.variantNameAr', 'عادي');
        DB::table('products')->where('id', $s['product'])->update(['name_ar' => 'اسم جديد']);
        $this->getJson("/api/v1/admin/menus/{$s['menu']}/pricing/adjustments/{$preview->json('data.id')}", $this->headers($s['tenant']))
            ->assertOk()->assertJsonPath('data.items.0.productNameAr', 'قهوة');
    }

    public function test_expired_preview_has_consistent_status_and_apply_rejection_without_price_writes(): void
    {
        $s = $this->scope();
        $preview = $this->previewFixedIncrease($s);
        DB::table('menu_price_adjustments')->where('id', $preview['id'])->update(['expires_at' => now()->subSecond()]);
        $this->getJson("/api/v1/admin/menus/{$s['menu']}/pricing/adjustments/{$preview['id']}", $this->headers($s['tenant']))->assertOk()->assertJsonPath('data.status', 'expired');
        $this->applyPreview($s, $preview)->assertStatus(409)->assertJsonPath('code', 'MENU_PRICING_PREVIEW_EXPIRED');
        $this->assertDatabaseCount('menu_variant_prices', 0);
    }

    public function test_applied_retry_returns_the_durable_result_without_duplicate_rows_even_after_context_changes(): void
    {
        $s = $this->scope();
        $preview = $this->previewFixedIncrease($s);
        $this->applyPreview($s, $preview)->assertOk()->assertJsonPath('data.status', 'applied');
        DB::table('branches')->where('id', $s['branch'])->update(['is_active' => false]);
        $this->applyPreview($s, $preview)->assertOk()->assertJsonPath('data.status', 'applied');
        $this->assertDatabaseCount('menu_variant_prices', 2);
        $this->assertDatabaseCount('menu_price_adjustments', 1);
    }

    public function test_reset_preview_detects_inherited_source_change_and_rolls_back_the_whole_mixed_batch(): void
    {
        $s = $this->scope();
        DB::table('menu_variant_prices')->insert(['tenant_id' => $s['tenant'], 'menu_id' => $s['menu'], 'product_variant_id' => $s['second'], 'branch_id' => $s['branch'], 'channel' => 'pos', 'price' => '13.00', 'created_at' => now(), 'updated_at' => now()]);
        $preview = $this->postJson($this->previewUrl($s), ['branchId' => $s['branch'], 'channel' => 'pos', 'operation' => 'manual_changes', 'items' => [
            ['variantId' => $s['variant'], 'action' => 'set', 'price' => '11.00'], ['variantId' => $s['second'], 'action' => 'reset'],
        ]], $this->headers($s['tenant']))->assertCreated();
        DB::table('product_variants')->where('id', $s['second'])->update(['base_price' => '14.00', 'updated_at' => now()->addSecond()]);
        $this->postJson($this->applyUrl($s, $preview->json('data.id')), ['previewFingerprint' => $preview->json('data.fingerprint'), 'confirmReviewedResults' => true], $this->headers($s['tenant']))
            ->assertStatus(409)->assertJsonPath('code', 'MENU_PRICING_PREVIEW_STALE');
        $this->assertDatabaseMissing('menu_variant_prices', ['tenant_id' => $s['tenant'], 'product_variant_id' => $s['variant']]);
        $this->assertDatabaseHas('menu_variant_prices', ['tenant_id' => $s['tenant'], 'product_variant_id' => $s['second'], 'price' => '13.00']);
    }

    public function test_bulk_creates_unchanged_inherited_overrides_and_rejects_rounding_to_zero_as_one_batch(): void
    {
        $s = $this->scope();
        $unchanged = $this->postJson($this->previewUrl($s), ['branchId' => $s['branch'], 'channel' => 'pos', 'operation' => 'fixed_increase', 'amount' => '0.01', 'roundingMode' => 'round_down', 'roundingStep' => '1'], $this->headers($s['tenant']))
            ->assertCreated()->assertJsonPath('data.summary.overridesToCreateCount', 2)->assertJsonPath('data.summary.unchangedPriceCount', 2);
        $this->postJson($this->applyUrl($s, $unchanged->json('data.id')), ['previewFingerprint' => $unchanged->json('data.fingerprint'), 'confirmReviewedResults' => true], $this->headers($s['tenant']))->assertOk();
        $this->assertDatabaseCount('menu_variant_prices', 2);

        $zero = $this->scope();
        DB::table('product_variants')->where('id', $zero['variant'])->update(['base_price' => '0.01']);
        DB::table('product_variants')->where('id', $zero['second'])->update(['base_price' => '0.01']);
        $this->postJson($this->previewUrl($zero), ['branchId' => $zero['branch'], 'channel' => 'pos', 'operation' => 'fixed_decrease', 'amount' => '0.005', 'roundingMode' => 'round_down', 'roundingStep' => '0.05'], $this->headers($zero['tenant']))
            ->assertUnprocessable()->assertJsonPath('code', 'MENU_PRICING_FINAL_RESULT_INVALID');
        $this->assertDatabaseMissing('menu_variant_prices', ['tenant_id' => $zero['tenant']]);
    }

    private function scope(): array
    {
        $tenant = DB::table('tenants')->insertGetId(['name' => 'Pricing', 'slug' => 'pricing-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
        $branch = DB::table('branches')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'currency' => 'SYP', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $product = DB::table('products')->insertGetId(['tenant_id' => $tenant, 'name' => 'Coffee', 'price' => '10.00', 'is_active' => true, 'product_type' => 'standard', 'created_at' => now(), 'updated_at' => now()]);
        $variant = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Regular', 'base_price' => '10.00', 'is_default' => true, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $second = DB::table('product_variants')->insertGetId(['tenant_id' => $tenant, 'product_id' => $product, 'name' => 'Large', 'base_price' => '12.00', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $menu = DB::table('menus')->insertGetId(['tenant_id' => $tenant, 'name' => 'Main', 'status' => 'draft', 'created_at' => now(), 'updated_at' => now()]);
        $section = DB::table('menu_sections')->insertGetId(['tenant_id' => $tenant, 'menu_id' => $menu, 'name' => 'Coffee', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('menu_item_placements')->insert(['tenant_id' => $tenant, 'menu_section_id' => $section, 'product_id' => $product, 'is_visible' => true, 'created_at' => now(), 'updated_at' => now()]);
        return compact('tenant', 'branch', 'menu', 'product', 'variant', 'second');
    }

    private function previewUrl(array $s): string { return "/api/v1/admin/menus/{$s['menu']}/pricing/adjustments/preview"; }
    private function applyUrl(array $s, int $id): string { return "/api/v1/admin/menus/{$s['menu']}/pricing/adjustments/$id/apply"; }
    private function headers(int $tenant): array { return ['X-Tenant-Id' => (string) $tenant]; }
    private function previewFixedIncrease(array $s): array
    {
        $response = $this->postJson($this->previewUrl($s), ['branchId' => $s['branch'], 'channel' => 'pos', 'operation' => 'fixed_increase', 'amount' => '1', 'roundingMode' => 'no_rounding', 'roundingStep' => null], $this->headers($s['tenant']))->assertCreated();
        return ['id' => $response->json('data.id'), 'fingerprint' => $response->json('data.fingerprint')];
    }
    private function applyPreview(array $s, array $preview)
    {
        return $this->postJson($this->applyUrl($s, $preview['id']), ['previewFingerprint' => $preview['fingerprint'], 'confirmReviewedResults' => true], $this->headers($s['tenant']));
    }
}
