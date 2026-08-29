<?php

namespace App\Models;

use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;

class ProductVariant extends Model
{
    use HasTenantScope, SoftDeletes;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['base_price' => 'decimal:2', 'cost_price' => 'decimal:2', 'is_default' => 'boolean', 'is_active' => 'boolean'];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function priceOverrides(): HasMany
    {
        return $this->hasMany(ProductVariantPriceOverride::class);
    }

    public function availabilityRules(): HasMany
    {
        return $this->hasMany(ProductAvailabilityRule::class);
    }

    public function operationalAvailabilities(): HasMany
    {
        return $this->hasMany(ProductVariantOperationalAvailability::class);
    }

    public function recipe(): HasOne
    {
        return $this->hasOne(VariantRecipe::class);
    }
}
