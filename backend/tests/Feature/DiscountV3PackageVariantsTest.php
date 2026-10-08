<?php

namespace Tests\Feature;

use App\Exceptions\OrderLifecycleException;
use App\Services\DiscountEligibilityService;
use App\Services\DiscountResolutionService;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Concerns\DiscountEngineFixture;
use Tests\TestCase;

/** Discount System V3 Phase 1: variant-level Package / Bundle requirements. */
class DiscountV3PackageVariantsTest extends TestCase
{
    use DiscountEngineFixture;
    use RefreshDatabase;

    /** Product A (the fixture's first product) gets Large/Regular/Iced; its order line uses $line. */
    private function variants(array $f, ?string $line = 'regular'): array
    {
        $ids = [];
        foreach (['large' => 'Large', 'regular' => 'Regular', 'iced' => 'Iced'] as $key => $name) {
            $ids[$key] = DB::table('product_variants')->insertGetId(['tenant_id' => $f['tenant'], 'product_id' => $f['products'][0], 'name' => $name, 'is_active' => true]);
        }
        DB::table('order_items')->where('id', $f['items'][0])->update(['product_variant_id' => $line === null ? null : $ids[$line]]);

        return $ids;
    }

    private function package(array $f, array $requirement, array $changes = []): int
    {
        return $this->policy($f, array_replace(['name' => 'Package', 'applicationMode' => 'manual', 'scope' => 'bundle', 'value' => 50, 'bundleRequirements' => [$requirement, ['productId' => $f['products'][1], 'quantity' => 1]]], $changes));
    }

    private function detail(array $f, int $id): array
    {
        return $this->getJson("/api/v1/discounts/$id", $f['headers'])->assertOk()->json('data');
    }

    /** The management payload a client sends back after reading a package (no product-only selections). */
    private function editable(array $detail): array
    {
        unset($detail['productVariantSelections']);

        return $detail;
    }

    /** Eligible amount of the package for the fixture order, or null when it does not qualify. */
    private function amount(array $f, int $id): ?string
    {
        try {
            return app(DiscountEligibilityService::class)->assertApplicable($f['tenant'], DB::table('discounts')->find($id), DB::table('orders')->find($f['order']))['amount'];
        } catch (OrderLifecycleException $exception) {
            $this->assertSame('DISCOUNT_ITEMS_NOT_ELIGIBLE', $exception->domainCode);

            return null;
        }
    }

    public function test_legacy_requirements_without_variant_rows_mean_all_variants(): void
    {
        $f = $this->fixture();
        $v = $this->variants($f, 'regular');
        $id = $this->policy($f, ['applicationMode' => 'manual', 'scope' => 'bundle', 'value' => 50, 'bundleRequirements' => [['productId' => $f['products'][0], 'quantity' => 1], ['productId' => $f['products'][1], 'quantity' => 1]]]);
        $this->assertDatabaseCount('discount_bundle_requirement_variants', 0);
        $requirement = $this->detail($f, $id)['bundleRequirements'][0];
        $this->assertSame('all', $requirement['variantMode']);
        $this->assertSame([], $requirement['variantIds']);
        $this->assertSame([], $requirement['variants']);
        $this->assertSame('10.00', $this->amount($f, $id)); // 50% of 20: the Regular line qualifies.
        foreach ([$v['large'], null] as $variant) {
            DB::table('order_items')->where('id', $f['items'][0])->update(['product_variant_id' => $variant]);
            $this->assertSame('10.00', $this->amount($f, $id));
        }
    }

    public function test_explicit_all_variants_round_trips_and_clears_a_previous_selection(): void
    {
        $f = $this->fixture();
        $v = $this->variants($f, 'large');
        $id = $this->package($f, ['productId' => $f['products'][0], 'quantity' => 1, 'variantMode' => 'all', 'variantIds' => []]);
        $this->assertSame('all', $this->detail($f, $id)['bundleRequirements'][0]['variantMode']);
        $payload = $this->editable($this->detail($f, $id));
        $payload['bundleRequirements'][0] = ['productId' => $f['products'][0], 'quantity' => 1, 'variantMode' => 'selected', 'variantIds' => [$v['large']]];
        $this->putJson("/api/v1/discounts/$id", $payload, $f['headers'])->assertOk()->assertJsonPath('data.bundleRequirements.0.variantMode', 'selected');
        $payload['bundleRequirements'][0] = ['productId' => $f['products'][0], 'quantity' => 1, 'variantMode' => 'all', 'variantIds' => []];
        $this->putJson("/api/v1/discounts/$id", $payload, $f['headers'])->assertOk()->assertJsonPath('data.bundleRequirements.0.variantMode', 'all')->assertJsonPath('data.bundleRequirements.0.variantIds', []);
        $this->assertDatabaseCount('discount_bundle_requirement_variants', 0);
    }

