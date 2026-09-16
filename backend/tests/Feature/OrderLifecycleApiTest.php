<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Branch;
use App\Services\BranchAccessService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class OrderLifecycleApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    public function test_authorized_unpaid_draft_and_held_orders_are_cancelled(): void
    {
        [$tenant, $branch] = $this->context();

        foreach (['draft', 'held'] as $status) {
            $order = $this->order($tenant, $branch, 'CANCEL-'.$status, $status);

            $this->json('DELETE', '/api/v1/orders/'.$order, [], $this->headers($tenant))
                ->assertNoContent();

            $cancelled = DB::table('orders')->where('id', $order)->first();
            $this->assertSame('cancelled', $cancelled->status);
            $this->assertSame('unpaid', $cancelled->payment_status);
            $this->assertNotNull($cancelled->closed_at);
            $this->assertNotNull($cancelled->deleted_at);
        }
    }

    public function test_paid_partially_refunded_refunded_and_terminal_orders_are_rejected_unchanged(): void
    {
        [$tenant, $branch] = $this->context();
        $cases = [
            ['paid', 'paid'],
            ['paid', 'partially_refunded'],
            ['refunded', 'refunded'],
            ['cancelled', 'unpaid'],
        ];

        foreach ($cases as [$status, $paymentStatus]) {
            $order = $this->order($tenant, $branch, 'REJECT-'.$status.'-'.$paymentStatus, $status, $paymentStatus);
            $before = DB::table('orders')->where('id', $order)->first();

            $this->json('DELETE', '/api/v1/orders/'.$order, [], $this->headers($tenant))
                ->assertUnprocessable();

            $after = DB::table('orders')->where('id', $order)->first();
            $this->assertSame($before->status, $after->status);
            $this->assertSame($before->payment_status, $after->payment_status);
            $this->assertNull($after->deleted_at);
            $this->assertNull($after->closed_at);
        }
    }

    public function test_completed_payment_blocks_cancellation_even_if_the_order_flag_is_stale(): void
    {
        [$tenant, $branch] = $this->context();
        $order = $this->order($tenant, $branch, 'STALE-PAYMENT-FLAG', 'draft', 'unpaid');
        DB::table('payments')->insert([
            'tenant_id' => $tenant,
            'branch_id' => $branch,
            'order_id' => $order,
            'method' => 'cash',
            'amount' => 5,
            'currency' => 'SYP',
            'status' => 'completed',
            'paid_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->json('DELETE', '/api/v1/orders/'.$order, [], $this->headers($tenant))
            ->assertUnprocessable();

        $this->assertSame('draft', DB::table('orders')->where('id', $order)->value('status'));
        $this->assertNull(DB::table('orders')->where('id', $order)->value('deleted_at'));
    }

    public function test_already_cancelled_or_deleted_order_cannot_generate_duplicate_effects(): void
    {
        [$tenant, $branch] = $this->context();
        $order = $this->order($tenant, $branch, 'REPEAT-CANCEL', 'draft');

        $this->json('DELETE', '/api/v1/orders/'.$order, [], $this->headers($tenant))
            ->assertNoContent();
        $cancelled = DB::table('orders')->where('id', $order)->first();

        $this->json('DELETE', '/api/v1/orders/'.$order, [], $this->headers($tenant))
            ->assertNotFound();

        $after = DB::table('orders')->where('id', $order)->first();
        $this->assertSame('cancelled', $after->status);
        $this->assertSame($cancelled->deleted_at, $after->deleted_at);
        $this->assertSame(0, DB::table('payments')->where('order_id', $order)->count());
        $this->assertSame(0, DB::table('sale_consumptions')->where('order_id', $order)->count());
        $this->assertSame(0, DB::table('journal_entries')->where('source_id', $order)->count());
    }

    public function test_foreign_tenant_order_cannot_be_cancelled(): void
    {
        [$tenant, $branch] = $this->context();
        $foreignTenant = (int) DB::table('tenants')->insertGetId([
            'name' => 'Foreign Lifecycle Tenant',
            'slug' => 'foreign-lifecycle-'.Str::lower(Str::random(10)),
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $foreignBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $foreignTenant,
            'name' => 'Foreign Lifecycle Branch',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $foreignOrder = $this->order($foreignTenant, $foreignBranch, 'FOREIGN-CANCEL', 'draft');

        $this->json('DELETE', '/api/v1/orders/'.$foreignOrder, [], $this->headers($tenant))
            ->assertNotFound();

        $this->assertSame('draft', DB::table('orders')->where('id', $foreignOrder)->value('status'));
        $this->assertNull(DB::table('orders')->where('id', $foreignOrder)->value('deleted_at'));
    }

    public function test_user_without_order_branch_access_cannot_cancel_order(): void
    {
        [$tenant, $branch] = $this->context();
        $restrictedBranch = (int) DB::table('branches')->insertGetId([
            'tenant_id' => $tenant,
            'name' => 'Restricted Lifecycle Branch',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $order = $this->order($tenant, $restrictedBranch, 'RESTRICTED-CANCEL', 'draft');
        $this->assertSame($restrictedBranch, (int) DB::table('orders')->where('id', $order)->value('branch_id'));
        $user = User::query()->create([
            'tenant_id' => $tenant,
            'name' => 'Restricted Lifecycle User',
            'email' => 'restricted-lifecycle-'.Str::uuid().'@example.test',
            'password' => 'testing-password',
            'role' => 'cashier',
            'is_active' => true,
            'must_change_password' => false,
        ]);
        $user->branches()->attach($branch, ['tenant_id' => $tenant]);
        $this->assertNotSame($branch, $restrictedBranch);
        $this->assertFalse($user->fresh()->branches()->whereKey($restrictedBranch)->exists());
        $this->assertFalse($user->fresh()->isOwner());
        $this->assertFalse(app(BranchAccessService::class)->canAccessBranch($user->fresh(), Branch::findOrFail($restrictedBranch)));
        $headers = [
            'Authorization' => 'Bearer '.$this->authenticateTenantUser($tenant, $user),
            'X-Tenant-Id' => (string) $tenant,
        ];

        $this->getJson('/api/v1/orders/'.$order, $headers)->assertForbidden();
        $this->json('DELETE', '/api/v1/orders/'.$order, [], $headers)->assertForbidden();

        $this->assertSame('draft', DB::table('orders')->where('id', $order)->value('status'));
        $this->assertNull(DB::table('orders')->where('id', $order)->value('deleted_at'));
    }

    public function test_cancellation_does_not_create_or_modify_payment_inventory_or_accounting_records(): void
    {
        [$tenant, $branch] = $this->context();
        $order = $this->order($tenant, $branch, 'NO-SIDE-EFFECTS', 'held');
        $payment = (int) DB::table('payments')->insertGetId([
            'tenant_id' => $tenant,
            'branch_id' => $branch,
            'order_id' => $order,
            'method' => 'cash',
            'amount' => 5,
            'currency' => 'SYP',
            'status' => 'pending',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $beforePayment = DB::table('payments')->where('id', $payment)->first();
        $beforeInventory = DB::table('sale_consumptions')->where('order_id', $order)->count();
        $beforeAccounting = DB::table('journal_entries')->where('source_id', $order)->count();

        $this->json('DELETE', '/api/v1/orders/'.$order, [], $this->headers($tenant))
            ->assertNoContent();

        $afterPayment = DB::table('payments')->where('id', $payment)->first();
        $this->assertSame($beforePayment->status, $afterPayment->status);
        $this->assertSame($beforePayment->amount, $afterPayment->amount);
        $this->assertSame($beforeInventory, DB::table('sale_consumptions')->where('order_id', $order)->count());
        $this->assertSame($beforeAccounting, DB::table('journal_entries')->where('source_id', $order)->count());
        $this->assertSame(1, DB::table('payments')->where('order_id', $order)->count());
    }

    public function test_unsupported_historical_snapshot_is_readable_but_not_resumable(): void
    {
        [$tenant, $branch] = $this->context();
        $now = now();
        $publication = DB::table('menu_publications')->insertGetId([
            'tenant_id' => $tenant,
            'status' => 'published',
            'published_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $version = DB::table('published_menu_versions')->insertGetId([
            'tenant_id' => $tenant,
            'menu_publication_id' => $publication,
            'branch_id' => $branch,
            'channel' => 'pos',
            'version_number' => (int) DB::table('published_menu_versions')
                ->where('tenant_id', $tenant)
                ->where('branch_id', $branch)
                ->where('channel', 'pos')
                ->max('version_number') + 1,
            'payload_json' => json_encode(['context' => ['schemaVersion' => 99], 'menus' => []]),
            'checksum' => str_repeat('a', 64),
            'status' => 'superseded',
            'published_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $order = $this->order($tenant, $branch, 'HISTORICAL-UNSUPPORTED', 'held');
        DB::table('orders')->where('id', $order)->update(['published_menu_version_id' => $version]);

        $this->getJson('/api/v1/orders/'.$order, $this->headers($tenant))
            ->assertOk()
            ->assertJsonPath('data.id', $order)
            ->assertJsonPath('data.canResume', false)
            ->assertJsonPath('data.resumeBlockerCode', 'UNSUPPORTED_MENU_SNAPSHOT_SCHEMA');
    }

    public function test_compatible_held_snapshot_remains_resumable(): void
    {
        [$tenant, $branch] = $this->context();
        $now = now();
        $publication = DB::table('menu_publications')->insertGetId([
            'tenant_id' => $tenant,
            'status' => 'published',
            'published_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $version = DB::table('published_menu_versions')->insertGetId([
            'tenant_id' => $tenant,
            'menu_publication_id' => $publication,
            'branch_id' => $branch,
            'channel' => 'pos',
            'version_number' => (int) DB::table('published_menu_versions')
                ->where('tenant_id', $tenant)
                ->where('branch_id', $branch)
                ->where('channel', 'pos')
                ->max('version_number') + 1,
            'payload_json' => json_encode(['context' => ['schemaVersion' => 3], 'menus' => []]),
            'checksum' => str_repeat('b', 64),
            'status' => 'superseded',
            'published_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $order = $this->order($tenant, $branch, 'HISTORICAL-COMPATIBLE', 'held');
        DB::table('orders')->where('id', $order)->update(['published_menu_version_id' => $version]);

        $this->getJson('/api/v1/orders/'.$order, $this->headers($tenant))
            ->assertOk()
            ->assertJsonPath('data.canResume', true)
            ->assertJsonPath('data.resumeBlockerCode', null);
    }

    private function context(): array
    {
        $tenant = (int) DB::table('tenants')->orderBy('id')->value('id');
        $branch = (int) DB::table('branches')
            ->where('tenant_id', $tenant)
            ->where('is_active', true)
            ->orderBy('id')
            ->value('id');

        return [$tenant, $branch];
    }

    private function headers(int $tenant): array
    {
        return ['X-Tenant-Id' => (string) $tenant];
    }

    private function order(
        int $tenant,
        int $branch,
        string $number,
        string $status,
        string $paymentStatus = 'unpaid',
    ): int {
        $time = now();

        return (int) DB::table('orders')->insertGetId([
            'tenant_id' => $tenant,
            'branch_id' => $branch,
            'order_number' => $number,
            'type' => 'takeaway',
            'status' => $status,
            'payment_status' => $paymentStatus,
            'total' => 5,
            'opened_at' => $time,
            'created_at' => $time,
            'updated_at' => $time,
        ]);
    }
}
