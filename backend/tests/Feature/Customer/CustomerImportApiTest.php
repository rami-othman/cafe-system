<?php

namespace Tests\Feature\Customer;

use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CustomerImportApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_preview_and_commit_a_name_only_import_without_fabricating_a_phone(): void
    {
        $tenant = $this->tenant('import-owner');
        $token = $this->authenticateTenantUser($tenant, $this->user($tenant, 'owner'));
        $csv = "name;phone;mobile;group\nName Only;07;;Missing Group\nGood Customer;091234567;;\n";

        $preview = $this->withToken($token)->post('/api/v1/admin/customer-management/customer-imports/preview', [
            'file' => UploadedFile::fake()->createWithContent('customers.csv', $csv),
        ])->assertCreated();
        $preview->assertJsonPath('data.status', 'preview_ready')
            ->assertJsonPath('data.counts.total', 2)
            ->assertJsonPath('data.counts.ready', 2)
            ->assertJsonPath('data.counts.warnings', 1)
            ->assertJsonPath('data.groups.missing.0', 'Missing Group');

        $id = (int) $preview->json('data.id');
        $result = $this->withToken($token)->postJson('/api/v1/admin/customer-management/customer-imports/'.$id.'/commit', ['createMissingGroups' => false])->assertOk();
        $result->assertJsonPath('data.status', 'completed_with_errors')
            ->assertJsonPath('data.counts.createdCustomers', 2)
            ->assertJsonPath('data.counts.failedRows', 0);

        $this->assertDatabaseHas('customers', ['tenant_id' => $tenant, 'name' => 'Name Only', 'customer_number' => 'C-000001', 'phone' => null]);
        $this->assertDatabaseHas('customers', ['tenant_id' => $tenant, 'name' => 'Good Customer', 'customer_number' => 'C-000002', 'phone' => '091234567']);
        $this->assertDatabaseMissing('customer_groups', ['tenant_id' => $tenant, 'normalized_name' => 'missing group']);
        $this->assertSame(0, DB::table('customer_phones')->where('tenant_id', $tenant)->where('customer_id', DB::table('customers')->where('tenant_id', $tenant)->where('name', 'Name Only')->value('id'))->count());

        $report = $this->withToken($token)->get('/api/v1/admin/customer-management/customer-imports/'.$id.'/errors')->assertOk();
        $reportContent = $report->streamedContent();
        $this->assertStringStartsWith("\xEF\xBB\xBF", $reportContent);
        $this->assertStringContainsString('MISSING_GROUP_NOT_CREATED', $reportContent);
    }

    public function test_missing_group_is_created_once_and_strong_duplicates_are_skipped(): void
    {
        $tenant = $this->tenant('import-groups');
        $token = $this->authenticateTenantUser($tenant, $this->user($tenant, 'owner'));
        $existing = $this->withToken($token)->postJson('/api/v1/admin/customer-management/customers', ['name' => 'Existing', 'phones' => [['rawNumber' => '091234567', 'isPrimary' => true]]])->assertCreated();
        $csv = "name;phone;group\nExisting;091234567;New Group\nImported;099999999;New Group\n";

        $preview = $this->withToken($token)->post('/api/v1/admin/customer-management/customer-imports/preview', ['file' => UploadedFile::fake()->createWithContent('customers.csv', $csv)])->assertCreated();
        $id = (int) $preview->json('data.id');
        $this->withToken($token)->postJson('/api/v1/admin/customer-management/customer-imports/'.$id.'/commit', ['createMissingGroups' => true])->assertOk()->assertJsonPath('data.status', 'completed');

        $group = DB::table('customer_groups')->where('tenant_id', $tenant)->where('normalized_name', 'new group')->first();
        $this->assertNotNull($group);
        $this->assertSame(2, DB::table('customers')->where('tenant_id', $tenant)->count());
        $this->assertDatabaseHas('customer_import_rows', ['customer_import_id' => $id, 'status' => 'skipped_existing', 'matched_customer_id' => $existing->json('data.id')]);
        $this->assertDatabaseHas('customer_group_memberships', ['tenant_id' => $tenant, 'customer_group_id' => $group->id]);
    }

    public function test_only_owner_or_authorized_manager_can_use_import_and_tenant_isolation_is_enforced(): void
    {
        $tenant = $this->tenant('import-auth');
        $otherTenant = $this->tenant('import-other');
        $manager = $this->user($tenant, 'manager');
        $employee = $this->user($tenant, 'employee');
        DB::table('customer_role_permissions')->insert(['tenant_id' => $tenant, 'role' => 'manager', 'permission' => 'customer.manage', 'created_at' => now(), 'updated_at' => now()]);
        $managerToken = $this->authenticateTenantUser($tenant, $manager);
        $employeeToken = $this->authenticateTenantUser($tenant, $employee);
        $otherToken = $this->authenticateTenantUser($otherTenant, $this->user($otherTenant, 'owner'));
        $file = ['file' => UploadedFile::fake()->createWithContent('customers.csv', "name,phone\nCustomer,\n")];

        $preview = $this->withToken($managerToken)->post('/api/v1/admin/customer-management/customer-imports/preview', $file)->assertCreated();
        $id = (int) $preview->json('data.id');
        $this->withToken($employeeToken)->getJson('/api/v1/admin/customer-management/customer-imports/'.$id)->assertForbidden();
        $this->withToken($otherToken)->getJson('/api/v1/admin/customer-management/customer-imports/'.$id)->assertNotFound();
    }

    public function test_repeated_commit_is_idempotent_and_completed_fingerprint_is_rejected_for_a_new_import(): void
    {
        $tenant = $this->tenant('import-idempotency');
        $token = $this->authenticateTenantUser($tenant, $this->user($tenant, 'owner'));
        $csv = "name;phone\nRepeatable;099999999\n";

        $firstPreview = $this->withToken($token)->post('/api/v1/admin/customer-management/customer-imports/preview', [
            'file' => UploadedFile::fake()->createWithContent('customers.csv', $csv),
        ])->assertCreated();
        $firstId = (int) $firstPreview->json('data.id');

        $this->withToken($token)
            ->postJson('/api/v1/admin/customer-management/customer-imports/'.$firstId.'/commit', ['createMissingGroups' => false])
            ->assertOk()
            ->assertJsonPath('data.status', 'completed');
        $this->withToken($token)
            ->postJson('/api/v1/admin/customer-management/customer-imports/'.$firstId.'/commit', ['createMissingGroups' => true])
            ->assertOk()
            ->assertJsonPath('data.status', 'completed')
            ->assertJsonPath('data.counts.createdCustomers', 1);
        $this->assertSame(1, DB::table('customers')->where('tenant_id', $tenant)->where('name', 'Repeatable')->count());

        $secondPreview = $this->withToken($token)->post('/api/v1/admin/customer-management/customer-imports/preview', [
            'file' => UploadedFile::fake()->createWithContent('renamed.csv', $csv),
        ])->assertCreated();
        $secondId = (int) $secondPreview->json('data.id');
        $this->withToken($token)
            ->postJson('/api/v1/admin/customer-management/customer-imports/'.$secondId.'/commit', ['createMissingGroups' => false])
            ->assertStatus(409)
            ->assertJsonPath('code', 'CUSTOMER_IMPORT_ALREADY_COMPLETED')
            ->assertJsonPath('message', 'Customer import request could not be completed.');
    }

    private function tenant(string $name): int
    {
        return (int) DB::table('tenants')->insertGetId(['name' => $name, 'slug' => $name.'-'.uniqid(), 'created_at' => now(), 'updated_at' => now()]);
    }

    private function user(int $tenant, string $role): User
    {
        return User::query()->create(['tenant_id' => $tenant, 'name' => $role, 'email' => $role.'-'.uniqid().'@example.test', 'password' => 'password', 'role' => $role, 'is_active' => true, 'must_change_password' => false]);
    }
}