    public function test_selected_single_and_multiple_variants_round_trip_through_create_edit_and_read(): void
    {
        $f = $this->fixture();
        $v = $this->variants($f);
        $id = $this->package($f, ['productId' => $f['products'][0], 'quantity' => 1, 'variantMode' => 'selected', 'variantIds' => [$v['large']]]);
        $created = $this->detail($f, $id);
        $this->assertSame('selected', $created['bundleRequirements'][0]['variantMode']);
        $this->assertSame([$v['large']], $created['bundleRequirements'][0]['variantIds']);
        $this->assertSame('Large', $created['bundleRequirements'][0]['variants'][0]['name']);
        $this->assertTrue($created['bundleRequirements'][0]['variants'][0]['isActive']);
        // The other requirement stays "all variants".
        $this->assertSame('all', $created['bundleRequirements'][1]['variantMode']);
        // Edit -> read keeps the selection, and the create response equals a fresh read.
        $payload = $this->editable($created);
        $payload['bundleRequirements'][0]['variantIds'] = [$v['iced'], $v['large']];
        $edited = $this->putJson("/api/v1/discounts/$id", $payload, $f['headers'])->assertOk()->json('data');
        $this->assertSame([$v['large'], $v['iced']], $edited['bundleRequirements'][0]['variantIds']);
        $this->assertSame($edited, $this->detail($f, $id));
        $this->assertDatabaseCount('discount_bundle_requirement_variants', 2);
    }

    public function test_legacy_client_edit_without_variant_fields_keeps_the_selected_variants(): void
    {
        $f = $this->fixture();
        $v = $this->variants($f);
        $id = $this->package($f, ['productId' => $f['products'][0], 'quantity' => 1, 'variantMode' => 'selected', 'variantIds' => [$v['large'], $v['iced']]]);
        $payload = $this->editable($this->detail($f, $id));
        $payload['name'] = 'Renamed by an older client';
        $payload['bundleRequirements'] = [['productId' => $f['products'][0], 'quantity' => 2], ['productId' => $f['products'][1], 'quantity' => 1]];
        $saved = $this->putJson("/api/v1/discounts/$id", $payload, $f['headers'])->assertOk()->json('data');
        $this->assertSame('Renamed by an older client', $saved['name']);
        $this->assertEquals(2, $saved['bundleRequirements'][0]['quantity']);
        $this->assertSame('selected', $saved['bundleRequirements'][0]['variantMode']);
        $this->assertSame([$v['large'], $v['iced']], $saved['bundleRequirements'][0]['variantIds']);
    }

    public function test_correct_variant_satisfies_and_wrong_variant_does_not(): void
    {
        $f = $this->fixture();
        $v = $this->variants($f, 'regular');
        $id = $this->package($f, ['productId' => $f['products'][0], 'quantity' => 1, 'variantMode' => 'selected', 'variantIds' => [$v['large']]]);
        $this->assertNull($this->amount($f, $id), 'Regular must not satisfy Large.');
        DB::table('order_items')->where('id', $f['items'][0])->update(['product_variant_id' => null]);
        $this->assertNull($this->amount($f, $id), 'A line without a variant must not satisfy a selected variant.');
        DB::table('order_items')->where('id', $f['items'][0])->update(['product_variant_id' => $v['large']]);
        $this->assertSame('10.00', $this->amount($f, $id));
        // Multiple selected variants: any of them satisfies the requirement.
        $multi = $this->package($f, ['productId' => $f['products'][0], 'quantity' => 1, 'variantMode' => 'selected', 'variantIds' => [$v['large'], $v['iced']]]);
        foreach (['large', 'iced'] as $key) {
            DB::table('order_items')->where('id', $f['items'][0])->update(['product_variant_id' => $v[$key]]);
            $this->assertSame('10.00', $this->amount($f, $multi));
        }
        DB::table('order_items')->where('id', $f['items'][0])->update(['product_variant_id' => $v['regular']]);
        $this->assertNull($this->amount($f, $multi));
    }

