<?php

namespace App\Models;

use App\Domain\Menu\Enums\MenuAuditAction;
use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MenuAuditLog extends Model
{
    use HasTenantScope;

    public const UPDATED_AT = null;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['action' => MenuAuditAction::class, 'before_data' => 'array', 'after_data' => 'array', 'created_at' => 'datetime'];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function menuPublication(): BelongsTo
    {
        return $this->belongsTo(MenuPublication::class);
    }

    public function changedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'changed_by');
    }
}
