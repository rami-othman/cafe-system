<?php

namespace App\Models;

use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Model;

class CustomerImportRow extends Model
{
    use HasTenantScope;

    protected $table = 'customer_import_rows';

    protected $fillable = [
        'tenant_id', 'customer_import_id', 'source_row_number',
        'legacy_customer_number', 'legacy_account_code', 'source_name',
        'normalized_name', 'source_phone_one', 'source_mobile', 'source_group',
        'parsed_payload', 'classification', 'status', 'warning_codes',
        'error_codes', 'matched_customer_id', 'created_customer_id',
        'created_group_id', 'membership_created',
    ];

    protected $casts = [
        'parsed_payload' => 'array',
        'warning_codes' => 'array',
        'error_codes' => 'array',
        'membership_created' => 'boolean',
    ];

    public function import(): BelongsTo
    {
        return $this->belongsTo(CustomerImport::class, 'customer_import_id');
    }
}
