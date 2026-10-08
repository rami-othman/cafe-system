<?php

namespace App\Services;

use Closure;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Generates short, typeable coupon codes for NEW discounts only. Existing and
 * manually entered codes are never rewritten or length-limited by this class.
 *
 * The check here only avoids obvious collisions: the partial unique index
 * discounts_tenant_lower_code_unique (tenant_id, LOWER(code)) stays the final
 * authority when the discount is actually saved.
 */
final class CouponCodeGenerator
{
    public const LENGTH = 5;

    /** Uppercase letters and digits without the ambiguous O, 0, I and 1. */
    public const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    public const MAX_ATTEMPTS = 16;

    /** @param  (Closure(int, int): int)|null  $randomInt  deterministic source for tests */
    public function __construct(private readonly ?Closure $randomInt = null) {}

    public function generate(int $tenantId): string
    {
        for ($attempt = 0; $attempt < self::MAX_ATTEMPTS; $attempt++) {
            $code = $this->candidate();
            if (! $this->exists($tenantId, $code)) {
                return $code;
            }
        }

        throw ValidationException::withMessages(['code' => 'A unique coupon code could not be generated. Please retry.']);
    }

    public function candidate(): string
    {
        $random = $this->randomInt ?? random_int(...);
        $code = '';
        for ($index = 0; $index < self::LENGTH; $index++) {
            $code .= self::ALPHABET[$random(0, strlen(self::ALPHABET) - 1)];
        }

        return $code;
    }

    private function exists(int $tenantId, string $code): bool
    {
        return DB::table('discounts')->where('tenant_id', $tenantId)->whereNull('deleted_at')
            ->whereRaw('LOWER(code) = ?', [strtolower($code)])->exists();
    }
}
