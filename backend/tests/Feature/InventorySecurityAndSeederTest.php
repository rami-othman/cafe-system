<?php

namespace Tests\Feature;

use Database\Seeders\FinancialInventoryFoundationSeeder;
use Database\Seeders\InventorySeeder;
use Database\Seeders\SuperAdminSeeder;
use Database\Seeders\TenantAccessSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class InventorySecurityAndSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_required_inventory_seeders_complete_and_create_inventory_foundation(): void
    {
        $this->seed(SuperAdminSeeder::class);
        $this->seed(TenantAccessSeeder::class);
        $this->seed(FinancialInventoryFoundationSeeder::class);
        $this->seed(InventorySeeder::class);

        $tenant = $this->tenant('cafe-618');
        $this->assertGreaterThan(0, $tenant);
        $this->assertGreaterThan(0, DB::table('branches')->where('tenant_id', $tenant)->count());
        $this->assertGreaterThan(0, DB::table('warehouses')->where('tenant_id', $tenant)->count());
        $this->assertGreaterThan(0, DB::table('inventory_items')->where('tenant_id', $tenant)->count());
        $this->assertGreaterThan(0, DB::table('stock_balances')->where('tenant_id', $tenant)->count());
        $this->assertGreaterThan(0, DB::table('stock_counts')->where('tenant_id', $tenant)->count());
    }

    public function test_unauthenticated_inventory_reads_and_writes_are_rejected(): void
    {
        $this->call('GET', '/api/v1/inventory/transfers')->assertUnauthorized();
        $this->call('GET', '/api/v1/inventory/balances')->assertUnauthorized();
        $this->call('GET', '/api/v1/inventory/movements')->assertUnauthorized();
        $this->call('POST', '/api/v1/inventory/transfers')->assertUnauthorized();
    }

    public function test_token_tenant_cannot_be_changed_by_fake_tenant_or_user_headers(): void
    {
        $this->seed(TenantAccessSeeder::class);
        $tenantA = $this->tenant('cafe-618');
        $tenantB = $this->createTenant('inventory-security-b');
        $cashier = $this->createUser($tenantA, 'cashier');

        $this->getJson('/api/v1/inventory/items', $this->headers($tenantA, $cashier) + ['X-Tenant-Id' => $tenantB])
            ->assertOk()
            ->assertJsonPath('data.meta.total', 0);
        $this->postJson('/api/v1/inventory/items', $this->itemPayload(), $this->headers($tenantA, $cashier) + ['X-User-Id' => $this->owner($tenantA)])
            ->assertForbidden();
    }

    public function test_tenant_cannot_read_or_mutate_another_tenants_transfer_or_resources(): void
    {
        $this->seed(TenantAccessSeeder::class);
        $tenantA = $this->tenant('cafe-618');
        $tenantB = $this->createTenant('inventory-security-b');
        [$sourceB, $destinationB] = $this->warehouses($tenantB);
        $transferB = (int) DB::table('warehouse_transfers')->insertGetId([
            'tenant_id' => $tenantB,
            'source_warehouse_id' => $sourceB,
            'destination_warehouse_id' => $destinationB,
            'status' => 'draft',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $foreignItem = $this->createItem($tenantB);
        $ownWarehouse = $this->warehouses($tenantA)[0];

        $this->getJson("/api/v1/inventory/transfers/$transferB", $this->headers($tenantA, $this->owner($tenantA)))->assertNotFound();
        $this->postJson("/api/v1/inventory/transfers/$transferB/cancel", [], $this->headers($tenantA, $this->owner($tenantA)))->assertNotFound();
        $this->postJson('/api/v1/inventory/movements', ['warehouseId' => $ownWarehouse, 'itemId' => $foreignItem, 'type' => 'stock_in', 'quantity' => '1.000', 'unitCost' => '1.0000'], $this->headers($tenantA, $this->owner($tenantA)))->assertUnprocessable();
        $this->postJson('/api/v1/inventory/movements', ['warehouseId' => $sourceB, 'itemId' => $this->createItem($tenantA), 'type' => 'stock_in', 'quantity' => '1.000', 'unitCost' => '1.0000'], $this->headers($tenantA, $this->owner($tenantA)))->assertUnprocessable();
    }

    public function test_branch_limited_manager_cannot_access_or_transfer_other_branch_stock(): void
    {
        $this->seed(TenantAccessSeeder::class);
        $tenant = $this->tenant('cafe-618');
        [$source, $destination] = $this->warehouses($tenant);
        $manager = $this->createUser($tenant, 'manager');
        $item = $this->createItem($tenant);
        foreach ([$source, $destination] as $warehouse) {
            DB::table('inventory_item_warehouses')->insert(['tenant_id' => $tenant, 'warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'created_at' => now(), 'updated_at' => now()]);
        }

        $this->getJson('/api/v1/warehouses', $this->headers($tenant, $manager))
            ->assertOk()
            ->assertJsonCount(1, 'data');
        $this->postJson('/api/v1/inventory/transfers', ['sourceWarehouseId' => $source, 'destinationWarehouseId' => $destination, 'idempotencyKey' => 'security-manager-create', 'lines' => [['itemId' => $item, 'requestedQuantity' => '1.000', 'unit' => 'kilogram']]], $this->headers($tenant, $manager))
            ->assertForbidden();
    }

    public function test_transfer_action_permissions_are_independent_and_owner_can_create(): void
    {
        $this->seed(TenantAccessSeeder::class);
        $tenant = $this->tenant('cafe-618');
        [$source, $destination] = $this->warehouses($tenant);
        $owner = $this->owner($tenant);
        $cashier = $this->createUser($tenant, 'cashier');
        $item = $this->createItem($tenant);
        foreach ([$source, $destination] as $warehouse) {
            DB::table('inventory_item_warehouses')->insert(['tenant_id' => $tenant, 'warehouse_id' => $warehouse, 'inventory_item_id' => $item, 'created_at' => now(), 'updated_at' => now()]);
        }

        $this->postJson('/api/v1/inventory/transfers', ['sourceWarehouseId' => $source, 'destinationWarehouseId' => $destination, 'idempotencyKey' => 'security-owner-create', 'lines' => [['itemId' => $item, 'requestedQuantity' => '1.000', 'unit' => 'kilogram']]], $this->headers($tenant, $owner))->assertCreated();
        foreach (['approve', 'dispatch', 'receive'] as $action) {
            $this->postJson("/api/v1/inventory/transfers/999/$action", $action === 'receive' ? ['idempotencyKey' => 'receipt', 'lines' => [['itemId' => $item, 'receivedQuantity' => '1.000']]] : ['idempotencyKey' => 'dispatch'], $this->headers($tenant, $cashier))
                ->assertForbidden();
        }
    }

    private function headers(int $tenant, int $user): array
    {
        $plain = "inventory-security-$tenant-$user";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenant, 'user_id' => $user, 'name' => 'inventory-security-test'], ['token_hash' => hash('sha256', $plain), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $plain"];
    }

    private function tenant(string $slug): int { return (int) DB::table('tenants')->where('slug', $slug)->value('id'); }
    private function owner(int $tenant): int { return (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id'); }
    private function warehouses(int $tenant): array
    {
        $ids = DB::table('warehouses')->where('tenant_id', $tenant)->orderBy('id')->limit(2)->pluck('id')->map(fn ($id) => (int) $id)->all();
        if (count($ids) < 2) {
            $branch = (int) DB::table('branches')->where('tenant_id', $tenant)->value('id');
            DB::table('warehouses')->insert(['tenant_id' => $tenant, 'branch_id' => null, 'name' => 'Central', 'code' => "CENTRAL-$tenant", 'type' => 'central', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
            DB::table('warehouses')->insert(['tenant_id' => $tenant, 'branch_id' => $branch, 'name' => 'Store', 'code' => "STORE-$tenant", 'type' => 'branch_main', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
            $ids = DB::table('warehouses')->where('tenant_id', $tenant)->orderBy('id')->limit(2)->pluck('id')->map(fn ($id) => (int) $id)->all();
        }
        return $ids;
    }
    private function createTenant(string $slug): int
    {
        $tenant = (int) DB::table('tenants')->insertGetId(['name' => $slug, 'slug' => $slug, 'status' => 'active', 'plan' => 'starter', 'currency' => 'SYP', 'timezone' => 'Asia/Damascus', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['tenant_id' => $tenant, 'name' => 'Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        $this->createUser($tenant, 'owner');
        $this->warehouses($tenant);
        return $tenant;
    }
    private function createUser(int $tenant, string $role): int
    {
        return (int) DB::table('users')->insertGetId(['tenant_id' => $tenant, 'name' => ucfirst($role), 'email' => "$role-$tenant-".uniqid().'@example.test', 'password' => bcrypt('password'), 'role' => $role, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }
    private function createItem(int $tenant): int
    {
        return (int) DB::table('inventory_items')->insertGetId(['tenant_id' => $tenant, 'name' => 'Security item', 'name_ar' => 'Security item', 'name_en' => 'Security item', 'catalog_identity' => uniqid('security-', true), 'item_type' => 'raw_material', 'unit' => 'kilogram', 'minimum_stock' => 0, 'reorder_level' => 0, 'cost_per_unit' => 1, 'latest_unit_cost' => 1, 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
    }
    private function itemPayload(): array { return ['nameAr' => 'Security item', 'nameEn' => 'Security item', 'sku' => 'SECURITY-ITEM', 'itemType' => 'raw_material', 'unit' => 'kilogram', 'isActive' => true]; }
}
