<?php

namespace Database\Seeders;

use App\Domain\Inventory\BarCheckTemplateService;
use App\Domain\Inventory\WarehouseTransferService;
use App\Http\Controllers\Api\ShiftController;
use App\Models\User;
use App\Services\FinancialSetupService;
use App\Services\StockCountService;
use App\Services\StockMovementService;
use Illuminate\Database\Seeder;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Operational inventory history for the normal local Cafe 618 tenant.
 *
 * The catalog and its baseline balances belong to InventoryCenterSeeder.
 * This seeder only adds idempotent, service-backed operational activity so
 * the inventory screens demonstrate real posting behaviour and WAC history.
 */
final class Cafe618InventoryOperationsDemoSeeder extends Seeder
{
    private int $tenantId;
    private int $ownerId;
    private int $branchId;
    private Carbon $today;
    private Request $request;

    public function run(): void
    {
        if (! app()->environment(['local', 'development', 'testing'])) {
            throw new RuntimeException('Cafe618InventoryOperationsDemoSeeder is restricted to local, development, and testing environments.');
        }

        $this->today = now()->startOfDay();
        $this->tenantId = (int) DB::table('tenants')->where('slug', 'cafe-618')->value('id');
        $owner = User::query()->where('tenant_id', $this->tenantId)->where('role', 'owner')->first();
        $branch = DB::table('branches')->where('tenant_id', $this->tenantId)->whereNull('deleted_at')->orderBy('id')->first();
        if (! $this->tenantId || ! $owner || ! $branch) {
            return;
        }

        $this->ownerId = (int) $owner->id;
        $this->branchId = (int) $branch->id;
        app(FinancialSetupService::class)->ensureForTenant($this->tenantId, $this->branchId, $this->ownerId);
        app(FinancialSetupService::class)->ensureBranchMainWarehouse($this->tenantId, $this->branchId, $this->ownerId);
        $this->request = Request::create('/seed/cafe-618/inventory-operations', 'POST');
        $this->request->attributes->set('tenant_id', $this->tenantId);
        $this->request->attributes->set('auth_user', $owner);

        $warehouses = $this->warehouses();
        if (! $warehouses['central'] || ! $warehouses['main'] || ! $warehouses['bar']) {
            throw new RuntimeException('Cafe 618 inventory warehouse foundation is incomplete.');
        }

        $items = $this->items();
        $this->ensureAssignments($warehouses, $items);
        $this->seedReceiptsAndWaste($warehouses, $items);
        $this->seedCounts($warehouses, $items);
        $this->seedTransfers($warehouses, $items);
        $this->seedBarChecks($warehouses, $items);
    }

    /** @return array{central: ?object, main: ?object, bar: ?object, kitchen: ?object} */
    private function warehouses(): array
    {
        $rows = DB::table('warehouses')->where('tenant_id', $this->tenantId)->where('is_active', true)->whereNull('deleted_at')->where('code', 'not like', 'LEGACY-%')->get();

        return [
            'central' => $rows->firstWhere('type', 'central'),
            'main' => $rows->first(fn (object $row) => $row->type === 'branch_main' && (int) $row->branch_id === $this->branchId),
            'bar' => $rows->first(fn (object $row) => $row->type === 'bar' && (int) $row->branch_id === $this->branchId),
            'kitchen' => $rows->first(fn (object $row) => $row->type === 'kitchen' && (int) $row->branch_id === $this->branchId),
        ];
    }

    /** @return array<string, int> */
    private function items(): array
    {
        $skus = ['INV-BEANS', 'INV-MILK-FRESH', 'INV-CUP-12OZ', 'INV-CUP-16OZ', 'INV-LID-12OZ', 'INV-CROISSANT', 'INV-CLEANER', 'INV-ICE', 'INV-VANILLA', 'INV-CARAMEL'];
        $items = DB::table('inventory_items')->where('tenant_id', $this->tenantId)->whereIn('sku', $skus)->pluck('id', 'sku');
        $missing = array_diff($skus, $items->keys()->all());
        if ($missing !== []) {
            throw new RuntimeException('Cafe 618 inventory catalog is missing: '.implode(', ', $missing));
        }

        return $items->map(fn ($id) => (int) $id)->all();
    }

