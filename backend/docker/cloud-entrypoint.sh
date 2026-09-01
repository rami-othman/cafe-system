#!/bin/sh

set -eu

PORT="${PORT:-8000}"

case "$PORT" in
    *[!0-9]*|'')
        echo "PORT must be a numeric TCP port." >&2
        exit 1
        ;;
esac

if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "PORT must be between 1 and 65535." >&2
    exit 1
fi

if [ -z "${APP_KEY:-}" ]; then
    echo "APP_KEY is required and must be supplied as a stable runtime environment variable." >&2
    exit 1
fi

if [ "${APP_ENV:-production}" = "staging" ] || [ "${APP_ENV:-production}" = "production" ]; then
    if [ -z "${DB_CONNECTION:-}" ]; then
        echo "DB_CONNECTION is required for staging/production; no local or SQLite fallback is available." >&2
        exit 1
    fi

    if [ "${DB_CONNECTION}" = "pgsql" ] && [ -z "${DB_URL:-}" ] \
        && { [ -z "${DB_HOST:-}" ] || [ -z "${DB_DATABASE:-}" ] || [ -z "${DB_USERNAME:-}" ] || [ -z "${DB_PASSWORD:-}" ]; }; then
        echo "PostgreSQL needs DB_URL or DB_HOST, DB_DATABASE, DB_USERNAME, and DB_PASSWORD." >&2
        exit 1
    fi
fi

mkdir -p storage/app/private storage/app/public storage/framework/cache/data storage/framework/sessions storage/framework/testing storage/framework/views storage/logs bootstrap/cache

# Configuration is cached only after all runtime variables have been supplied.
# Route caching is deliberately omitted: API correctness is preferred until the
# large route table has been explicitly audited for cache compatibility.
php artisan config:clear
php artisan config:cache
php artisan view:cache

if [ "${RUN_MIGRATIONS:-false}" = "true" ]; then
    php artisan migrate --force
fi

exec "$@" --port="$PORT"
