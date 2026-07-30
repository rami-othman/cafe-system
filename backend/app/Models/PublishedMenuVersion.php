<?php

namespace App\Models;

use App\Domain\Menu\Enums\PublishedMenuVersionStatus;
use App\Domain\Menu\Enums\SalesChannel;
use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PublishedMenuVersion extends Model
{
    use HasTenantScope;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['channel' => SalesChannel::class, 'status' => PublishedMenuVersionStatus::class, 'payload_json' => 'array', 'published_at' => 'datetime'];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function menuPublication(): BelongsTo
    {
        return $this->belongsTo(MenuPublication::class);
    }

    public function branch(): BelongsTo
    {
        return $this->belongsTo(Branch::class);
    }
}
