<?php

namespace App\Services\Catalog;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Models\MenuAuditLog;
use Illuminate\Database\Eloquent\Model;

class CatalogAuditService
{
    public function log(int $tenantId, Model|string $entity, MenuAuditAction $action, ?array $before = null, ?array $after = null): void
    {
        $model = $entity instanceof Model ? $entity : null;
        MenuAuditLog::query()->create(['tenant_id' => $tenantId, 'entity_type' => $model ? $model::class : $entity, 'entity_id' => $model?->getKey(), 'action' => $action, 'before_data' => $before, 'after_data' => $after]);
    }
}
