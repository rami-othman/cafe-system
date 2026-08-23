<?php

namespace App\Services;

use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;

class OperationalAuditService
{
    public function record(Request $request, int $tenantId, string $action, string $entityType, int $entityId, array $before = [], array $after = [], ?int $branchId = null, ?int $actorId = null): void
    {
        DB::table('activity_logs')->insert([
            'tenant_id' => $tenantId,
            'branch_id' => $branchId,
            'user_id' => $actorId,
            'action' => $action,
            'entity_type' => $entityType,
            'entity_id' => $entityId,
            'description' => $this->description($action),
            'ip_address' => $request->ip(),
            'before_state' => json_encode($this->redact($before)),
            'after_state' => json_encode($this->redact($after)),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function description(string $action): string
    {
        return str_replace('.', ' ', $action);
    }

    private function redact(array $state): array
    {
        foreach (['password', 'token', 'token_hash', 'remember_token'] as $key) {
            if (Arr::has($state, $key)) {
                Arr::set($state, $key, '[redacted]');
            }
        }

        return $state;
    }
}
