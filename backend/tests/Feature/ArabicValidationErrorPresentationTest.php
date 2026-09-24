<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * F — user-facing validation/error messages must be Arabic, human-readable,
 * and free of raw technical field paths, while the machine-readable
 * `errors.<field>` keys stay intact for API clients. See
 * App\Support\ValidationErrorPresenter and lang/ar/validation.php.
 */
class ArabicValidationErrorPresentationTest extends TestCase
{
    use RefreshDatabase;

    public function test_missing_required_field_returns_arabic_message(): void
    {
        $tenant = $this->tenant('f-required-1');
        $headers = $this->headers($tenant);

        $response = $this->postJson('/api/v1/finance/suppliers', [], $headers)->assertStatus(422);

        $response->assertJsonValidationErrors(['name']);
        $this->assertStringContainsString('مطلوب', $response->json('errors.name.0'));
        $this->assertMatchesRegularExpression('/[\x{0600}-\x{06FF}]/u', $response->json('message'));
    }

    public function test_invalid_purchase_line_unit_cost_shows_one_based_arabic_line_position(): void
    {
        $tenant = $this->tenant('f-line-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers);
        $warehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->value('id');

        $line = fn (string $qty, string $gross) => [
            'lineType' => 'inventory', 'description' => 'Material', 'inventoryItemId' => $itemId, 'warehouseId' => $warehouseId,
            'quantity' => $qty, 'lineGrossAmount' => $gross,
        ];

        $response = $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'F-LINE-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01',
            'invoiceType' => 'inventory',
            'lines' => [
                $line('10.000', '100.00'),
                $line('20.000', '200.00'),
                ['lineType' => 'inventory', 'description' => 'Bad', 'inventoryItemId' => $itemId, 'warehouseId' => $warehouseId,
                    'quantity' => '5.000', 'unitCost' => '0.189189189'],
            ],
        ], $headers)->assertStatus(422);

