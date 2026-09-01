<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Central orchestration layer for automatic accounting postings.
 *
 * This service does NOT invent business accounting rules. It resolves
 * tenant-scoped account codes, guards against posting the same business
 * event twice, and delegates the actual ledger write to the existing
 * JournalEntryService (createDraft + post) so every poster — manual entries
 * through JournalEntryController, and every automatic poster added in a
 * later phase — shares one code path and one set of guarantees (tenant
 * isolation, debit == credit, draft-then-post, audit trail).
 *
 * Phase 0B ships this generic engine plus named adapter methods for the
 * business events future phases will need. Every adapter is a thin
 * pass-through: it does not select accounts, does not compute amounts, and
 * does not know about payment methods, cash accounts, or COGS — those
 * mappings don't exist yet. The caller must supply a fully-resolved `lines`
 * array (account codes + debit/credit amounts already decided). Nothing in
 * this codebase calls any of these adapters yet; POS, Refunds, Inventory,
 * and Reports do not post automatically until their designated phase (see
 * docs/finance/FINANCE_IMPLEMENTATION_PLAN.md).
 */
class AccountingPostingService
{
    public function __construct(
        private readonly JournalEntryService $entries,
        private readonly OperationalAuditService $audit,
    ) {}

    /**
     * @param array{
     *   branchId?: int|null,
     *   sourceType: string,
     *   sourceId?: int|null,
     *   sourceEvent?: string|null,
     *   entryDate?: string|null,
     *   description?: string|null,
     *   lines: array<int, array{accountCode: string, debit?: string|float|int|null, credit?: string|float|int|null, description?: string|null}>,
     * } $data
     */
    public function post(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        $sourceType = (string) ($data['sourceType'] ?? '');
        if ($sourceType === '') {
            throw ValidationException::withMessages(['sourceType' => 'A posting must declare which business event it represents.']);
        }
        $sourceId = isset($data['sourceId']) ? (int) $data['sourceId'] : null;
        $sourceEvent = isset($data['sourceEvent']) ? trim((string) $data['sourceEvent']) : null;
        if ($sourceId === null || $sourceId <= 0 || $sourceEvent === '') {
            throw ValidationException::withMessages(['sourceEvent' => 'An automated posting requires a positive sourceId and a non-empty sourceEvent.']);
        }

        // Duplicate-posting guard: the same tenant + source_type + source_id
        // + source_event must never create two accounting effects. Checked
        // once outside the transaction (fast path for the common replay
        // case) and again inside it under a lock (see below) before insert.
        $existing = $this->existingPostingFor($tenantId, $sourceType, $sourceId, $sourceEvent);
        if ($existing !== null) {
            return $existing;
        }

        try {
            return DB::transaction(function () use ($request, $tenantId, $data, $actorId, $sourceType, $sourceId, $sourceEvent): int {
                $existing = $this->existingPostingFor($tenantId, $sourceType, $sourceId, $sourceEvent, lock: true);
                if ($existing !== null) {
                    return $existing;
                }

                $lines = array_map(
                    fn (array $line): array => [
                        'accountId' => $this->resolveAccountId($tenantId, (string) $line['accountCode']),
                        'debit' => $line['debit'] ?? '0',
                        'credit' => $line['credit'] ?? '0',
                        'description' => $line['description'] ?? null,
                    ],
                    $data['lines'] ?? [],
                );

                $entryId = $this->entries->createDraft($request, $tenantId, [
                    'branchId' => $data['branchId'] ?? null,
                    'entryDate' => $data['entryDate'] ?? now()->toDateString(),
                    'sourceType' => $sourceType,
                    'sourceId' => $sourceId,
                    'sourceEvent' => $sourceEvent,
                    'description' => $data['description'] ?? null,
                    'lines' => $lines,
                ], $actorId);

                $this->entries->post($request, $tenantId, $entryId, $actorId);

                $this->audit->record(
                    $request,
                    $tenantId,
                    'accounting_posting.created',
                    $sourceType,
                    $sourceId,
                    [],
                    ['journalEntryId' => $entryId, 'sourceEvent' => $sourceEvent],
                    $data['branchId'] ?? null,
                    $actorId,
                );

                return $entryId;
            });
        } catch (QueryException $exception) {
            // The database unique constraint is the concurrency backstop. If
            // another transaction won the race, return its posting instead of
            // exposing a duplicate-key error to an idempotent caller.
            $existing = $this->existingPostingFor($tenantId, $sourceType, $sourceId, $sourceEvent);
            if ($existing !== null) {
                return $existing;
            }

            throw $exception;
        }
    }

    // ---- Named adapters ---------------------------------------------------
    // Each method below is intentionally a thin pass-through to post(). It
    // exists so a future phase has a stable, named entry point to wire up
    // once its required components (cash accounts, payment methods, COGS,
    // suppliers, ...) exist — not to make POS/Inventory/Expenses look
    // functional today. See the class docblock.

    public function postSale(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        return $this->post($request, $tenantId, [...$data, 'sourceType' => 'pos_order'], $actorId);
    }

    public function postRefund(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        return $this->post($request, $tenantId, [...$data, 'sourceType' => 'payment_refund'], $actorId);
    }

    public function postExpense(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        return $this->post($request, $tenantId, [...$data, 'sourceType' => 'expense'], $actorId);
    }

    public function postSupplierInvoice(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        return $this->post($request, $tenantId, [...$data, 'sourceType' => 'supplier_invoice'], $actorId);
    }

    public function postSupplierPayment(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        return $this->post($request, $tenantId, [...$data, 'sourceType' => 'supplier_payment'], $actorId);
    }

    public function postInventoryAdjustment(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        return $this->post($request, $tenantId, [...$data, 'sourceType' => 'stock_count_variance'], $actorId);
    }

    public function postWaste(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        return $this->post($request, $tenantId, [...$data, 'sourceType' => 'stock_movement_waste'], $actorId);
    }

    public function postCashTransfer(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        return $this->post($request, $tenantId, [...$data, 'sourceType' => 'cash_transfer'], $actorId);
    }

    /**
     * Resolves an account by tenant + code, never by a raw database id —
     * matching FinancialSetupService's own convention ("Default accounts
     * are resolved by tenant plus account code, never by database ID").
     * No account code is ever hard-coded here; the caller supplies it.
     */
    private function resolveAccountId(int $tenantId, string $code): int
    {
        $id = DB::table('financial_accounts')
            ->where('tenant_id', $tenantId)
            ->where('code', $code)
            ->where('is_active', true)
            ->whereNull('deleted_at')
            ->value('id');

        if ($id === null) {
            throw ValidationException::withMessages(['lines' => "No active account with code {$code} exists for this tenant."]);
        }

        return (int) $id;
    }

    private function existingPostingFor(int $tenantId, string $sourceType, int $sourceId, string $sourceEvent, bool $lock = false): ?int
    {
        $query = DB::table('journal_entries')
            ->where('tenant_id', $tenantId)
            ->where('source_type', $sourceType)
            ->where('source_id', $sourceId)
            ->where('source_event', $sourceEvent);
        if ($lock) {
            $query->lockForUpdate();
        }
        $id = $query->value('id');

        return $id === null ? null : (int) $id;
    }
}
