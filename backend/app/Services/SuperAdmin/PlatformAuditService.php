<?php

namespace App\Services\SuperAdmin;

use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;

class PlatformAuditService
{
    public function record(Request $request, string $action, ?string $targetType = null, ?int $targetId = null, ?int $tenantId = null, array $before = [], array $after = [], ?string $reason = null): void
    {
        DB::table('platform_audit_logs')->insert([
            'actor_id' => $request->user()?->id,
            'action' => $action,
            'target_type' => $targetType,
            'target_id' => $targetId,
            'tenant_id' => $tenantId,
            'before_state' => json_encode($this->redact($before)),
            'after_state' => json_encode($this->redact($after)),
            'reason' => $reason,
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'request_id' => $request->header('X-Request-Id'),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
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
