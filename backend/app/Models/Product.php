<?php

namespace App\Models;

use App\Domain\Menu\Enums\ProductType;
use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;

class Product extends Model
{
    use HasTenantScope, SoftDeletes;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['product_type' => ProductType::class, 'price' => 'decimal:2', 'cost_price' => 'decimal:2', 'is_active' => 'boolean', 'is_stock_tracked' => 'boolean'];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class)->withTrashed();
    }

    public function reportingCategory(): BelongsTo
    {
        return $this->belongsTo(ReportingCategory::class)->withTrashed();
    }

    public function kitchenStation(): BelongsTo
    {
        return $this->belongsTo(KitchenStation::class)->withTrashed();
    }

    public function variants(): HasMany
    {
        return $this->hasMany(ProductVariant::class);
    }

    public function defaultVariant(): HasOne
    {
        return $this->hasOne(ProductVariant::class)->where('is_default', true);
    }

    public function modifierGroups(): BelongsToMany
    {
        return $this->belongsToMany(ModifierGroup::class, 'product_modifier_group')->withPivot(['tenant_id', 'sort_order', 'is_required_override', 'min_selections_override', 'max_selections_override', 'allow_quantity_override'])->withTimestamps();
    }

    public function menuItemPlacements(): HasMany
    {
        return $this->hasMany(MenuItemPlacement::class);
    }

    public function availabilityRules(): HasMany
    {
        return $this->hasMany(ProductAvailabilityRule::class);
    }

    public function operationalAvailabilities(): HasMany
    {
        return $this->hasMany(ProductOperationalAvailability::class);
    }
}
