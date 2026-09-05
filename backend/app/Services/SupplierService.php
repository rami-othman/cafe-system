<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SupplierService
{
    public function __construct(private readonly OperationalAuditService $audit) {}

    public function create(Request $request, int $tenantId, array $data, ?int $actorId): int
    {
        return DB::transaction(function () use ($request, $tenantId, $data, $actorId): int {
            $id = (int) DB::table('suppliers')->insertGetId($this->payload($data) + [
                'tenant_id' => $tenantId,
                'supplier_number' => $this->nextNumber($tenantId),
                'is_active' => true,
                'created_by' => $actorId,
                'updated_by' => $actorId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            $this->audit->record($request, $tenantId, 'supplier.created', 'supplier', $id, [], (array) $this->find($tenantId, $id), null, $actorId);

            return $id;
        });
    }

    public function update(Request $request, int $tenantId, int $id, array $data, ?int $actorId): void
    {
        DB::transaction(function () use ($request, $tenantId, $id, $data, $actorId): void {
            $before = $this->find($tenantId, $id);
            DB::table('suppliers')->where('tenant_id', $tenantId)->where('id', $id)->update($this->payload($data) + ['updated_by' => $actorId, 'updated_at' => now()]);
            $this->audit->record($request, $tenantId, 'supplier.updated', 'supplier', $id, (array) $before, (array) $this->find($tenantId, $id), null, $actorId);
        });
    }

    public function status(Request $request, int $tenantId, int $id, bool $active, ?int $actorId): void
    {
        $before = $this->find($tenantId, $id);
        DB::table('suppliers')->where('tenant_id', $tenantId)->where('id', $id)->update(['is_active' => $active, 'updated_by' => $actorId, 'updated_at' => now()]);
        $this->audit->record($request, $tenantId, $active ? 'supplier.activated' : 'supplier.deactivated', 'supplier', $id, (array) $before, (array) $this->find($tenantId, $id), null, $actorId);
    }

    public function find(int $tenantId, int $id): object
    {
        $row = DB::table('suppliers')->where('tenant_id', $tenantId)->where('id', $id)->whereNull('deleted_at')->first();
        abort_unless($row, 404, 'Supplier not found.');

        return $row;
    }

    private function payload(array $data): array
    {
        return [
            'name' => $data['name'],
            'phone' => $data['phone'] ?? null,
            'email' => $data['email'] ?? null,
            'address' => $data['address'] ?? null,
            'contact_person' => $data['contactPerson'] ?? null,
            'tax_number' => $data['taxNumber'] ?? null,
            'payment_terms_days' => (int) ($data['paymentTermsDays'] ?? 0),
            'notes' => $data['notes'] ?? null,
        ];
    }

    private function nextNumber(int $tenantId): string
    {
        $last = DB::table('suppliers')->where('tenant_id', $tenantId)->lockForUpdate()->orderByDesc('id')->value('supplier_number');
        $number = $last && preg_match('/(\d+)$/', $last, $match) ? ((int) $match[1] + 1) : 1;

        return 'SUP-'.str_pad((string) $number, 5, '0', STR_PAD_LEFT);
    }
}
