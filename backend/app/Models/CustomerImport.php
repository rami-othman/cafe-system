<?php

namespace App\Models;

use App\Models\Concerns\HasTenantScope;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Model;

class CustomerImport extends Model
{
    use HasTenantScope;

    protected $table = 'customer_imports';

    protected $fillable = [
        'tenant_id', 'actor_user_id', 'original_filename', 'file_fingerprint',
        'detected_encoding', 'detected_delimiter', 'status', 'create_missing_groups',
        'total_rows', 'ready_rows', 'warning_rows', 'rejected_rows',
        'duplicate_candidates', 'processed_rows', 'created_customers',
        'skipped_customers', 'failed_rows', 'created_groups', 'created_memberships',
        'group_summary', 'started_at', 'completed_at', 'failure_code',
    ];

    protected $casts = [
        'create_missing_groups' => 'boolean',
        'group_summary' => 'array',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
    ];

    public function rows(): HasMany
    {
        return $this->hasMany(CustomerImportRow::class);
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_user_id');
    }
}