    public function test_the_resolution_engine_uses_the_same_variant_matching(): void
    {
        $f = $this->fixture();
        $v = $this->variants($f, 'regular');
        $id = $this->package($f, ['productId' => $f['products'][0], 'quantity' => 1, 'variantMode' => 'selected', 'variantIds' => [$v['large']]]);
        $intent = ['source' => 'configured_manual', 'discountId' => $id];
        try {
            $this->resolution($f, $intent);
            $this->fail('A Regular line must not satisfy a Large requirement in the engine.');
        } catch (OrderLifecycleException $exception) {
            $this->assertSame('DISCOUNT_ITEMS_NOT_ELIGIBLE', $exception->domainCode);
        }
        DB::table('order_items')->where('id', $f['items'][0])->update(['product_variant_id' => $v['large']]);
        $result = $this->resolution($f, $intent);
        $this->assertSame([$id], array_column($result['discounts'], 'discountId'));
        $this->assertSame('10.00', $result['totals']['discountTotal']);
        // Allocations land only on the lines that satisfy the package.
        $this->assertEqualsCanonicalizing($f['items'], array_column($result['discounts'][0]['allocations'], 'orderItemId'));
        // Persisted paid-order snapshots keep the variant refinement.
        DB::transaction(fn () => app(DiscountResolutionService::class)->persist($f['tenant'], DB::table('orders')->find($f['order']), $result));
        $snapshot = json_decode(DB::table('order_discounts')->where('order_id', $f['order'])->value('policy_snapshot'), true);
        $requirements = collect($snapshot['bundleRequirements']);
        $this->assertSame('selected', $requirements->firstWhere('productId', $f['products'][0])['variantMode']);
        $this->assertSame([$v['large']], $requirements->firstWhere('productId', $f['products'][0])['variantIds']);
        $this->assertSame('all', $requirements->firstWhere('productId', $f['products'][1])['variantMode']);
    }

    public function test_quantity_and_repeated_line_semantics_are_preserved_for_selected_variants(): void
    {
        $f = $this->fixture();
        $v = $this->variants($f, 'large');
        $id = $this->package($f, ['productId' => $f['products'][0], 'quantity' => 2, 'variantMode' => 'selected', 'variantIds' => [$v['large']]]);
        $this->assertNull($this->amount($f, $id), 'One Large does not satisfy a quantity of two.');
        // A Regular line of the same product cannot top the quantity up.
        $regular = DB::table('order_items')->insertGetId(['tenant_id' => $f['tenant'], 'order_id' => $f['order'], 'product_id' => $f['products'][0], 'product_variant_id' => $v['regular'], 'product_name' => 'Pinned', 'quantity' => 1, 'unit_price' => '10.00', 'total' => '10.00']);
        $this->assertNull($this->amount($f, $id));
        // A second Large line (repeated product lines) does.
        DB::table('order_items')->where('id', $regular)->update(['product_variant_id' => $v['large']]);
        DB::table('orders')->where('id', $f['order'])->update(['subtotal' => '30.00', 'total' => '30.00']);
        $this->assertSame('15.00', $this->amount($f, $id)); // 50% of (2 x 10 + 10); one package only.
        // A single line carrying quantity 3 still takes exactly the required 2.
        DB::table('order_items')->where('id', $regular)->delete();
        DB::table('order_items')->where('id', $f['items'][0])->update(['quantity' => 3, 'total' => '30.00']);
        DB::table('orders')->where('id', $f['order'])->update(['subtotal' => '40.00', 'total' => '40.00']);
        $this->assertSame('15.00', $this->amount($f, $id));
    }

