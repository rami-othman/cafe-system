<?php

namespace App\Models;

use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class CustomerGroup extends Model
{
    use HasTenantScope, SoftDeletes;

    protected $table = 'customer_groups';

    protected $fillable = ['tenant_id', 'name', 'normalized_name', 'is_active'];

    protected $casts = ['is_active' => 'boolean'];

    public function customers(): BelongsToMany
    {
        return $this->belongsToMany(Customer::class, 'customer_group_memberships', 'customer_group_id', 'customer_id')
            ->withPivot('tenant_id')
            ->withTimestamps();
    }

    public function lifecycleState(): string
    {
        return $this->deleted_at !== null ? 'archived' : ($this->is_active ? 'active' : 'inactive');
    }
}
