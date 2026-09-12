<?php

namespace App\Models;

use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Customer extends Model
{
    use HasTenantScope, SoftDeletes;

    protected $table = 'customers';

    protected $fillable = [
        'tenant_id', 'name', 'customer_number', 'normalized_name', 'phone', 'email',
        'birth_date', 'notes', 'total_spent', 'visits_count', 'is_active',
    ];

    protected $casts = [
        'birth_date' => 'date:Y-m-d',
        'total_spent' => 'decimal:2',
        'visits_count' => 'integer',
        'is_active' => 'boolean',
    ];

    public function phones(): HasMany
    {
        return $this->hasMany(CustomerPhone::class);
    }

    public function groups(): BelongsToMany
    {
        return $this->belongsToMany(CustomerGroup::class, 'customer_group_memberships', 'customer_id', 'customer_group_id')
            ->withPivot('tenant_id')
            ->withTimestamps();
    }

    public function lifecycleState(): string
    {
        return $this->deleted_at !== null ? 'archived' : ($this->is_active ? 'active' : 'inactive');
    }
}
