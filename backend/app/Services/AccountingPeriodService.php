<?php

namespace App\Services;

use App\Support\FinancialActor;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class AccountingPeriodService
{
    public function __construct(private readonly AccountingPeriodReadinessService $readiness, private readonly OperationalAuditService $audit) {}

    public function create(Request $request, int $tenantId, array $data, int $actorId): object
    {
        if ($data['startDate'] > $data['endDate']) throw ValidationException::withMessages(['endDate' => 'The period end date must be on or after the start date.']);
        return DB::transaction(function () use ($request, $tenantId, $data, $actorId): object {
            $this->assertNoOverlap($tenantId, $data['startDate'], $data['endDate']);
            $id = (int) DB::table('accounting_periods')->insertGetId(['tenant_id' => $tenantId, 'name' => $data['name'], 'start_date' => $data['startDate'], 'end_date' => $data['endDate'], 'status' => 'open', 'notes' => $data['notes'] ?? null, 'created_at' => now(), 'updated_at' => now()]);
            $row = $this->find($tenantId, $id); $this->audit->record($request, $tenantId, 'accounting_period.created', 'accounting_period', $id, [], (array) $row, null, $actorId); return $row;
        });
    }

    public function update(Request $request, int $tenantId, int $id, array $data, int $actorId): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $data, $actorId): object {
            $before = DB::table('accounting_periods')->where('tenant_id', $tenantId)->where('id', $id)->lockForUpdate()->first(); abort_unless($before, 404, 'Accounting period not found.');
            if ($before->status !== 'open') throw ValidationException::withMessages(['period' => 'Only open accounting periods can be edited.']);
            $start = $data['startDate'] ?? $before->start_date; $end = $data['endDate'] ?? $before->end_date;
            if ($start > $end) throw ValidationException::withMessages(['endDate' => 'The period end date must be on or after the start date.']);
            $this->assertNoOverlap($tenantId, $start, $end, $id);
            DB::table('accounting_periods')->where('id', $id)->update(['name' => $data['name'] ?? $before->name, 'start_date' => $start, 'end_date' => $end, 'notes' => array_key_exists('notes', $data) ? $data['notes'] : $before->notes, 'updated_at' => now()]);
            $row = $this->find($tenantId, $id); $this->audit->record($request, $tenantId, 'accounting_period.updated', 'accounting_period', $id, (array) $before, (array) $row, null, $actorId); return $row;
        });
    }

    public function close(Request $request, int $tenantId, int $id, int $actorId): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $actorId): object {
            $row = DB::table('accounting_periods')->where('tenant_id', $tenantId)->where('id', $id)->lockForUpdate()->first(); abort_unless($row, 404, 'Accounting period not found.');
            if ($row->status === 'closed') return $row;
            if ($row->status !== 'open') throw ValidationException::withMessages(['period' => 'Only an open period can be closed.']);
            $result = $this->readiness->evaluate($tenantId, $row->start_date, $row->end_date);
            if (! $result['canClose']) throw ValidationException::withMessages(['readiness' => $result['blockers']]);
            DB::table('accounting_periods')->where('id', $id)->update(['status' => 'closed', 'closed_at' => now(), 'closed_by' => $actorId, 'updated_at' => now()]);
            $after = $this->find($tenantId, $id); $this->audit->record($request, $tenantId, 'accounting_period.closed', 'accounting_period', $id, (array) $row, (array) $after, null, $actorId); return $after;
        });
    }

    public function lock(Request $request, int $tenantId, int $id, int $actorId): object
    {
        return DB::transaction(function () use ($request, $tenantId, $id, $actorId): object {
            $row = DB::table('accounting_periods')->where('tenant_id', $tenantId)->where('id', $id)->lockForUpdate()->first(); abort_unless($row, 404, 'Accounting period not found.');
            if ($row->status === 'locked') return $row;
            if ($row->status !== 'closed') throw ValidationException::withMessages(['period' => 'Only a closed period can be locked.']);
            DB::table('accounting_periods')->where('id', $id)->update(['status' => 'locked', 'locked_at' => now(), 'locked_by' => $actorId, 'updated_at' => now()]);
            $after = $this->find($tenantId, $id); $this->audit->record($request, $tenantId, 'accounting_period.locked', 'accounting_period', $id, (array) $row, (array) $after, null, $actorId); return $after;
        });
    }

    public function find(int $tenantId, int $id): object { $row = DB::table('accounting_periods')->where('tenant_id', $tenantId)->where('id', $id)->first(); abort_unless($row, 404, 'Accounting period not found.'); return $row; }
    public function readiness(int $tenantId, int $id): array { $row = $this->find($tenantId, $id); return $this->readiness->evaluate($tenantId, $row->start_date, $row->end_date); }
    private function assertNoOverlap(int $tenantId, string $start, string $end, ?int $except = null): void { $exists = DB::table('accounting_periods')->where('tenant_id', $tenantId)->when($except, fn ($q) => $q->where('id', '<>', $except))->where('start_date', '<=', $end)->where('end_date', '>=', $start)->lockForUpdate()->exists(); if ($exists) throw ValidationException::withMessages(['dates' => 'ACCOUNTING_PERIOD_OVERLAP']); }
}
