<?php

namespace Tests\Feature;

use App\Services\CashBoxSyncService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** A cash box is just an account under group 13; creating the account creates the box. */
final class CashBoxFromChartTest extends TestCase
{
    use RefreshDatabase;

    private int $tenant;

    private int $group;

    private array $h;

    private function setUpTenant(): void
    {
        $this->seed();
        $this->tenant = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $owner = (int) DB::table('users')->where('tenant_id', $this->tenant)->where('role', 'owner')->value('id');
        DB::table('api_tokens')->insert([
            'tenant_id' => $this->tenant, 'user_id' => $owner, 'name' => 'box', 'token_hash' => hash('sha256', 'box-token'),
            'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->h = ['Authorization' => 'Bearer box-token', 'X-Tenant-Id' => $this->tenant];
        $this->group = (int) DB::table('financial_accounts')->insertGetId([
            'tenant_id' => $this->tenant, 'parent_account_id' => null, 'code' => '13', 'name_ar' => 'الأموال الجاهزة', 'name_en' => 'Ready funds',
            'account_group' => 'assets', 'normal_balance' => 'debit', 'is_active' => true, 'is_system_protected' => false,
            'catalog_source' => 'phinix', 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function create(string $name): array
    {
        return $this->postJson('/api/v1/finance/accounts', ['nameAr' => $name, 'nameEn' => $name, 'parentAccountId' => $this->group, 'isActive' => true], $this->h)
            ->assertCreated()->json('data');
    }

    public function test_creating_an_account_under_13_creates_its_box(): void
    {
        $this->setUpTenant();
        $cash = $this->create('صندوق الصيانة');
        $bank = $this->create('بنك سوريا');

        $box = DB::table('financial_locations')->where('tenant_id', $this->tenant)->where('financial_account_id', $cash['id'])->first();
        $this->assertNotNull($box);
        $this->assertSame(['cash', 'main_safe', null], [$box->kind, $box->type, $box->branch_id]);
        $this->assertSame('صندوق الصيانة', $box->name);
        $this->assertSame('bank', DB::table('financial_locations')->where('financial_account_id', $bank['id'])->value('kind'));

        // Renaming the account renames the box; an account elsewhere in the tree never becomes a box.
        $this->patchJson('/api/v1/finance/accounts/'.$cash['id'], ['nameAr' => 'صندوق الصيانة 2', 'nameEn' => 'x', 'code' => $cash['code'], 'parentAccountId' => $this->group,
            'accountGroup' => 'assets', 'normalBalance' => 'debit', 'isActive' => true], $this->h)->assertOk();
        $this->assertSame('صندوق الصيانة 2', DB::table('financial_locations')->where('id', $box->id)->value('name'));
        $other = $this->postJson('/api/v1/finance/accounts', ['nameAr' => 'مصروف', 'nameEn' => 'x', 'parentAccountId' => DB::table('financial_accounts')->where('tenant_id', $this->tenant)->where('code', '6100')->value('id'), 'isActive' => true], $this->h)->assertCreated()->json('data');
        $this->assertFalse(DB::table('financial_locations')->where('financial_account_id', $other['id'])->exists());
    }

    public function test_sync_registers_existing_accounts_and_linking_a_pos_makes_the_box_the_branch_drawer(): void
    {
        $this->setUpTenant();
        $id = (int) DB::table('financial_accounts')->insertGetId([
            'tenant_id' => $this->tenant, 'parent_account_id' => $this->group, 'code' => '139', 'name_ar' => 'صندوق TierFour', 'name_en' => 'x',
            'account_group' => 'assets', 'normal_balance' => 'debit', 'is_active' => true, 'is_system_protected' => false,
            'catalog_source' => 'phinix', 'created_at' => now(), 'updated_at' => now(),
        ]);
        $sync = app(CashBoxSyncService::class);
        $this->assertSame(1, $sync->syncTenant($this->tenant));
        $this->assertSame(0, $sync->syncTenant($this->tenant), 'idempotent');
        $locationId = (int) DB::table('financial_locations')->where('financial_account_id', $id)->value('id');
        $branch = (int) DB::table('branches')->where('tenant_id', $this->tenant)->orderBy('id')->value('id');

        $sync->adoptAsDrawer($this->tenant, $branch, $locationId);
        $loc = DB::table('financial_locations')->where('id', $locationId)->first();
        $this->assertSame(['cash_drawer', $branch], [$loc->type, (int) $loc->branch_id]);

        // Once it serves a branch it cannot be switched off.
        DB::table('branches')->where('id', $branch)->update(['pos_cash_financial_location_id' => $locationId]);
        $this->patchJson('/api/v1/finance/accounts/'.$id.'/status', ['isActive' => false], $this->h)->assertUnprocessable()->assertJsonValidationErrors('isActive');
    }
}
