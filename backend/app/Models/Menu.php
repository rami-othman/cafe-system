<?php

namespace App\Models;

use App\Domain\Menu\Enums\MenuStatus;
use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Menu extends Model
{
    use HasTenantScope, SoftDeletes;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['status' => MenuStatus::class];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function sections(): HasMany
    {
        return $this->hasMany(MenuSection::class);
    }

    public function assignments(): HasMany
    {
        return $this->hasMany(MenuAssignment::class);
    }

    public function availabilityRules(): HasMany
    {
        return $this->hasMany(MenuAvailabilityRule::class);
    }
}