    private function ensureAssignments(array $warehouses, array $items): void
    {
        $locations = [
            'INV-BEANS' => ['central', 'main', 'bar'],
            'INV-MILK-FRESH' => ['central', 'main', 'bar'],
            'INV-CUP-12OZ' => ['central', 'main', 'bar'],
            'INV-CUP-16OZ' => ['central', 'main', 'bar'],
            'INV-LID-12OZ' => ['central', 'main', 'bar'],
            'INV-VANILLA' => ['central', 'main', 'bar'],
            'INV-CARAMEL' => ['central', 'main', 'bar'],
            'INV-CROISSANT' => ['central', 'main', 'kitchen'],
            'INV-CLEANER' => ['central', 'main'],
            'INV-ICE' => ['central', 'bar'],
        ];
        $now = now();
        foreach ($locations as $sku => $types) {
            foreach ($types as $type) {
                if (! isset($warehouses[$type]) || $warehouses[$type] === null) {
                    continue;
                }
                DB::table('inventory_item_warehouses')->insertOrIgnore([
                    'tenant_id' => $this->tenantId,
                    'inventory_item_id' => $items[$sku],
                    'warehouse_id' => $warehouses[$type]->id,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }
    }

    private function seedReceiptsAndWaste(array $warehouses, array $items): void
    {
        // Several receipts at different costs intentionally exercise the real
        // weighted-average calculation. No balance or WAC field is written here.
        foreach ([
            ['beans-1', 'INV-BEANS', '18.000', '9.5000', 54, 'Green coffee receipt â€” early-month roast'],
            ['beans-2', 'INV-BEANS', '14.000', '9.8000', 36, 'Green coffee receipt â€” mid-month roast'],
            ['beans-3', 'INV-BEANS', '16.000', '10.1000', 12, 'Green coffee receipt â€” current roast'],
            ['milk-1', 'INV-MILK-FRESH', '36.000', '1.2200', 42, 'Fresh milk chilled delivery'],
            ['milk-2', 'INV-MILK-FRESH', '28.000', '1.3100', 20, 'Fresh milk weekend delivery'],
            ['cups-1', 'INV-CUP-12OZ', '500.000', '0.0620', 39, '12oz cups carton receipt'],
            ['cups-2', 'INV-CUP-12OZ', '400.000', '0.0690', 9, '12oz cups price-adjusted receipt'],
            ['lids-1', 'INV-LID-12OZ', '600.000', '0.0310', 34, 'Cup lids carton receipt'],
            ['croissants-1', 'INV-CROISSANT', '40.000', '1.0800', 16, 'Morning pastry delivery'],
        ] as [$name, $sku, $quantity, $cost, $daysAgo, $reason]) {
            $this->movement($name, $warehouses['central'], $items[$sku], 'stock_in', $quantity, $cost, $daysAgo, $reason);
        }

        foreach ([
            ['expired-milk', 'INV-MILK-FRESH', '3.000', 8, 'Expired milk removed during receiving inspection'],
            ['broken-cups', 'INV-CUP-12OZ', '24.000', 6, 'Damaged cup sleeve discarded'],
            ['spoiled-pastry', 'INV-CROISSANT', '3.000', 5, 'Unsold pastry discarded at end of day'],
            ['bean-spill', 'INV-BEANS', '0.650', 2, 'Coffee beans spilled during grinder refill'],
        ] as [$name, $sku, $quantity, $daysAgo, $reason]) {
            $this->movement($name, $warehouses['central'], $items[$sku], 'waste', $quantity, null, $daysAgo, $reason);
        }
    }

    private function movement(string $name, object $warehouse, int $itemId, string $type, string $quantity, ?string $unitCost, int $daysAgo, string $reason): void
    {
        $payload = [
            'warehouseId' => $warehouse->id,
            'branchId' => $warehouse->branch_id,
            'itemId' => $itemId,
            'type' => $type,
            'quantity' => $quantity,
            'reason' => $reason,
            'referenceType' => 'cafe618_inventory_demo',
            'referenceId' => 1,
            'idempotencyKey' => $this->scenario('movement-'.$name),
            'occurredAt' => $this->dateTime($daysAgo),
        ];
        if ($unitCost !== null) {
            $payload['unitCost'] = $unitCost;
        }
        app(StockMovementService::class)->record($this->request, $this->tenantId, $payload, $this->ownerId);
    }

    private function seedCounts(array $warehouses, array $items): void
    {
        $this->count('zero-variance', $warehouses['central'], 31, function (object $line): string {
            return (string) $line->expected_quantity;
        });
        $this->count('shortage', $warehouses['central'], 15, function (object $line) use ($items): string {
            return (int) $line->inventory_item_id === $items['INV-CUP-12OZ']
                ? number_format(max(0, (float) $line->expected_quantity - 18), 3, '.', '')
                : (string) $line->expected_quantity;
        }, 'Shortage found after counter service reconciliation.');
        $this->count('surplus', $warehouses['central'], 7, function (object $line) use ($items): string {
            return (int) $line->inventory_item_id === $items['INV-LID-12OZ']
                ? number_format((float) $line->expected_quantity + 25, 3, '.', '')
                : (string) $line->expected_quantity;
        }, 'Unrecorded carton found in the receiving area.');

        $notes = $this->countNotes('open-cycle');
        if (! DB::table('stock_counts')->where('tenant_id', $this->tenantId)->where('notes', $notes)->exists()) {
            $service = app(StockCountService::class);
            $id = $service->create($this->request, $this->tenantId, ['warehouseId' => $warehouses['main']->id, 'countDate' => $this->today->toDateString(), 'countType' => 'cycle', 'categoryFilters' => ['Coffee'], 'notes' => $notes], $this->ownerId);
            $service->transition($this->request, $this->tenantId, $id, 'start', $this->ownerId);
        }
    }

    private function count(string $name, object $warehouse, int $daysAgo, callable $quantity, ?string $varianceReason = null): void
    {
        $notes = $this->countNotes($name);
        if (DB::table('stock_counts')->where('tenant_id', $this->tenantId)->where('notes', $notes)->exists()) {
            return;
        }

        $service = app(StockCountService::class);
        $id = $service->create($this->request, $this->tenantId, ['warehouseId' => $warehouse->id, 'countDate' => $this->date($daysAgo), 'notes' => $notes], $this->ownerId);
        $service->transition($this->request, $this->tenantId, $id, 'start', $this->ownerId);
        DB::table('stock_count_lines')->where('tenant_id', $this->tenantId)->where('stock_count_id', $id)->orderBy('id')->each(function (object $line) use ($service, $id, $quantity, $varianceReason): void {
            $entered = $quantity($line);
            $service->upsertLine($this->tenantId, $id, [
                'itemId' => (int) $line->inventory_item_id,
                'countedQuantity' => $entered,
                'reason' => $entered === (string) $line->expected_quantity ? null : $varianceReason,
            ], $this->ownerId);
        });
        $service->transition($this->request, $this->tenantId, $id, 'submit', $this->ownerId);
        $service->transition($this->request, $this->tenantId, $id, 'approve', $this->ownerId);
        $service->transition($this->request, $this->tenantId, $id, 'post', $this->ownerId);
    }

    private function seedTransfers(array $warehouses, array $items): void
    {
        $this->transfer('central-to-main-received', $warehouses['central'], $warehouses['main'], [
            ['itemId' => $items['INV-BEANS'], 'requestedQuantity' => '9.000'],
            ['itemId' => $items['INV-MILK-FRESH'], 'requestedQuantity' => '12.000'],
            ['itemId' => $items['INV-CUP-12OZ'], 'requestedQuantity' => '180.000'],
            ['itemId' => $items['INV-VANILLA'], 'requestedQuantity' => '4.000'],
            ['itemId' => $items['INV-CARAMEL'], 'requestedQuantity' => '4.000'],
        ], 'received');
        $this->transfer('main-to-bar-partial', $warehouses['main'], $warehouses['bar'], [
            ['itemId' => $items['INV-BEANS'], 'requestedQuantity' => '3.000'],
            ['itemId' => $items['INV-MILK-FRESH'], 'requestedQuantity' => '5.000'],
            ['itemId' => $items['INV-CUP-12OZ'], 'requestedQuantity' => '90.000'],
        ], 'partial');
        $this->transfer('central-to-kitchen-draft', $warehouses['central'], $warehouses['kitchen'] ?: $warehouses['main'], [
            ['itemId' => $items['INV-CROISSANT'], 'requestedQuantity' => '12.000'],
        ], 'draft');
        $this->transfer('central-to-main-cancelled', $warehouses['central'], $warehouses['main'], [
            ['itemId' => $items['INV-CUP-16OZ'], 'requestedQuantity' => '20.000'],
        ], 'cancelled');
    }

    private function transfer(string $name, object $source, object $destination, array $lines, string $target): void
    {
        $service = app(WarehouseTransferService::class);
        $key = $this->scenario('transfer-'.$name);
        $id = $service->create($this->request, $this->tenantId, [
            'sourceWarehouseId' => $source->id,
            'destinationWarehouseId' => $destination->id,
            'lines' => array_map(fn (array $line) => $line + ['unit' => $this->itemUnit($line['itemId'])], $lines),
            'notes' => 'Cafe 618 inventory demo: '.str_replace('-', ' ', $name),
            'idempotencyKey' => $key,
        ], $this->ownerId);
        $status = (string) DB::table('warehouse_transfers')->where('id', $id)->value('status');
        if ($target === 'draft' || $status === 'cancelled') {
            return;
        }
        if ($status === 'draft') {
            $service->action($this->request, $this->tenantId, $id, 'submit', ['idempotencyKey' => $key.'-submit'], $this->ownerId);
            $status = 'submitted';
        }
        if ($target === 'cancelled' && $status === 'submitted') {
            $service->action($this->request, $this->tenantId, $id, 'cancel', ['idempotencyKey' => $key.'-cancel', 'cancellationReason' => 'Delivery schedule changed before approval.'], $this->ownerId);
            return;
        }
        if ($status === 'submitted') {
            $service->action($this->request, $this->tenantId, $id, 'approve', ['idempotencyKey' => $key.'-approve'], $this->ownerId);
            $status = 'approved';
        }
        if ($status === 'approved') {
            $service->action($this->request, $this->tenantId, $id, 'dispatch', ['idempotencyKey' => $key.'-dispatch'], $this->ownerId);
            $status = 'dispatched';
        }
        if ($target === 'received' && $status === 'dispatched') {
            $service->receive($this->request, $this->tenantId, $id, ['idempotencyKey' => $key.'-receipt', 'lines' => array_map(fn (array $line) => ['itemId' => $line['itemId'], 'receivedQuantity' => $line['requestedQuantity'], 'unit' => $this->itemUnit($line['itemId'])], $lines)], $this->ownerId);
        }
        if ($target === 'partial' && $status === 'dispatched') {
            $first = $lines[0];
            $service->receive($this->request, $this->tenantId, $id, ['idempotencyKey' => $key.'-receipt-one', 'lines' => [[
                'itemId' => $first['itemId'], 'receivedQuantity' => '2.000', 'unit' => $this->itemUnit($first['itemId']), 'discrepancyReason' => 'Partial delivery is still in transit.',
            ]]], $this->ownerId);
        }
    }

    private function seedBarChecks(array $warehouses, array $items): void
    {
        if (! $warehouses['bar']) {
            return;
        }
        $template = $this->barTemplate($warehouses['bar'], $items);
        $service = app(StockCountService::class);

        // A posted check gives history; a second active shift/check leaves the
        // Bar Checks screen with a useful in-progress operational scenario.
        $completedShift = $this->shift('completed-bar-check');
        $completed = $this->barCheck($service, $completedShift, $warehouses['bar']->id);
        $this->completeBarCheck($completed, false);
        $this->closeShift($completedShift);

        $varianceShift = $this->shift('completed-bar-check-variance');
        $variance = $this->barCheck($service, $varianceShift, $warehouses['bar']->id);
        $this->completeBarCheck($variance, true);
        $this->closeShift($varianceShift);

        $openShift = $this->shift('open-bar-check');
        $open = $this->barCheck($service, $openShift, $warehouses['bar']->id);
        if ((string) DB::table('stock_counts')->where('id', $open)->value('status') === 'in_progress') {
            $line = DB::table('stock_count_lines')->where('stock_count_id', $open)->orderBy('id')->first();
            if ($line) {
                $service->upsertLine($this->tenantId, $open, ['itemId' => $line->inventory_item_id, 'countedQuantity' => (string) $line->expected_quantity], $this->ownerId);
            }
        }
    }

    private function barCheck(StockCountService $service, int $shiftId, int $warehouseId): int
    {
        $existing = DB::table('stock_counts')->where('tenant_id', $this->tenantId)->where('shift_id', $shiftId)->where('warehouse_id', $warehouseId)->where('count_type', 'shift_check')->value('id');

        return $existing ? (int) $existing : $service->startBarCheck($this->request, $this->tenantId, $shiftId, $warehouseId, $this->ownerId);
    }

    private function barTemplate(object $bar, array $items): int
    {
        $lines = [
            ['itemId' => $items['INV-BEANS'], 'countUnit' => 'kg', 'required' => true, 'tolerance' => '0.050', 'requiresReviewWhenExceeded' => false],
            ['itemId' => $items['INV-MILK-FRESH'], 'countUnit' => 'liter', 'required' => true, 'tolerance' => '0.100', 'requiresReviewWhenExceeded' => false],
            ['itemId' => $items['INV-CUP-12OZ'], 'countUnit' => 'piece', 'required' => true, 'tolerance' => '5.000', 'requiresReviewWhenExceeded' => false],
        ];
        $validated = app(BarCheckTemplateService::class)->validate($this->tenantId, $this->branchId, $bar->id, $lines, false);
        $existing = DB::table('bar_check_templates')->where('tenant_id', $this->tenantId)->where('warehouse_id', $bar->id)->where('name', 'Cafe 618 Bar Opening Check')->first();
        DB::table('bar_check_templates')->where('tenant_id', $this->tenantId)->where('warehouse_id', $bar->id)->when($existing, fn ($query) => $query->where('id', '!=', $existing->id))->update(['is_active' => false, 'updated_at' => now()]);
        if ($existing) {
            DB::table('bar_check_templates')->where('id', $existing->id)->update(['is_active' => true, 'updated_by' => $this->ownerId, 'updated_at' => now()]);
            DB::table('bar_check_template_lines')->where('bar_check_template_id', $existing->id)->delete();
            DB::table('bar_check_template_lines')->insert(array_map(fn (array $line) => $line + ['bar_check_template_id' => $existing->id, 'created_at' => now(), 'updated_at' => now()], $validated['lines']));
            return (int) $existing->id;
        }
        $id = (int) DB::table('bar_check_templates')->insertGetId([
            'tenant_id' => $this->tenantId, 'branch_id' => $this->branchId, 'warehouse_id' => $bar->id, 'name' => 'Cafe 618 Bar Opening Check', 'is_active' => true, 'required_for_shift_close' => false,
            'created_by' => $this->ownerId, 'updated_by' => $this->ownerId, 'created_at' => now(), 'updated_at' => now(),
        ]);
        DB::table('bar_check_template_lines')->insert(array_map(fn (array $line) => $line + ['bar_check_template_id' => $id, 'created_at' => now(), 'updated_at' => now()], $validated['lines']));

        return $id;
    }

    private function shift(string $scenario): int
    {
        $notes = 'Cafe 618 inventory demo shift: '.$scenario;
        $existing = DB::table('shifts')->where('tenant_id', $this->tenantId)->where('notes', $notes)->value('id');
        if ($existing) {
            return (int) $existing;
        }
        $request = Request::create('/api/v1/shifts/current', 'POST', ['branchId' => $this->branchId, 'openingCash' => 0]);
        $request->attributes->set('tenant_id', $this->tenantId);
        $request->attributes->set('auth_user', User::findOrFail($this->ownerId));
        $response = app(ShiftController::class)->open($request)->getData(true);
        $id = (int) $response['data']['id'];
        DB::table('shifts')->where('id', $id)->update(['notes' => $notes, 'updated_at' => now()]);

        return $id;
    }

    private function completeBarCheck(int $countId, bool $withVariance): void
    {
        if ((string) DB::table('stock_counts')->where('id', $countId)->value('status') !== 'in_progress') {
            return;
        }
        $service = app(StockCountService::class);
        DB::table('stock_count_lines')->where('stock_count_id', $countId)->orderBy('id')->each(function (object $line) use ($service, $countId, $withVariance): void {
            $quantity = (string) $line->expected_quantity;
            if ($withVariance && $line->id === DB::table('stock_count_lines')->where('stock_count_id', $countId)->min('id')) {
                $quantity = number_format(max(0, (float) $quantity - 0.100), 3, '.', '');
            }
            $service->upsertLine($this->tenantId, $countId, ['itemId' => $line->inventory_item_id, 'countedQuantity' => $quantity, 'reason' => $quantity === (string) $line->expected_quantity ? null : 'Measured variance during bar opening check.'], $this->ownerId);
        });
        $service->transition($this->request, $this->tenantId, $countId, 'submit', $this->ownerId);
        $service->transition($this->request, $this->tenantId, $countId, 'approve', $this->ownerId);
        $service->transition($this->request, $this->tenantId, $countId, 'post', $this->ownerId);
    }

    private function closeShift(int $shiftId): void
    {
        $shift = DB::table('shifts')->where('id', $shiftId)->first(['status', 'notes']);
        if (! $shift || (string) $shift->status !== 'open') {
            return;
        }
        $request = Request::create('/api/v1/shifts/'.$shiftId.'/close', 'POST', ['closingCash' => 0, 'note' => $shift->notes]);
        $request->attributes->set('tenant_id', $this->tenantId);
        $request->attributes->set('auth_user', User::findOrFail($this->ownerId));
        app(ShiftController::class)->close($request, $shiftId);
    }

    private function scenario(string $name): string
    {
        return 'cafe-618-inventory-'.$this->today->format('Ymd').'-'.$name;
    }

    private function countNotes(string $name): string
    {
        return 'Cafe 618 inventory demo count: '.$this->today->format('Ymd').' '.$name;
    }

    private function date(int $daysAgo): string
    {
        return $this->today->copy()->subDays($daysAgo)->toDateString();
    }

    private function dateTime(int $daysAgo): string
    {
        return $this->today->copy()->subDays($daysAgo)->setTime(9, 30)->toDateTimeString();
    }

    private function itemUnit(int $itemId): string
    {
        return (string) DB::table('inventory_items')->where('tenant_id', $this->tenantId)->where('id', $itemId)->value('unit');
    }
}
