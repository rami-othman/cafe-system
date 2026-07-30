<?php

namespace App\Models;

use App\Domain\Menu\Enums\SalesChannel;
use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class MenuAvailabilityRule extends Model
{
    use HasTenantScope, SoftDeletes;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['channel' => SalesChannel::class, 'start_time' => 'datetime:H:i:s', 'end_time' => 'datetime:H:i:s', 'start_date' => 'date', 'end_date' => 'date', 'is_active' => 'boolean'];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function menu(): BelongsTo
    {
        return $this->belongsTo(Menu::class);
    }

    public function branch(): BelongsTo
    {
        return $this->belongsTo(Branch::class);
    }
}
