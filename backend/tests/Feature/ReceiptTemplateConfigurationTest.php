<?php

namespace Tests\Feature;

use App\Models\Branch;
use App\Models\Tenant;
use App\Models\User;
use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class ReceiptTemplateConfigurationTest extends TestCase
{
    use RefreshDatabase;

    private function validPayload(array $overrides = []): array
    {
        // sectionOrder is a plain list; array_replace_recursive would merge
        // it index-by-index instead of replacing it wholesale, so it's
        // pulled out and reattached as a full override.
        $sectionOrder = $overrides['sectionOrder'] ?? null;
        unset($overrides['sectionOrder']);
        $payload = array_replace_recursive([
            'header' => [
                'showLogo' => true,
                'showCafeName' => true,
                'showBranchName' => true,
                'showAddress' => true,
                'showPhone' => true,
            ],
            'orderInfo' => [
                'showOrderNumber' => true,
                'showDateTime' => true,
                'showCashier' => true,
                'showCustomer' => false,
                'showOrderType' => true,
            ],
            'items' => [
                'showProductName' => true,
                'showQuantity' => true,
                'showUnitPrice' => true,
                'showModifiers' => true,
                'showNotes' => true,
            ],
            'totals' => [
                'showSubtotal' => true,
                'showDiscount' => true,
                'showTax' => true,
                'showTotal' => true,
            ],
            'payment' => [
                'showPaymentMethod' => true,
                'showPaidAmount' => true,
                'showChange' => true,
            ],
            'footer' => [
                'enabled' => true,
                'text' => 'Thank you for visiting',
            ],
            'sectionOrder' => ['header', 'orderInfo', 'items', 'totals', 'payment', 'footer'],
        ], $overrides);

        if ($sectionOrder !== null) {
            $payload['sectionOrder'] = $sectionOrder;
        }

        return $payload;
    }

    public function test_branch_with_no_saved_template_returns_defaults(): void
    {
        [$tenant, $branch, $owner] = $this->tenantBranchUser('defaults', 'owner');
        $token = $this->authenticateTenantUser($tenant->id, $owner);

        $this->withToken($token)->getJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template")
            ->assertOk()
            ->assertJsonPath('data.header.showLogo', true)
            ->assertJsonPath('data.orderInfo.showCustomer', false)
            ->assertJsonPath('data.items.showProductName', true)
            ->assertJsonPath('data.totals.showTotal', true)
            ->assertJsonPath('data.footer.text', 'Thank you for visiting')
            ->assertJsonPath('data.sectionOrder', ['header', 'orderInfo', 'items', 'totals', 'payment', 'footer']);

        $this->assertDatabaseCount('receipt_templates', 0);
    }

    public function test_owner_can_persist_and_reload_branch_specific_template(): void
    {
        [$tenant, $branch, $owner] = $this->tenantBranchUser('persist', 'owner');
        $token = $this->authenticateTenantUser($tenant->id, $owner);

        $payload = $this->validPayload([
            'header' => ['showLogo' => false],
            'orderInfo' => ['showCustomer' => true],
            'footer' => ['text' => 'شكراً لزيارتكم'],
        ]);

        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template", $payload)
            ->assertOk()
            ->assertJsonPath('data.header.showLogo', false)
            ->assertJsonPath('data.orderInfo.showCustomer', true)
            ->assertJsonPath('data.footer.text', 'شكراً لزيارتكم');

        $this->assertDatabaseHas('receipt_templates', [
            'tenant_id' => $tenant->id,
            'branch_id' => $branch->id,
            'type' => 'receipt',
        ]);

        $this->withToken($token)->getJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template")
            ->assertOk()
            ->assertJsonPath('data.header.showLogo', false)
            ->assertJsonPath('data.footer.text', 'شكراً لزيارتكم');
    }

    public function test_template_is_tenant_isolated(): void
    {
        [$tenantA, $branchA, $ownerA] = $this->tenantBranchUser('tpl-a', 'owner');
        [, $branchB] = $this->tenantBranchUser('tpl-b', 'owner');
        $tokenA = $this->authenticateTenantUser($tenantA->id, $ownerA);

        $this->withToken($tokenA)->getJson("/api/v1/cafe-configuration/branches/{$branchB->id}/receipt-template")
            ->assertNotFound();
        $this->withToken($tokenA)->putJson("/api/v1/cafe-configuration/branches/{$branchB->id}/receipt-template", $this->validPayload())
            ->assertNotFound();
    }

    public function test_switching_branches_returns_each_branchs_own_template(): void
    {
        [$tenant, $branchOne, $owner] = $this->tenantBranchUser('switch-1', 'owner');
        $branchTwo = Branch::query()->create(['tenant_id' => $tenant->id, 'name' => 'Branch switch-2', 'timezone' => 'UTC', 'currency' => 'SYP', 'is_active' => true]);
        $token = $this->authenticateTenantUser($tenant->id, $owner);

        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branchOne->id}/receipt-template", $this->validPayload(['footer' => ['text' => 'Branch one footer']]))
            ->assertOk();

        $this->withToken($token)->getJson("/api/v1/cafe-configuration/branches/{$branchOne->id}/receipt-template")
            ->assertOk()->assertJsonPath('data.footer.text', 'Branch one footer');
        $this->withToken($token)->getJson("/api/v1/cafe-configuration/branches/{$branchTwo->id}/receipt-template")
            ->assertOk()->assertJsonPath('data.footer.text', 'Thank you for visiting');
    }

    public function test_section_order_must_be_a_permutation_with_items_before_totals(): void
    {
        [$tenant, $branch, $owner] = $this->tenantBranchUser('order-validation', 'owner');
        $token = $this->authenticateTenantUser($tenant->id, $owner);

        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template", $this->validPayload([
            'sectionOrder' => ['header', 'orderInfo', 'items', 'totals', 'payment'],
        ]))->assertUnprocessable()->assertJsonValidationErrors('sectionOrder');

        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template", $this->validPayload([
            'sectionOrder' => ['header', 'orderInfo', 'totals', 'items', 'payment', 'footer'],
        ]))->assertUnprocessable()->assertJsonValidationErrors('sectionOrder');
    }

    public function test_footer_text_rejects_html_and_overlong_input(): void
    {
        [$tenant, $branch, $owner] = $this->tenantBranchUser('footer-validation', 'owner');
        $token = $this->authenticateTenantUser($tenant->id, $owner);

        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template", $this->validPayload([
            'footer' => ['text' => '<script>alert(1)</script>'],
        ]))->assertUnprocessable()->assertJsonValidationErrors('footer.text');

        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template", $this->validPayload([
            'footer' => ['text' => str_repeat('a', 501)],
        ]))->assertUnprocessable()->assertJsonValidationErrors('footer.text');
    }

    public function test_product_name_and_total_cannot_be_disabled(): void
    {
        [$tenant, $branch, $owner] = $this->tenantBranchUser('locked-fields', 'owner');
        $token = $this->authenticateTenantUser($tenant->id, $owner);

        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template", $this->validPayload([
            'items' => ['showProductName' => false],
            'totals' => ['showTotal' => false],
        ]))
            ->assertOk()
            ->assertJsonPath('data.items.showProductName', true)
            ->assertJsonPath('data.totals.showTotal', true);
    }

    public function test_failed_receipt_template_update_does_not_touch_branch_printer_defaults(): void
    {
        [$tenant, $branch, $owner] = $this->tenantBranchUser('template-isolation', 'owner');
        app(FinancialSetupService::class)->ensureForTenant($tenant->id);
        $token = $this->authenticateTenantUser($tenant->id, $owner);

        // Set known, distinct branch printer defaults via the branch endpoint.
        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}", [
            'receiptPrintingEnabled' => true,
            'defaultPaperWidth' => '58mm',
            'autoPrintAfterPayment' => true,
            'defaultPrinterName' => 'Counter printer',
            'defaultPrinterIp' => '192.168.1.99',
            'defaultPrinterPort' => 9100,
        ])->assertOk();

        $expectedPrinterDefaults = [
            'id' => $branch->id,
            'receipt_printing_enabled' => true,
            'default_paper_width' => '58mm',
            'auto_print_after_payment' => true,
            'default_printer_name' => 'Counter printer',
            'default_printer_ip' => '192.168.1.99',
            'default_printer_port' => 9100,
        ];
        $this->assertDatabaseHas('branches', $expectedPrinterDefaults);

        // An invalid receipt-template payload must be rejected without
        // touching the branch's printer defaults set above.
        $this->withToken($token)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template", $this->validPayload([
            'sectionOrder' => ['header', 'orderInfo', 'items', 'totals', 'payment'],
        ]))->assertUnprocessable()->assertJsonValidationErrors('sectionOrder');

        $this->assertDatabaseHas('branches', $expectedPrinterDefaults);
        // The failed request also must not have created a receipt_templates row.
        $this->assertDatabaseCount('receipt_templates', 0);

        $this->withToken($token)->getJson("/api/v1/cafe-configuration/branches/{$branch->id}")
            ->assertOk()
            ->assertJsonPath('data.receiptPrintingEnabled', true)
            ->assertJsonPath('data.defaultPaperWidth', '58mm')
            ->assertJsonPath('data.defaultPrinterIp', '192.168.1.99')
            ->assertJsonPath('data.defaultPrinterPort', 9100);
    }

    public function test_owner_and_manager_can_get_and_put_but_employee_cannot(): void
    {
        [$tenant, $branch, $owner] = $this->tenantBranchUser('authz', 'owner');
        $manager = $this->user($tenant, 'manager');
        $employee = $this->user($tenant, 'cashier');
        $ownerToken = $this->authenticateTenantUser($tenant->id, $owner);
        $managerToken = $this->authenticateTenantUser($tenant->id, $manager);
        $employeeToken = $this->authenticateTenantUser($tenant->id, $employee);

        $this->withToken($ownerToken)->getJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template")->assertOk();
        $this->withToken($ownerToken)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template", $this->validPayload())->assertOk();

        $this->withToken($managerToken)->getJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template")->assertOk();
        $this->withToken($managerToken)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template", $this->validPayload([
            'footer' => ['text' => 'Saved by manager'],
        ]))->assertOk()->assertJsonPath('data.footer.text', 'Saved by manager');

        $this->withToken($employeeToken)->getJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template")->assertForbidden();
        $this->withToken($employeeToken)->putJson("/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template", $this->validPayload())->assertForbidden();

        $this->call('GET', "/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template")->assertUnauthorized();
        $this->call('PUT', "/api/v1/cafe-configuration/branches/{$branch->id}/receipt-template", $this->validPayload())->assertUnauthorized();
    }

    public function test_manager_cross_tenant_branch_access_is_rejected(): void
    {
        [$tenantA, $branchA] = $this->tenantBranchUser('manager-tenant-a', 'owner');
        [, $branchB] = $this->tenantBranchUser('manager-tenant-b', 'owner');
        $manager = $this->user($tenantA, 'manager');
        $managerToken = $this->authenticateTenantUser($tenantA->id, $manager);

        $this->withToken($managerToken)->getJson("/api/v1/cafe-configuration/branches/{$branchB->id}/receipt-template")->assertNotFound();
        $this->withToken($managerToken)->putJson("/api/v1/cafe-configuration/branches/{$branchB->id}/receipt-template", $this->validPayload())->assertNotFound();
        // The manager's own tenant/branch is unaffected.
        $this->withToken($managerToken)->getJson("/api/v1/cafe-configuration/branches/{$branchA->id}/receipt-template")->assertOk();
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
            'password' => Hash::make('password'),
            'role' => $role,
            'is_active' => true,
        ]);
    }
}
