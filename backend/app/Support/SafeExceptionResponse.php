<?php

namespace App\Support;

use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Throwable;

/**
 * Decides whether an unexpected exception's real message is safe to leak to
 * an API client. Exceptions that already render their own safe response
 * (HTTP exceptions, auth failures, validation, 404s) are left alone; genuine
 * unexpected failures (SQL errors, type errors, ...) get a generic Arabic
 * message instead of their raw text — the original exception is still
 * logged normally by Laravel, this only changes the response body.
 */
final class SafeExceptionResponse
{
    public const GENERIC_MESSAGE = 'حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى.';

    public const GENERIC_CODE = 'UNEXPECTED_ERROR';

    public static function shouldReplace(Throwable $exception, bool $debug): bool
    {
        if ($debug) {
            return false;
        }

        return ! (
            $exception instanceof HttpExceptionInterface
            || $exception instanceof AuthenticationException
            || $exception instanceof AuthorizationException
            || $exception instanceof ModelNotFoundException
            || $exception instanceof ValidationException
        );
    }

    /** @return array{message: string, code: string} */
    public static function body(): array
    {
        return ['message' => self::GENERIC_MESSAGE, 'code' => self::GENERIC_CODE];
    }
}
