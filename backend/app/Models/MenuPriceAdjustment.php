<?php

namespace App\Models;

use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class MenuPriceAdjustment extends Model
{
    use HasTenantScope;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['summary' => 'array', 'expires_at' => 'datetime', 'applied_at' => 'datetime', 'confirmed_reviewed_results' => 'boolean', 'acknowledged_opposite_direction' => 'boolean'];
    }

    public function items(): HasMany
    {
        return $this->hasMany(MenuPriceAdjustmentItem::class);
    }
}
