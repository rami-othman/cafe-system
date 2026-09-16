<?php

namespace App\Models;

use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CustomerPhone extends Model
{
    use HasTenantScope;

    protected $table = 'customer_phones';

    protected $fillable = [
        'tenant_id', 'customer_id', 'raw_number', 'normalized_number', 'type', 'is_primary', 'validation_status',
    ];

    protected $casts = ['is_primary' => 'boolean'];

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }
}
