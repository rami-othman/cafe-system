<?php

namespace Tests\Feature;

use App\Services\AccountingPostingService;
use App\Services\FinancialSetupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

/**
 * AccountingPostingService is not yet called by any business controller in
 * Phase 0B (see docs/finance/FINANCE_IMPLEMENTATION_PLAN.md) — these tests
 * exercise the service directly, the same way a future PaymentController
 * integration eventually will, to prove the orchestration layer itself is
 * correct before anything is wired to it.
 */
class AccountingPostingServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_post_resolves_accounts_by_code_and_posts_a_balanced_entry_through_the_existing_journal_service(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();

        $entryId = $this->service()->postSale($this->request(), $tenantId, [
            'sourceId' => 555,
            'sourceEvent' => 'POS_ORDER_PAID',
            'entryDate' => '2026-08-29',
            'description' => 'Test sale posting',
            'lines' => [
                ['accountCode' => '1010', 'debit' => '100.00'],
                ['accountCode' => '4000', 'credit' => '100.00'],
            ],
        ], $this->ownerId($tenantId));

        $entry = DB::table('journal_entries')->where('id', $entryId)->first();
        $this->assertNotNull($entry);
        $this->assertSame($tenantId, (int) $entry->tenant_id);
        $this->assertSame('posted', $entry->status);
        $this->assertSame('pos_order', $entry->source_type);
        $this->assertSame(555, (int) $entry->source_id);
        $this->assertSame('POS_ORDER_PAID', $entry->source_event);

        $lines = DB::table('journal_entry_lines')->where('journal_entry_id', $entryId)->orderBy('line_number')->get();
        $this->assertCount(2, $lines);
        $this->assertSame(100.0, (float) $lines[0]->debit);
        $this->assertSame(100.0, (float) $lines[1]->credit);

        $this->assertDatabaseHas('activity_logs', [
            'tenant_id' => $tenantId,
            'action' => 'accounting_posting.created',
            'entity_type' => 'pos_order',
            'entity_id' => 555,
        ]);
    }

    public function test_replaying_the_same_source_event_returns_the_original_entry_and_creates_no_duplicate(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        $data = [
            'sourceId' => 777,
            'sourceEvent' => 'POS_ORDER_PAID',
            'entryDate' => '2026-08-29',
            'lines' => [
                ['accountCode' => '1010', 'debit' => '50.00'],
                ['accountCode' => '4000', 'credit' => '50.00'],
            ],
        ];

        $firstId = $this->service()->postSale($this->request(), $tenantId, $data, $this->ownerId($tenantId));
        $secondId = $this->service()->postSale($this->request(), $tenantId, $data, $this->ownerId($tenantId));

        $this->assertSame($firstId, $secondId);
        $this->assertSame(1, DB::table('journal_entries')->where('tenant_id', $tenantId)->where('source_type', 'pos_order')->where('source_id', 777)->where('source_event', 'POS_ORDER_PAID')->count());
    }

    public function test_a_different_source_event_for_the_same_source_id_is_not_treated_as_a_duplicate(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        $lines = [
            ['accountCode' => '1010', 'debit' => '20.00'],
            ['accountCode' => '4000', 'credit' => '20.00'],
        ];

        $saleId = $this->service()->postSale($this->request(), $tenantId, [
            'sourceId' => 900, 'sourceEvent' => 'POS_ORDER_PAID', 'entryDate' => '2026-08-29', 'lines' => $lines,
        ], $this->ownerId($tenantId));
        $refundId = $this->service()->postRefund($this->request(), $tenantId, [
            'sourceId' => 900, 'sourceEvent' => 'PAYMENT_REFUNDED', 'entryDate' => '2026-08-29', 'lines' => $lines,
        ], $this->ownerId($tenantId));

        $this->assertNotSame($saleId, $refundId);
    }

    public function test_posting_against_an_unknown_account_code_is_rejected_and_nothing_is_committed(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();

        $this->expectException(ValidationException::class);
        try {
            $this->service()->postExpense($this->request(), $tenantId, [
                'sourceId' => 1, 'sourceEvent' => 'EXPENSE_PAID', 'entryDate' => '2026-08-29',
                'lines' => [
                    ['accountCode' => '9999-DOES-NOT-EXIST', 'debit' => '10.00'],
                    ['accountCode' => '1010', 'credit' => '10.00'],
                ],
            ], $this->ownerId($tenantId));
        } finally {
            $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $tenantId)->where('source_type', 'expense')->count());
        }
    }

    public function test_posting_against_an_inactive_account_is_rejected(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();
        DB::table('financial_accounts')->where('tenant_id', $tenantId)->where('code', '1010')->update(['is_active' => false]);

        $this->expectException(ValidationException::class);
        $this->service()->postSale($this->request(), $tenantId, [
            'sourceId' => 2, 'sourceEvent' => 'POS_ORDER_PAID', 'entryDate' => '2026-08-29',
            'lines' => [
                ['accountCode' => '1010', 'debit' => '10.00'],
                ['accountCode' => '4000', 'credit' => '10.00'],
            ],
        ], $this->ownerId($tenantId));
    }

    public function test_an_unbalanced_posting_is_rejected_and_rolls_back_the_draft_it_created(): void
    {
        $this->seed();
        $tenantId = $this->demoTenantId();

        try {
            $this->service()->postSale($this->request(), $tenantId, [
                'sourceId' => 3, 'sourceEvent' => 'POS_ORDER_PAID', 'entryDate' => '2026-08-29',
                'lines' => [
                    ['accountCode' => '1010', 'debit' => '100.00'],
                    ['accountCode' => '4000', 'credit' => '90.00'],
                ],
            ], $this->ownerId($tenantId));
            $this->fail('Expected an unbalanced posting to throw.');
        } catch (ValidationException $exception) {
            // expected — the whole posting (draft + lines) must not survive.
        }

        $this->assertSame(0, DB::table('journal_entries')->where('tenant_id', $tenantId)->where('source_type', 'pos_order')->count());
    }

    public function test_account_resolution_is_tenant_scoped_even_when_two_tenants_share_the_same_code(): void
    {
        $this->seed();
        $tenantA = $this->demoTenantId();
        $tenantB = DB::table('tenants')->insertGetId(['name' => 'Posting Tenant B', 'slug' => 'posting-tenant-b', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        app(FinancialSetupService::class)->ensureForTenant($tenantB);

        $entryId = $this->service()->postSale($this->request(), $tenantA, [
            'sourceId' => 4, 'sourceEvent' => 'POS_ORDER_PAID', 'entryDate' => '2026-08-29',
            'lines' => [
                ['accountCode' => '1010', 'debit' => '15.00'],
                ['accountCode' => '4000', 'credit' => '15.00'],
            ],
        ], $this->ownerId($tenantA));

        $cashAccountForTenantA = (int) DB::table('financial_accounts')->where('tenant_id', $tenantA)->where('code', '1010')->value('id');
        $cashAccountForTenantB = (int) DB::table('financial_accounts')->where('tenant_id', $tenantB)->where('code', '1010')->value('id');
        $this->assertNotSame($cashAccountForTenantA, $cashAccountForTenantB);

        $usedAccountId = (int) DB::table('journal_entry_lines')->where('journal_entry_id', $entryId)->where('debit', '15.00')->value('financial_account_id');
        $this->assertSame($cashAccountForTenantA, $usedAccountId);
    }

    private function service(): AccountingPostingService
    {
        return app(AccountingPostingService::class);
    }

    private function request(): Request
    {
        return Request::create('/api/v1/test-posting', 'POST');
    }

    private function demoTenantId(): int
    {
        return (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
    }

    private function ownerId(int $tenantId): int
    {
        return (int) DB::table('users')->where('tenant_id', $tenantId)->where('role', 'owner')->value('id');
    }
}
