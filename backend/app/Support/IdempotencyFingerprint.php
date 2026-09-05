<?php

namespace App\Support;

use JsonException;

/**
 * Produces a stable hash of the validated business payload associated with
 * an idempotency key. A key may be replayed only for the same operation;
 * returning a prior result for a changed request would hide a financial
 * conflict rather than make the operation safe.
 */
final class IdempotencyFingerprint
{
    public static function from(array $payload): string
    {
        unset($payload['idempotencyKey']);

        try {
            return hash('sha256', json_encode(self::canonicalize($payload), JSON_THROW_ON_ERROR | JSON_PRESERVE_ZERO_FRACTION));
        } catch (JsonException) {
            // All callers use Laravel-validated scalar/array data. This is a
            // defensive failure mode should an unsupported type reach here.
            throw new \LogicException('Unable to fingerprint idempotency payload.');
        }
    }

    private static function canonicalize(mixed $value): mixed
    {
        if (is_array($value)) {
            if (array_is_list($value)) {
                return array_map(self::canonicalize(...), $value);
            }

            ksort($value, SORT_STRING);
            foreach ($value as $key => $nested) {
                $value[$key] = self::canonicalize($nested);
            }

            return $value;
        }

        if (is_int($value) || is_float($value)) {
            return self::normaliseNumber((string) $value);
        }

        if (is_string($value) && preg_match('/^-?\d+(?:\.\d+)?$/', $value)) {
            return self::normaliseNumber($value);
        }

        return $value;
    }

    private static function normaliseNumber(string $value): string
    {
        $normalised = rtrim(rtrim(number_format((float) $value, 12, '.', ''), '0'), '.');

        return $normalised === '-0' ? '0' : $normalised;
    }
}