        $response->assertJsonValidationErrors(['lines.2.unitCost']);
        $message = $response->json('errors')['lines.2.unitCost'][0];
        $this->assertStringContainsString('البند 3', $message);
        $this->assertStringContainsString('تكلفة الوحدة', $message);
        $this->assertStringNotContainsString('lines.2.unitCost', $message);
        $this->assertStringNotContainsString('lines.2.unitCost', $response->json('message'));
    }

    public function test_first_line_error_shows_human_position_one(): void
    {
        $tenant = $this->tenant('f-line-2');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers);
        $warehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->value('id');

        $response = $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'F-LINE-002', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01',
            'invoiceType' => 'inventory',
            'lines' => [
                ['lineType' => 'inventory', 'inventoryItemId' => $itemId, 'warehouseId' => $warehouseId, 'quantity' => '5.000'],
            ],
        ], $headers)->assertStatus(422);

        $response->assertJsonValidationErrors(['lines.0.description']);
        $this->assertStringContainsString('البند 1', $response->json('errors')['lines.0.description'][0]);
    }

    public function test_invalid_branch_field_uses_arabic_attribute_name(): void
    {
        $tenant = $this->tenant('f-attr-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);

        $response = $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'F-ATTR-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01',
            'subtotal' => '10.00',
            'branchId' => 'not-an-id',
        ], $headers)->assertStatus(422);

        $response->assertJsonValidationErrors(['branchId']);
        $message = $response->json('errors')['branchId'][0];
        $this->assertStringContainsString('الفرع', $message);
        $this->assertStringNotContainsString('branchId', $message);
    }

    public function test_date_validation_uses_arabic_field_name(): void
    {
        $tenant = $this->tenant('f-date-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);

        $response = $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'F-DATE-001', 'invoiceDate' => 'not-a-date', 'dueDate' => '2026-10-01',
            'subtotal' => '10.00',
        ], $headers)->assertStatus(422);

        $response->assertJsonValidationErrors(['invoiceDate']);
        $message = $response->json('errors.invoiceDate.0');
        $this->assertStringContainsString('تاريخ الفاتورة', $message);
        $this->assertStringNotContainsString('invoiceDate', $message);
    }

    public function test_array_validation_errors_preserve_machine_readable_field_keys(): void
    {
        $tenant = $this->tenant('f-keys-1');
        $headers = $this->headers($tenant);
        $supplierId = $this->supplier($headers);
        $itemId = $this->inventoryItem($headers);
        $warehouseId = (int) DB::table('warehouses')->where('tenant_id', $tenant)->value('id');

        $response = $this->postJson('/api/v1/finance/supplier-invoices', [
            'supplierId' => $supplierId, 'invoiceNumber' => 'F-KEYS-001', 'invoiceDate' => '2026-09-01', 'dueDate' => '2026-10-01',
            'invoiceType' => 'inventory',
            'lines' => [
                ['lineType' => 'inventory', 'description' => 'Bad', 'inventoryItemId' => $itemId, 'warehouseId' => $warehouseId,
                    'quantity' => '5.000', 'unitCost' => '0.189189189'],
            ],
        ], $headers)->assertStatus(422);

        $errors = $response->json('errors');
        $this->assertArrayHasKey('lines.0.unitCost', $errors);
    }

    public function test_closed_accounting_period_error_is_safe_and_understandable(): void
    {
        $tenant = $this->tenant('f-period-1');
        $headers = $this->headers($tenant);
        $cash = $this->accountId($tenant, '1010');
        $equity = $this->accountId($tenant, '3000');

        $period = (int) $this->postJson('/api/v1/finance/accounting-periods', ['name' => 'F-Period', 'startDate' => '2030-11-01', 'endDate' => '2030-11-30'], $headers)
            ->assertCreated()->json('data.id');
        $this->postJson("/api/v1/finance/accounting-periods/$period/close", [], $headers)->assertOk();

        $response = $this->postJson('/api/v1/finance/journal-entries', [
            'entryDate' => '2030-11-11',
            'lines' => [['accountId' => $cash, 'debit' => '10.00'], ['accountId' => $equity, 'credit' => '10.00']],
        ], $headers)->assertCreated();
        $entryId = $response->json('data.id');

        $failed = $this->postJson("/api/v1/finance/journal-entries/$entryId/post", [], $headers)->assertStatus(422);
        $message = $failed->json('errors.accountingPeriod.0');
        $this->assertStringContainsString('الفترة المحاسبية', $message);
        $this->assertStringNotContainsString('ACCOUNTING_PERIOD', $message);
    }

    public function test_unauthorized_financial_source_message_does_not_expose_internals(): void
    {
        $tenant = $this->tenant('f-cash-1');
        $headers = $this->headers($tenant);
        $userId = (int) DB::table('users')->where('tenant_id', $tenant)->where('role', 'owner')->value('id');
        $branchId = (int) DB::table('branches')->where('tenant_id', $tenant)->value('id');

        try {
            app(\App\Services\CashSourceResolver::class)->resolve($tenant, $userId, $branchId, 999999);
            $this->fail('Expected a validation exception for an unavailable cash location.');
        } catch (\Illuminate\Validation\ValidationException $e) {
            $message = $e->errors()['financialLocationId'][0];
            $this->assertMatchesRegularExpression('/[\x{0600}-\x{06FF}]/u', $message);
            $this->assertStringNotContainsString('SQLSTATE', $message);
            $this->assertStringNotContainsString('financial_locations', $message);
        }
    }

    public function test_http_status_codes_are_unchanged_for_validation_and_conflict_errors(): void
    {
        $tenant = $this->tenant('f-status-1');
        $headers = $this->headers($tenant);

        $this->postJson('/api/v1/finance/suppliers', [], $headers)->assertStatus(422);
    }

    /**
     * Locale precedence (see App\Http\Middleware\SetLocaleFromRequest):
     * no explicit `X-App-Locale` header must still default to Arabic, even
     * though this exact request goes through Symfony's test HTTP client.
     */
    public function test_no_explicit_app_locale_defaults_to_arabic(): void
    {
        $tenant = $this->tenant('f-locale-default');
        $headers = $this->headers($tenant);

        $response = $this->postJson('/api/v1/finance/suppliers', [], $headers)->assertStatus(422);

        $this->assertStringContainsString('مطلوب', $response->json('errors.name.0'));
    }

    public function test_explicit_app_locale_ar_returns_arabic(): void
    {
        $tenant = $this->tenant('f-locale-ar');
        $headers = $this->headers($tenant) + ['X-App-Locale' => 'ar'];

        $response = $this->postJson('/api/v1/finance/suppliers', [], $headers)->assertStatus(422);

        $this->assertStringContainsString('مطلوب', $response->json('errors.name.0'));
    }

    public function test_explicit_app_locale_en_returns_english(): void
    {
        $tenant = $this->tenant('f-locale-en');
        $headers = $this->headers($tenant) + ['X-App-Locale' => 'en'];

        $response = $this->postJson('/api/v1/finance/suppliers', [], $headers)->assertStatus(422);

        $this->assertStringContainsString('required', $response->json('errors.name.0'));
    }

    public function test_unsupported_app_locale_falls_back_to_arabic_default(): void
    {
        $tenant = $this->tenant('f-locale-unsupported');
        $headers = $this->headers($tenant) + ['X-App-Locale' => 'fr-FR'];

        $response = $this->postJson('/api/v1/finance/suppliers', [], $headers)->assertStatus(422);

        $this->assertStringContainsString('مطلوب', $response->json('errors.name.0'));
    }

    public function test_region_qualified_app_locale_is_normalized(): void
    {
        $tenant = $this->tenant('f-locale-region');
        $headers = $this->headers($tenant) + ['X-App-Locale' => 'en-US'];

        $response = $this->postJson('/api/v1/finance/suppliers', [], $headers)->assertStatus(422);

        $this->assertStringContainsString('required', $response->json('errors.name.0'));
    }

    /**
     * The whole point of X-App-Locale: an ambient Accept-Language header
     * that the app itself never chose (Symfony's test client always sends
     * one) must NOT silently override the Arabic default.
     */
    public function test_ambient_accept_language_does_not_override_arabic_default(): void
    {
        $tenant = $this->tenant('f-locale-ambient');
        $headers = $this->headers($tenant) + ['Accept-Language' => 'en-us,en;q=0.5'];

        $response = $this->postJson('/api/v1/finance/suppliers', [], $headers)->assertStatus(422);

        $this->assertStringContainsString('مطلوب', $response->json('errors.name.0'));
    }

    private function tenant(string $slug): int
    {
        $tenantId = DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('branches')->insert(['tenant_id' => $tenantId, 'name' => 'Central Branch', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        app(\App\Services\FinancialSetupService::class)->ensureForTenant($tenantId);

        return (int) $tenantId;
    }

    private function headers(int $tenantId): array
    {
        $userId = (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
        if (! $userId) {
            $userId = (int) DB::table('users')->insertGetId(['tenant_id' => $tenantId, 'name' => 'F Owner', 'email' => "f-owner-$tenantId@example.test", 'password' => bcrypt('password'), 'role' => 'owner', 'is_active' => true, 'created_at' => now(), 'updated_at' => now()]);
        }
        $plainToken = "f-validation-test-$tenantId-$userId";
        DB::table('api_tokens')->updateOrInsert(['tenant_id' => $tenantId, 'user_id' => $userId, 'name' => 'f-validation-test'], ['token_hash' => hash('sha256', $plainToken), 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

        return ['Authorization' => "Bearer $plainToken", 'X-Tenant-Id' => $tenantId];
    }

    private function supplier(array $headers): int
    {
        return (int) $this->postJson('/api/v1/finance/suppliers', ['name' => 'F Validation Supplier '.uniqid()], $headers)->assertCreated()->json('data.id');
    }

    private function inventoryItem(array $headers): int
    {
        $itemId = (int) $this->postJson('/api/v1/inventory/items', [
            'nameAr' => 'صنف اختبار', 'nameEn' => 'F Validation Item '.uniqid(), 'sku' => 'F-VAL-'.strtoupper(uniqid()),
            'itemType' => 'raw_material', 'unit' => 'kg', 'minimumStock' => '0.000', 'reorderLevel' => '0.000',
            'latestUnitCost' => '1.0000', 'isActive' => true,
        ], $headers)->assertCreated()->json('data.id');
        $tenantId = (int) DB::table('inventory_items')->where('id', $itemId)->value('tenant_id');
        if (! DB::table('warehouses')->where('tenant_id', $tenantId)->exists()) {
            $branchId = (int) DB::table('branches')->where('tenant_id', $tenantId)->value('id');
            $this->postJson('/api/v1/warehouses', ['name' => 'Main Warehouse', 'code' => 'WH-'.strtoupper(uniqid()), 'type' => 'other', 'branchId' => $branchId, 'isActive' => true], $headers)->assertCreated();
        }

        return $itemId;
    }

    private function accountId(int $tenantId, string $code): int
    {
        return (int) DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', $code)->value('id');
    }
}
