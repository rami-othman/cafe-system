<?php

namespace App\Models;

use App\Domain\Menu\Enums\MenuPublicationStatus;
use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class MenuPublication extends Model
{
    use HasTenantScope;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['status' => MenuPublicationStatus::class, 'change_summary' => 'array', 'validation_result' => 'array', 'published_at' => 'datetime'];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function publishedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'published_by');
    }

    public function sourcePublication(): BelongsTo
    {
        return $this->belongsTo(self::class, 'source_publication_id');
    }

    public function derivedPublications(): HasMany
    {
        return $this->hasMany(self::class, 'source_publication_id');
    }

    public function publishedMenuVersions(): HasMany
    {
        return $this->hasMany(PublishedMenuVersion::class);
    }

    public function auditLogs(): HasMany
    {
        return $this->hasMany(MenuAuditLog::class);
    }
}
