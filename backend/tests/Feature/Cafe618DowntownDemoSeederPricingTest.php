<?php

namespace Tests\Feature;

use App\Models\Menu;
use App\Services\Menu\MenuPricingQueryService;
use Database\Seeders\Cafe618DowntownDemoSeeder;
use Database\Seeders\FinancialInventoryFoundationSeeder;
use Database\Seeders\InventoryCenterSeeder;
use Database\Seeders\MenuCatalogSeeder;
use Database\Seeders\SuperAdminSeeder;
use Database\Seeders\TenantAccessSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class Cafe618DowntownDemoSeederPricingTest extends TestCase
{
    use RefreshDatabase;

    public function test_active_seeded_menu_is_listable_and_usable_by_pricing_without_an_enum_cast_failure(): void
    {
        $this->seedPricingPrerequisites();
        $this->seed(Cafe618DowntownDemoSeeder::class);

        $this->assertActiveMenuIsListableAndPriceable('Downtown Demo Menu');
    }

    private function seedPricingPrerequisites(): void
    {
        $this->seed(SuperAdminSeeder::class);
        $this->seed(TenantAccessSeeder::class);
        $this->seed(FinancialInventoryFoundationSeeder::class);
        $this->seed(MenuCatalogSeeder::class);
        $this->seed(InventoryCenterSeeder::class);
    }

    private function assertActiveMenuIsListableAndPriceable(string $name): void
    {
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->whereNull('deleted_at')->orderBy('id')->value('id');
        $menu = Menu::query()
            ->where('tenant_id', $tenantId)
            ->where('name', $name)
            ->firstOrFail();

        $this->assertSame('active', $menu->status->value);
        $this->assertTrue(
            Menu::query()->where('tenant_id', $tenantId)->get()->contains('id', $menu->id),
            'The seeded menu must be listable through the enum-cast model.'
        );

        $overview = app(MenuPricingQueryService::class)->overview($tenantId, $menu->id, [
            'branchId' => $branchId,
            'channel' => 'pos',
            'page' => 1,
            'perPage' => 25,
        ]);

        $this->assertSame($menu->id, $overview['context']['menuId']);
        $this->assertNotEmpty($overview['items'], 'The seeded menu must remain usable by pricing.');
    }
}
