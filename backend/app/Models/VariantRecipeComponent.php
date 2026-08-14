<?php

namespace App\Models;

use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class VariantRecipeComponent extends Model
{
    use HasTenantScope;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['quantity' => 'decimal:6'];
    }

    public function recipe(): BelongsTo
    {
        return $this->belongsTo(VariantRecipe::class, 'variant_recipe_id');
    }
}
