<?php

namespace App\Models;

use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class ReceiptTemplate extends Model
{
    use HasTenantScope, SoftDeletes;

    public const SECTIONS = ['header', 'order_info', 'items', 'totals', 'payment', 'footer'];

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'header' => 'array',
            'order_info' => 'array',
            'items' => 'array',
            'totals' => 'array',
            'payment' => 'array',
            'footer' => 'array',
            'section_order' => 'array',
        ];
    }

    public function branch(): BelongsTo
    {
        return $this->belongsTo(Branch::class);
    }
}
