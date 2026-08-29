<?php

namespace App\Models;

use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ModifierOptionRecipeProfileComponent extends Model
{
    use HasTenantScope;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['quantity' => 'decimal:6'];
    }

    public function profile(): BelongsTo
    {
        return $this->belongsTo(ModifierOptionRecipeProfile::class, 'modifier_option_recipe_profile_id');
    }
}
