<?php

namespace App\Domain\Manufacturing;

use Illuminate\Support\Facades\DB;

/** Mirrors CatalogAuditService/MenuAuditLog — no generic cross-module audit trail exists yet to extend instead. */
final class ManufacturingAuditService
{
    public function log(int $tenantId, string $entityType, int $entityId, string $action, ?array $before = null, ?array $after = null, ?int $actorId = null): void
    {
        DB::table('manufacturing_audit_logs')->insert([
            'tenant_id' => $tenantId,
            'entity_type' => $entityType,
            'entity_id' => $entityId,
            'action' => $action,
            'before_data' => $before !== null ? json_encode($before) : null,
            'after_data' => $after !== null ? json_encode($after) : null,
            'changed_by' => $actorId,
            'created_at' => now(),
        ]);
    }
}
