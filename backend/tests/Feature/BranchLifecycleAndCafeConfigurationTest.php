<?php

namespace Tests\Feature;

use App\Models\Branch;
use App\Models\Tenant;
use App\Models\User;
use App\Services\BranchAccessService;
use App\Services\FinancialSetupService;
use App\Services\UserBranchAssignmentService;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class BranchLifecycleAndCafeConfigurationTest extends TestCase
{
    use RefreshDatabase;

    public function test_inactive_branches_stop_operational_access_without_removing_assignments_or_history(): void
    {
        [$tenant, $branch, $owner] = $this->tenantBranchUser('lifecycle', 'owner');
        $manager = $this->user($tenant, 'manager');
        $employee = $this->user($tenant, 'cashier');
        $assignments = app(UserBranchAssignmentService::class);
        $assignments->assign($manager, $branch);
        $assignments->assign($employee, $branch);
        $access = app(BranchAccessService::class);
        $foreignTenant = Tenant::query()->create([
            'name' => 'Foreign lifecycle tenant',
            'slug' => 'foreign-lifecycle-'.uniqid(),
            'status' => 'active',
        ]);
        $foreignBranch = Branch::query()->create([
            'tenant_id' => $foreignTenant->id,
            'name' => 'Foreign branch',
            'timezone' => 'UTC',
            'currency' => 'SYP',
            'is_active' => true,
        ]);
        $deletedBranch = Branch::query()->create([
            'tenant_id' => $tenant->id,
            'name' => 'Deleted branch',
            'timezone' => 'UTC',
            'currency' => 'SYP',
            'is_active' => true,
        ]);
        $deletedBranch->delete();
        $now = now();
        $orderId = DB::table('orders')->insertGetId([
            'tenant_id' => $tenant->id,
            'branch_id' => $branch->id,
            'order_number' => 'HISTORICAL-'.uniqid(),
            'type' => 'takeaway',
            'status' => 'paid',
            'payment_status' => 'paid',
            'subtotal' => 10,
            'tax_total' => 0,
            'total' => 10,
            'opened_at' => $now,
            'closed_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $this->assertTrue($access->canAccessBranch($owner, $branch));
        $this->assertTrue($access->canAccessBranch($manager, $branch));
        $this->assertFalse($access->canAccessBranch($owner, $foreignBranch));
        $this->assertFalse($access->canAccessBranch($owner, $deletedBranch));
        $branch->update(['is_active' => false]);

        $this->assertDatabaseHas('user_branches', ['user_id' => $employee->id, 'branch_id' => $branch->id]);
        $this->assertDatabaseHas('orders', ['id' => $orderId, 'branch_id' => $branch->id]);
        $this->assertFalse($access->canAccessBranch($owner, $branch->fresh()));
        $this->assertFalse($access->canAccessBranch($manager, $branch->fresh()));
        $this->assertSame([], $access->accessibleBranchIds($employee));

        $ownerToken = $this->authenticateTenantUser($tenant->id, $owner);
        $employeeToken = $this->authenticateTenantUser($tenant->id, $employee);
        $this->withToken($ownerToken)->getJson('/api/v1/branches')->assertOk()->assertJsonCount(0, 'data');
        $this->withToken($employeeToken)->getJson('/api/v1/branches')->assertOk()->assertJsonCount(0, 'data');
        $this->withToken($ownerToken)->getJson("/api/v1/pos/state?branchId={$branch->id}")->assertNotFound();
        $this->withToken($ownerToken)->getJson("/api/v1/pos/state?branchId={$foreignBranch->id}")->assertUnprocessable();
        $this->withToken($ownerToken)->getJson("/api/v1/pos/state?branchId={$deletedBranch->id}")->assertUnprocessable();
        $this->withToken($employeeToken)->postJson('/api/v1/shifts/current', ['branchId' => $branch->id, 'openingCash' => 0])->assertNotFound();

        try {
            $assignments->assign($employee, $branch->fresh());
            $this->fail('Inactive branches must not be assignable.');
        } catch (DomainException) {
            // Expected: retained historical assignment cannot be replaced with an inactive one.
        }
    }

    public function test_inactive_branch_is_rejected_before_new_order_creation(): void
    {
        $this->seed();
        $tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $owner = User::query()->where('tenant_id', $tenantId)->where('role', 'owner')->firstOrFail();
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->where('name', 'Downtown')->value('id');
        DB::table('branches')->where('id', $branchId)->update(['is_active' => false]);

        $this->withToken($this->authenticateTenantUser($tenantId, $owner))
            ->postJson('/api/v1/orders', ['branchId' => $branchId])
            ->assertNotFound();
    }

    public function test_owner_can_administrate_same_tenant_branches_and_sensitive_fields_are_rejected(): void
    {
        [$tenant, $active, $owner] = $this->tenantBranchUser('configuration', 'owner');
        $inactive = Branch::query()->create([
            'tenant_id' => $tenant->id,
            'name' => 'Inactive branch',
            'timezone' => 'Asia/Damascus',
            'currency' => 'SYP',
            'is_active' => false,
        ]);
        $token = $this->authenticateTenantUser($tenant->id, $owner);

        $this->withToken($token)->getJson('/api/v1/cafe-configuration/branches')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonFragment(['id' => $inactive->id, 'isActive' => false]);

        $created = $this->withToken($token)->postJson('/api/v1/cafe-configuration/branches', [
            'name' => '  New branch  ',
            'address' => 'Main Street',
            'phone' => '+963 11 123 4567',
            'timezone' => 'Asia/Damascus',
        ])->assertCreated()
            ->assertJsonPath('data.name', 'New branch')
            ->assertJsonPath('data.currency', 'SYP')
            ->assertJsonPath('data.isActive', true);
        $branchId = $created->json('data.id');
        $this->assertDatabaseHas('branches', ['id' => $branchId, 'tenant_id' => $tenant->id, 'currency' => 'SYP', 'is_active' => true]);

        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branchId}", [
            'name' => 'Renamed branch',
            'address' => null,
            'phone' => '123',
            'timezone' => 'UTC',
        ])->assertOk()->assertJsonPath('data.name', 'Renamed branch');

        $this->withToken($token)->postJson('/api/v1/cafe-configuration/branches', ['name' => 'Missing Zone'])
            ->assertUnprocessable()->assertJsonValidationErrors('timezone');
        $this->withToken($token)->postJson('/api/v1/cafe-configuration/branches', ['name' => 'Bad Zone', 'timezone' => 'Not/AZone'])
            ->assertUnprocessable()->assertJsonValidationErrors('timezone');
        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branchId}", ['currency' => 'USD'])
            ->assertUnprocessable()->assertJsonValidationErrors('currency');
        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branchId}", ['isActive' => false])
            ->assertUnprocessable()->assertJsonValidationErrors('isActive');
        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branchId}", ['tenant_id' => 999])
            ->assertUnprocessable()->assertJsonValidationErrors('tenant_id');
        $this->assertDatabaseHas('branches', ['id' => $branchId, 'tenant_id' => $tenant->id, 'currency' => 'SYP', 'is_active' => true]);
        $this->assertDatabaseHas('branches', ['id' => $active->id, 'tenant_id' => $tenant->id]);
    }

    public function test_configuration_is_owner_only_and_tenant_scoped(): void
    {
        [$tenantA, $branchA, $owner] = $this->tenantBranchUser('owner-a', 'owner');
        [$tenantB, $branchB] = $this->tenantBranchUser('owner-b', 'owner');
        $manager = $this->user($tenantA, 'manager');
        $employee = $this->user($tenantA, 'cashier');
        $ownerToken = $this->authenticateTenantUser($tenantA->id, $owner);

        $this->withToken($ownerToken)->getJson("/api/v1/cafe-configuration/branches/{$branchB->id}")->assertNotFound();
        $this->withToken($ownerToken)->putJson("/api/v1/cafe-configuration/branches/{$branchB->id}", ['name' => 'Nope'])->assertNotFound();
        $this->withToken($ownerToken)->getJson('/api/v1/cafe-configuration/branches')
            ->assertOk()->assertJsonMissing(['id' => $branchB->id]);
        $managerToken = $this->authenticateTenantUser($tenantA->id, $manager);
        // Manager gets read access (needed for the Printing screen's branch
        // picker) but branch creation stays Owner-only.
        $this->withToken($managerToken)
            ->getJson('/api/v1/cafe-configuration/branches')->assertOk();
        $this->withToken($managerToken)
            ->postJson('/api/v1/cafe-configuration/branches', ['name' => 'Nope', 'timezone' => 'UTC'])
            ->assertForbidden();
        $this->withToken($this->authenticateTenantUser($tenantA->id, $employee))
            ->getJson('/api/v1/cafe-configuration/branches')->assertForbidden();
        $this->assertDatabaseHas('branches', ['id' => $branchA->id, 'tenant_id' => $tenantA->id]);
        $this->assertDatabaseHas('branches', ['id' => $branchB->id, 'tenant_id' => $tenantB->id, 'name' => $branchB->name]);
    }

    public function test_manager_can_administer_branch_printing_but_not_other_branch_fields(): void
    {
        [$tenant, $branch, $owner] = $this->tenantBranchUser('manager-printing', 'owner');
        app(FinancialSetupService::class)->ensureForTenant($tenant->id);
        $manager = $this->user($tenant, 'manager');
        $employee = $this->user($tenant, 'cashier');
        $managerToken = $this->authenticateTenantUser($tenant->id, $manager);
        $originalName = $branch->name;

        // Manager can read the branch (needed to load current printer config).
        $this->withToken($managerToken)->getJson("/api/v1/cafe-configuration/branches/{$branch->id}")
            ->assertOk()->assertJsonPath('data.name', $originalName);

        // Manager saving printer fields succeeds; a non-printer field sent
        // alongside them (the Flutter client always submits the full branch
        // draft) is silently ignored rather than applied or rejected.
        $this->withToken($managerToken)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}", [
            'name' => 'Renamed by manager',
            'receiptPrintingEnabled' => true,
            'defaultPaperWidth' => '58mm',
            'autoPrintAfterPayment' => true,
            'defaultPrinterName' => 'Counter printer',
            'defaultPrinterIp' => '192.168.1.60',
            'defaultPrinterPort' => 9100,
        ])->assertOk()
            ->assertJsonPath('data.name', $originalName)
            ->assertJsonPath('data.defaultPrinterIp', '192.168.1.60');

        $this->assertDatabaseHas('branches', [
            'id' => $branch->id, 'name' => $originalName, 'default_printer_ip' => '192.168.1.60',
        ]);

        // Employee cannot reach any of this.
        $employeeToken = $this->authenticateTenantUser($tenant->id, $employee);
        $this->withToken($employeeToken)->getJson("/api/v1/cafe-configuration/branches/{$branch->id}")->assertForbidden();
        $this->withToken($employeeToken)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}", [
            'defaultPrinterIp' => '192.168.1.70',
        ])->assertForbidden();
        $this->call('GET', "/api/v1/cafe-configuration/branches/{$branch->id}")->assertUnauthorized();

        // Tenant isolation: a manager in another tenant cannot read or write
        // this branch's printer configuration.
        [, $foreignBranch] = $this->tenantBranchUser('manager-printing-foreign', 'owner');
        $this->withToken($managerToken)->getJson("/api/v1/cafe-configuration/branches/{$foreignBranch->id}")->assertNotFound();
        $this->withToken($managerToken)->putJson("/api/v1/cafe-configuration/branches/{$foreignBranch->id}", [
            'defaultPrinterIp' => '10.0.0.5',
        ])->assertNotFound();
    }

    public function test_owner_can_store_tenant_scoped_branch_printer_defaults(): void
    {
        [$tenant, $branch, $owner] = $this->tenantBranchUser('printer-defaults', 'owner');
        app(FinancialSetupService::class)->ensureForTenant($tenant->id);
        $token = $this->authenticateTenantUser($tenant->id, $owner);

        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}", [
            'receiptPrintingEnabled' => true,
            'defaultPaperWidth' => '58mm',
            'autoPrintAfterPayment' => true,
            'defaultPrinterName' => 'Counter printer',
            'defaultPrinterIp' => '192.168.1.50',
            'defaultPrinterPort' => 9100,
        ])->assertOk()
            ->assertJsonPath('data.receiptPrintingEnabled', true)
            ->assertJsonPath('data.defaultPaperWidth', '58mm')
            ->assertJsonPath('data.defaultPrinterIp', '192.168.1.50');

        $this->assertDatabaseHas('branches', [
            'id' => $branch->id, 'tenant_id' => $tenant->id,
            'receipt_printing_enabled' => true, 'default_printer_port' => 9100,
        ]);
        $this->withToken($token)->getJson('/api/v1/branches')->assertOk()
            ->assertJsonPath('data.0.printerConfig.ipAddress', '192.168.1.50')
            ->assertJsonPath('data.0.printerConfig.paperWidth', '58mm');
        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}", [
            'defaultPrinterIp' => 'not a host',
        ])->assertUnprocessable()->assertJsonValidationErrors('defaultPrinterIp');
    }

    public function test_failed_branch_printer_update_does_not_touch_receipt_template(): void
    {
        [$tenant, $branch, $owner] = $this->tenantBranchUser('printer-template-isolation', 'owner');
        app(FinancialSetupService::class)->ensureForTenant($tenant->id);
        $token = $this->authenticateTenantUser($tenant->id, $owner);

        // Save a known, distinct receipt template via the receipt-template endpoint first.
        $templatePayload = [
            'header' => ['showLogo' => false, 'showCafeName' => true, 'showBranchName' => true, 'showAddress' => true, 'showPhone' => true],
            'orderInfo' => ['showOrderNumber' => true, 'showDateTime' => true, 'showCashier' => true, 'showCustomer' => true, 'showOrderType' => true],
            'items' => ['showProductName' => true, 'showQuantity' => true, 'showUnitPrice' => true, 'showModifiers' => true, 'showNotes' => true],
            'totals' => ['showSubtotal' => true, 'showDiscount' => true, 'showTax' => true, 'showTotal' => true],
            'payment' => ['showPaymentMethod' => true, 'showPaidAmount' => true, 'showChange' => true],
            'footer' => ['enabled' => true, 'text' => 'Distinct footer text'],
            'sectionOrder' => ['header', 'orderInfo', 'items', 'totals', 'payment', 'footer'],
        ];
        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template", $templatePayload)
            ->assertOk()
            ->assertJsonPath('data.footer.text', 'Distinct footer text');

        $templateBefore = DB::table('receipt_templates')->where('branch_id', $branch->id)->where('tenant_id', $tenant->id)->first();
        $this->assertNotNull($templateBefore);

        // An invalid branch printer-defaults payload (printing enabled with
        // no printer IP/port) must be rejected without touching the receipt
        // template saved above.
        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}", [
            'receiptPrintingEnabled' => true,
        ])->assertUnprocessable()->assertJsonValidationErrors('defaultPrinterIp');

        $templateAfter = DB::table('receipt_templates')->where('branch_id', $branch->id)->where('tenant_id', $tenant->id)->first();
        $this->assertEquals($templateBefore, $templateAfter);
    }

    /** @return array{Tenant, Branch, User} */
    private function tenantBranchUser(string $name, string $role): array
    {
        $tenant = Tenant::query()->create(['name' => "Tenant {$name}", 'slug' => 'tenant-'.strtolower($name).'-'.uniqid(), 'status' => 'active']);
        $branch = Branch::query()->create(['tenant_id' => $tenant->id, 'name' => "Branch {$name}", 'timezone' => 'UTC', 'currency' => 'SYP', 'is_active' => true]);

        return [$tenant, $branch, $this->user($tenant, $role)];
    }

    private function user(Tenant $tenant, string $role): User
    {
        return User::query()->create([
            'tenant_id' => $tenant->id,
            'name' => ucfirst($role),
            'email' => uniqid($role, true).'@example.test',
            'username' => $role === 'cashier' ? 'cashier-'.uniqid() : null,
            'password' => Hash::make('password'),
            'role' => $role,
            'is_active' => true,
        ]);
    }
}
