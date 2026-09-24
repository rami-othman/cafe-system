<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * The Flutter client is bilingual (ar/en, user-selectable) — the backend
 * must not hardcode Arabic for everyone. The client sends its active UI
 * language via Accept-Language; unset/unsupported falls back to the
 * configured default locale (config/app.php).
 */
class SetLocaleFromRequest
{
    private const SUPPORTED = ['ar', 'en'];

    public function handle(Request $request, Closure $next): Response
    {
        $requested = strtolower(substr((string) $request->header('Accept-Language', ''), 0, 2));
        if (in_array($requested, self::SUPPORTED, true)) {
            app()->setLocale($requested);
        }

        return $next($request);
    }
}
