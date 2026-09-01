<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use App\Models\Concerns\HasTenantScope;
use App\Services\DefaultTenantRoleService;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

#[Fillable(['tenant_id', 'tenant_role_id', 'name', 'email', 'username', 'normalized_username', 'password', 'role', 'is_active', 'must_change_password'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasFactory, HasTenantScope, Notifiable, SoftDeletes;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_active' => 'boolean',
            'must_change_password' => 'boolean',
        ];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    public function tenantRole(): BelongsTo
    {
        return $this->belongsTo(TenantRole::class);
    }

    public function branches(): BelongsToMany
    {
        return $this->belongsToMany(Branch::class, 'user_branches')->withTimestamps();
    }

    public function apiTokens(): HasMany
    {
        return $this->hasMany(ApiToken::class);
    }

    protected function username(): Attribute
    {
        return Attribute::make(
            set: fn (?string $username): array => [
                'username' => $username === null ? null : trim($username),
                'normalized_username' => $username === null ? null : self::normalizeUsername($username),
            ],
        );
    }

    public function isOwner(): bool
    {
        return $this->effectiveRoleCode() === DefaultTenantRoleService::OWNER;
    }

    public function usesEmailLogin(): bool
    {
        return in_array($this->effectiveRoleCode(), [DefaultTenantRoleService::OWNER, DefaultTenantRoleService::MANAGER], true);
    }

    public function effectiveRoleCode(): string
    {
        if ($this->relationLoaded('tenantRole') ? $this->tenantRole : $this->tenantRole()->first()) {
            return $this->tenantRole->code;
        }

        // Compatibility only for data written before the Phase 2 backfill. New
        // employee-management writes always set tenant_role_id.
        return match ($this->role) {
            'owner' => DefaultTenantRoleService::OWNER,
            'manager' => DefaultTenantRoleService::MANAGER,
            default => DefaultTenantRoleService::EMPLOYEE,
        };
    }

    public static function normalizeUsername(string $username): string
    {
        return mb_strtolower(trim($username));
    }
}