    public function test_invalid_variant_selections_are_rejected_and_never_change_the_saved_policy(): void
    {
        $f = $this->fixture();
        $v = $this->variants($f);
        $foreignTenant = DB::table('tenants')->insertGetId(['name' => 'Foreign', 'slug' => uniqid('foreign-')]);
        $foreignProduct = DB::table('products')->insertGetId(['tenant_id' => $foreignTenant, 'name' => 'Foreign', 'price' => 1, 'is_active' => true]);
        $foreign = DB::table('product_variants')->insertGetId(['tenant_id' => $foreignTenant, 'product_id' => $foreignProduct, 'name' => 'Foreign variant', 'is_active' => true]);
        $otherProduct = DB::table('product_variants')->insertGetId(['tenant_id' => $f['tenant'], 'product_id' => $f['products'][1], 'name' => 'Other product variant', 'is_active' => true]);
        $inactive = DB::table('product_variants')->insertGetId(['tenant_id' => $f['tenant'], 'product_id' => $f['products'][0], 'name' => 'Inactive', 'is_active' => false]);
        $archived = DB::table('product_variants')->insertGetId(['tenant_id' => $f['tenant'], 'product_id' => $f['products'][0], 'name' => 'Archived', 'is_active' => true, 'deleted_at' => now()]);
        $id = $this->package($f, ['productId' => $f['products'][0], 'quantity' => 1, 'variantMode' => 'selected', 'variantIds' => [$v['large']]]);
        $before = $this->detail($f, $id);
        $product = $f['products'][0];
        $invalid = [
            'another product' => ['variantMode' => 'selected', 'variantIds' => [$otherProduct]],
            'cross tenant' => ['variantMode' => 'selected', 'variantIds' => [$foreign]],
            'inactive' => ['variantMode' => 'selected', 'variantIds' => [$inactive]],
            'archived' => ['variantMode' => 'selected', 'variantIds' => [$archived]],
            'unknown id' => ['variantMode' => 'selected', 'variantIds' => [999999]],
            'duplicate ids' => ['variantMode' => 'selected', 'variantIds' => [$v['large'], $v['large']]],
            'selected without ids' => ['variantMode' => 'selected', 'variantIds' => []],
            'selected with ids omitted' => ['variantMode' => 'selected'],
            'all with ids' => ['variantMode' => 'all', 'variantIds' => [$v['large']]],
            'ids without mode' => ['variantIds' => [$v['large']]],
            'unknown mode' => ['variantMode' => 'some', 'variantIds' => []],
            'non list ids' => ['variantMode' => 'selected', 'variantIds' => ['a' => $v['large']]],
            'non integer id' => ['variantMode' => 'selected', 'variantIds' => ['large']],
            'zero id' => ['variantMode' => 'selected', 'variantIds' => [0]],
        ];
        foreach ($invalid as $label => $extra) {
            $payload = $this->editable($before);
            $payload['bundleRequirements'][0] = ['productId' => $product, 'quantity' => 1] + $extra;
            $this->putJson("/api/v1/discounts/$id", $payload, $f['headers'])->assertUnprocessable();
            $this->assertSame($before, $this->detail($f, $id), "$label changed the saved policy");
            $this->postJson('/api/v1/discounts', $payload + ['name' => "Create $label"], $f['headers'])->assertUnprocessable();
        }
        $this->assertSame(1, DB::table('discounts')->where('tenant_id', $f['tenant'])->where('scope', 'bundle')->count());
    }

    public function test_storage_enforces_product_and_tenant_identity_and_cascades_with_the_requirement(): void
    {
        $f = $this->fixture();
        $v = $this->variants($f);
        $id = $this->package($f, ['productId' => $f['products'][0], 'quantity' => 1, 'variantMode' => 'selected', 'variantIds' => [$v['large']]]);
        $requirement = DB::table('discount_bundle_requirements')->where('discount_id', $id)->where('product_id', $f['products'][0])->first();
        $otherProduct = DB::table('product_variants')->insertGetId(['tenant_id' => $f['tenant'], 'product_id' => $f['products'][1], 'name' => 'Other', 'is_active' => true]);
        $row = ['tenant_id' => $f['tenant'], 'discount_id' => $id, 'product_id' => $f['products'][0], 'discount_bundle_requirement_id' => $requirement->id];
        foreach ([['product_variant_id' => $otherProduct], ['product_variant_id' => $v['large']]] as $bad) {
            try {
                DB::transaction(fn () => DB::table('discount_bundle_requirement_variants')->insert($row + $bad));
                $this->fail('The database must reject a wrong-product or duplicate variant row.');
            } catch (QueryException $exception) {
                $this->assertContains($exception->errorInfo[0], ['23503', '23505']);
            }
        }
        // A requirement of another tenant's discount cannot adopt this tenant's variant.
        try {
            DB::transaction(fn () => DB::table('discount_bundle_requirement_variants')->insert(['tenant_id' => $f['tenant'] + 1000, 'product_variant_id' => $v['iced']] + $row));
            $this->fail('The database must reject a cross-tenant row.');
        } catch (QueryException $exception) {
            $this->assertSame('23503', $exception->errorInfo[0]);
        }
        $this->deleteJson("/api/v1/discounts/$id", [], $f['headers'])->assertNoContent();
        $this->assertDatabaseCount('discount_bundle_requirement_variants', 0);
    }
}
