<?php

namespace App\Models;

use App\Domain\Menu\Enums\SalesChannel;
use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class ProductVariantPriceOverride extends Model
{
    use HasTenantScope, SoftDeletes;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['channel' => SalesChannel::class, 'override_price' => 'decimal:2', 'is_active' => 'boolean'];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function productVariant(): BelongsTo
    {
        return $this->belongsTo(ProductVariant::class);
    }

    public function branch(): BelongsTo
    {
        return $this->belongsTo(Branch::class);
    }
}
