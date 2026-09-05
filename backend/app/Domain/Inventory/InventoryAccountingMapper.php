<?php

namespace App\Domain\Inventory;

use App\Services\AccountingPostingService;
use App\Services\OperationalAuditService;
use App\Support\Money;
use App\Support\InventoryDecimal;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * The sole Inventory-to-Finance mapping layer. It consumes only a persisted,
 * final stock movement and its own cost snapshot; it never recalculates WAC.
 */
final class InventoryAccountingMapper
{
    private const INVENTORY_ASSET_CODE = '1100';
    private const VARIANCE_CODE = '5010';

    public function __construct(private readonly AccountingPostingService $posting, private readonly OperationalAuditService $audit) {}

    /** Posts a required financial impact while the originating inventory transaction is still open. */
    public function postForFinalMovement(Request $request, int $tenantId, object $movement, ?int $actorId): array
    {
        $decision = $this->decision($tenantId, $movement, true);
        if ($decision['status'] !== 'POSTED') return $decision;
        $journalId = $this->posting->post($request, $tenantId, [
            'sourceType' => 'inventory_movement',
            'sourceId' => (int) $movement->id,
            'sourceEvent' => $decision['event'],
            'branchId' => $movement->branch_id ? (int) $movement->branch_id : null,
            'entryDate' => substr((string) $movement->occurred_at, 0, 10) ?: now()->toDateString(),
            'description' => $decision['description'],
            'lines' => $decision['lines'],
        ], $actorId);
        $this->audit->record($request, $tenantId, 'stock_movement.finance_posted', 'stock_movement', (int) $movement->id, [], ['journalEntryId' => $journalId, 'classification' => $decision['classification'], 'amount' => $decision['amount']], $movement->branch_id ? (int) $movement->branch_id : null, $actorId);

        return [...$decision, 'journalId' => $journalId, 'journalReference' => $this->journalNumber($tenantId, $journalId)];
    }

    /** Read-only Finance impact contract for inventory APIs. */
    public function impactForMovement(int $tenantId, object $movement): array
    {
        $decision = $this->decision($tenantId, $movement, false);
        if ($decision['status'] !== 'POSTED') return $decision;
        $journal = DB::table('journal_entries')->where('tenant_id', $tenantId)->where('source_type', 'inventory_movement')->where('source_id', $movement->id)->where('source_event', $decision['event'])->first(['id', 'entry_number', 'status']);
        if (! $journal) return [...$decision, 'status' => 'FAILED', 'message' => 'A required inventory accounting posting is missing.'];
        return [...$decision, 'journalId' => (int) $journal->id, 'journalReference' => $journal->entry_number, 'status' => 'POSTED'];
    }

    private function decision(int $tenantId, object $movement, bool $throwForConfiguration): array
    {
        $type = (string) $movement->type;
        if ($type === 'sale_consumption') return $this->nonPosting('ALREADY_HANDLED_BY_SOURCE', 'SALE_CONSUMPTION', 'Sale consumption is already included in the paid-order COGS journal.');
        if (in_array($type, ['transfer_in', 'transfer_out'], true)) return $this->nonPosting('NOT_APPLICABLE', 'INTERNAL_TRANSFER', 'Internal transfer — no P&L impact.');
        if (in_array($type, ['opening_balance', 'stock_in', 'stock_out', 'return_in', 'return_out'], true)) return $this->nonPosting('NOT_APPLICABLE', 'UNMAPPED_RECEIPT_OR_MOVEMENT', 'This inventory movement has no approved Finance business mapping.');
        if (in_array($type, ['adjustment_in', 'adjustment_out'], true)) return $this->configurationRequired($throwForConfiguration, 'Manual adjustment accounting treatment is not configured.');
        if (! in_array($type, ['waste', 'stock_count_variance'], true)) return $this->nonPosting('NOT_APPLICABLE', 'UNSUPPORTED_MOVEMENT_TYPE', 'No Finance mapping exists for this inventory movement type.');

        $amountCents = Money::cents((string) $movement->total_cost, 'totalCost');
        if ($amountCents === 0) return $this->nonPosting('NOT_APPLICABLE', 'ZERO_COST', 'The finalized movement has no monetary impact.');
        $accounts = $this->accounts($tenantId, $throwForConfiguration);
        if ($accounts === null) return $this->configurationRequired(false, 'Inventory Asset or Inventory Variance account is not configured.');
        $outbound = InventoryDecimal::units($movement->quantity_out) > 0;
        $isWaste = $type === 'waste';
        $event = $isWaste ? 'INVENTORY_WASTE' : ($outbound ? 'STOCK_COUNT_SHORTAGE' : 'STOCK_COUNT_SURPLUS');
        $classification = $isWaste ? 'WASTE' : ($outbound ? 'STOCK_COUNT_SHORTAGE' : 'STOCK_COUNT_SURPLUS');
        $lines = ($isWaste || $outbound)
            ? [['accountCode' => $accounts['variance'], 'debit' => Money::decimal($amountCents)], ['accountCode' => $accounts['inventory'], 'credit' => Money::decimal($amountCents)]]
            : [['accountCode' => $accounts['inventory'], 'debit' => Money::decimal($amountCents)], ['accountCode' => $accounts['variance'], 'credit' => Money::decimal($amountCents)]];
        return [
            'status' => 'POSTED',
            'classification' => $classification,
            'event' => $event,
            'amount' => Money::decimal($amountCents),
            'message' => null,
            'description' => match ($classification) {
                'WASTE' => 'Inventory waste',
                'STOCK_COUNT_SHORTAGE' => 'Stock count shortage',
                default => 'Stock count surplus',
            },
            'lines' => $lines,
        ];
    }

    private function accounts(int $tenantId, bool $throw): ?array
    {
        $codes = DB::table('financial_accounts')->where('tenant_id', $tenantId)->whereIn('code', [self::INVENTORY_ASSET_CODE, self::VARIANCE_CODE])->where('is_active', true)->whereNull('deleted_at')->pluck('code')->all();
        if (in_array(self::INVENTORY_ASSET_CODE, $codes, true) && in_array(self::VARIANCE_CODE, $codes, true)) return ['inventory' => self::INVENTORY_ASSET_CODE, 'variance' => self::VARIANCE_CODE];
        if ($throw) throw ValidationException::withMessages(['finance' => 'Inventory Asset or Inventory Variance account is not configured.']);
        return null;
    }

    private function configurationRequired(bool $throw, string $message): array
    {
        if ($throw) throw ValidationException::withMessages(['finance' => $message]);
        return $this->nonPosting('CONFIGURATION_REQUIRED', 'CONFIGURATION_REQUIRED', $message);
    }
    private function nonPosting(string $status, string $classification, string $message): array { return ['status' => $status, 'classification' => $classification, 'amount' => null, 'journalId' => null, 'journalReference' => null, 'message' => $message, 'lines' => []]; }
    private function journalNumber(int $tenantId, int $id): ?string { return DB::table('journal_entries')->where('tenant_id', $tenantId)->where('id', $id)->value('entry_number'); }
}
