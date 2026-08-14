<?php

namespace App\Models;

use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ModifierOptionRecipeProfile extends Model
{
    use HasTenantScope;

    protected $guarded = [];

    public function components(): HasMany
    {
        return $this->hasMany(ModifierOptionRecipeProfileComponent::class);
    }
}
