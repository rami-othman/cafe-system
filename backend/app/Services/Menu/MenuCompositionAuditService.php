<?php

namespace App\Services\Menu;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Models\MenuAuditLog;
use Illuminate\Database\Eloquent\Model;

class MenuCompositionAuditService
{
    public function log(int $tenantId, Model|string $entity, MenuAuditAction $action, ?array $before = null, ?array $after = null): void
    {
        $model = $entity instanceof Model ? $entity : null;
        MenuAuditLog::query()->create([
            'tenant_id' => $tenantId,
            'menu_publication_id' => null,
            'entity_type' => $model ? $model::class : $entity,
            'entity_id' => $model?->getKey(),
            'action' => $action,
            'before_data' => $before,
            'after_data' => $after,
            'changed_by' => $this->actorId(),
        ]);
    }

    private function actorId(): ?int
    {
        $user = request()->attributes->get('auth_user');

        return $user ? (int) $user->id : null;
    }
}
