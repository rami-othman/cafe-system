<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * The Flutter client is bilingual (ar/en, user-selectable) — the backend
 * must not hardcode Arabic for everyone. The client signals its active UI
 * language through the dedicated `X-App-Locale` header, which only the app
 * itself ever sets deliberately (via AppLocaleCubit/CurrentLocale).
 *
 * `Accept-Language` is deliberately NOT trusted here: it is an ambient
 * header every HTTP client (browsers, Symfony's test client, curl with a
 * default profile, etc.) may set on its own without the application ever
 * choosing a language, which would silently override the intended Arabic
 * default. `X-App-Locale` missing/unsupported falls back to the configured
 * default locale (config/app.php, APP_LOCALE).
 */
class SetLocaleFromRequest
{
    private const SUPPORTED = ['ar', 'en'];

    public function handle(Request $request, Closure $next): Response
    {
        $requested = strtolower(substr((string) $request->header('X-App-Locale', ''), 0, 2));
        if (in_array($requested, self::SUPPORTED, true)) {
            app()->setLocale($requested);
        }

        return $next($request);
    }
}
