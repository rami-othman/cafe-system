<?php

namespace App\Models;

use App\Domain\Menu\Enums\ModifierGroupType;
use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class ModifierGroup extends Model
{
    use HasTenantScope, SoftDeletes;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['group_type' => ModifierGroupType::class, 'is_required' => 'boolean', 'allow_quantity' => 'boolean', 'is_active' => 'boolean'];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function options(): HasMany
    {
        return $this->hasMany(ModifierOption::class);
    }

    public function optionPreview(): HasMany
    {
        return $this->hasMany(ModifierOption::class);
    }

    public function products(): BelongsToMany
    {
        return $this->belongsToMany(Product::class, 'product_modifier_group')->withPivot(['tenant_id', 'sort_order', 'is_required_override', 'min_selections_override', 'max_selections_override', 'allow_quantity_override'])->withTimestamps();
    }
}
