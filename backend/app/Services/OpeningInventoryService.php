<?php

namespace App\Services;

use App\Domain\Inventory\InventoryPostingService;
use App\Support\InventoryDecimal;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class OpeningInventoryService
{
    public function __construct(
        private readonly InventoryPostingService $stock,
        private readonly AccountingPostingService $posting,
        private readonly FinanceAccountMap $accountMap,
    ) {}

    public function create(Request $request, int $tenantId, int $periodId, array $lines, int $actorId): array
    {
        return DB::transaction(function () use ($request, $tenantId, $periodId, $lines, $actorId): array {
            $period = DB::table('accounting_periods')->where('tenant_id', $tenantId)
                ->where('id', $periodId)->lockForUpdate()->first();
            abort_unless($period, 404, 'Accounting period not found.');
            if ($period->status !== 'open') {
                throw ValidationException::withMessages(['period' => 'بضاعة أول المدة تحتاج إلى سنة محاسبية مفتوحة.']);
            }
            if (DB::table('journal_entries')->where('tenant_id', $tenantId)
                ->where('source_type', 'opening_inventory')->where('source_id', $periodId)->exists()) {
                throw ValidationException::withMessages(['period' => 'تم ترحيل بضاعة أول المدة لهذه السنة مسبقًا.']);
            }
            $seen = [];
            $movementIds = [];
            $totalCents = 0;
            foreach ($lines as $index => $line) {
                $warehouseId = (int) $line['warehouseId'];
                $itemId = (int) $line['itemId'];
                $pair = "$warehouseId:$itemId";
                if (isset($seen[$pair])) {
                    throw ValidationException::withMessages(["lines.$index" => 'لا تكرر المادة في المستودع نفسه.']);
                }
                $seen[$pair] = true;
                if (DB::table('stock_movements')->where('tenant_id', $tenantId)->where('warehouse_id', $warehouseId)
                    ->where('inventory_item_id', $itemId)->exists()) {
                    throw ValidationException::withMessages(["lines.$index" => 'بضاعة أول المدة متاحة فقط قبل أول حركة لهذه المادة في المستودع.']);
                }
                if (InventoryDecimal::units($line['quantity']) <= 0 || InventoryDecimal::cost($line['unitCost']) <= 0) {
                    throw ValidationException::withMessages(["lines.$index" => 'الكمية وتكلفة الوحدة يجب أن تكونا أكبر من صفر.']);
                }
                $warehouse = DB::table('warehouses')->where('tenant_id', $tenantId)->where('id', $warehouseId)->first();
                abort_unless($warehouse, 422, 'Invalid warehouse.');
                $result = $this->stock->post($request, $tenantId, [
                    'type' => 'opening_balance', 'warehouseId' => $warehouseId,
                    'branchId' => $warehouse->branch_id, 'itemId' => $itemId,
                    'quantity' => $line['quantity'], 'unitCost' => $line['unitCost'],
                    'unit' => $line['unit'] ?? null,
                    'reason' => 'بضاعة أول المدة — '.$period->name,
                    'referenceType' => 'opening_inventory', 'referenceId' => $periodId,
                    'occurredAt' => $period->start_date.' 12:00:00',
                ], $actorId);
                $movementIds[] = $result->movementId;
                $totalCents += Money::cents(DB::table('stock_movements')->where('id', $result->movementId)->value('total_cost'));
            }
            if ($totalCents <= 0) {
                throw ValidationException::withMessages(['lines' => 'إجمالي قيمة بضاعة أول المدة يجب أن يكون أكبر من صفر.']);
            }
            $journalId = $this->posting->post($request, $tenantId, [
                'sourceType' => 'opening_inventory', 'sourceId' => $periodId,
                'sourceEvent' => 'OPENING_INVENTORY', 'entryDate' => $period->start_date,
                'description' => 'بضاعة أول المدة — '.$period->name,
                'lines' => [
                    ['accountCode' => $this->accountMap->code($tenantId, 'sales.inventory_asset'), 'debit' => Money::decimal($totalCents)],
                    ['accountCode' => $this->accountMap->code($tenantId, 'inventory.opening_equity'), 'credit' => Money::decimal($totalCents)],
                ],
            ], $actorId);

            return ['journalEntryId' => $journalId, 'movementIds' => $movementIds,
                'totalCost' => Money::decimal($totalCents), 'periodId' => $periodId];
        });
    }
}
