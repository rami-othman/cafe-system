#!/usr/bin/env bash
# Cafe System 618 - safe deploy. RUN ON THE SERVER (as root), never locally.
#
#   APP_DIR=/var/www/cafe-system bash deploy-staging.sh
#
# Optional variables:
#   REF=main                      branch/tag/commit to deploy (default: main)
#   SAFETY_DIR=/root/cafe618-safety   where the DB backup is written
#   ASSUME_YES=1                  skip the confirmation before migrating
#   HEALTH_URL=https://IP/api/v1/health   URL checked at the end (optional)
#   BUILD_WEB=1 WEB_DIR=/var/www/cafe18 API_BASE_URL=https://IP/api/v1
#                                 also rebuild and publish Flutter Web (old build kept)
#
# Safety rules: aborts on any error, refuses a dirty worktree, takes and validates a
# database backup BEFORE touching anything, shows pending migrations (--pretend) and asks
# before running them, never uses migrate:fresh / DROP DATABASE.

set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/cafe-system}"
REF="${REF:-main}"
SAFETY_DIR="${SAFETY_DIR:-/root/cafe618-safety}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"

say()  { printf '\n==> %s\n' "$*"; }
fail() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[ -d "$APP_DIR/.git" ] || fail "APP_DIR '$APP_DIR' is not a git checkout."
[ -f "$APP_DIR/backend/.env" ] || fail "$APP_DIR/backend/.env not found."
command -v php >/dev/null      || fail "php not found."
command -v composer >/dev/null || fail "composer not found."
command -v pg_dump >/dev/null  || fail "pg_dump not found."

cd "$APP_DIR"

say "1/8 Checking the worktree is clean"
if [ -n "$(git status --porcelain)" ]; then
  git status --short
  fail "Worktree has local changes. Resolve them first (nothing was changed)."
fi
PREV_COMMIT="$(git rev-parse HEAD)"
echo "Current commit: $PREV_COMMIT"

say "2/8 Database backup (validated)"
env_get() { grep -E "^$1=" backend/.env | tail -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"; }
DB_HOST="$(env_get DB_HOST)"; DB_PORT="$(env_get DB_PORT)"; DB_NAME="$(env_get DB_DATABASE)"
DB_USER="$(env_get DB_USERNAME)"; DB_PASS="$(env_get DB_PASSWORD)"
[ -n "$DB_NAME" ] && [ -n "$DB_USER" ] || fail "DB_DATABASE / DB_USERNAME missing in backend/.env (DB_URL is not supported by this script)."
mkdir -p "$SAFETY_DIR"
chmod 700 "$SAFETY_DIR"
DUMP="$SAFETY_DIR/deploy-$TS-$DB_NAME.dump"
PGPASSWORD="$DB_PASS" pg_dump -Fc -h "${DB_HOST:-127.0.0.1}" -p "${DB_PORT:-5432}" -U "$DB_USER" -d "$DB_NAME" -f "$DUMP"
pg_restore -l "$DUMP" >/dev/null || fail "Backup file failed validation: $DUMP"
echo "Backup OK: $DUMP ($(du -h "$DUMP" | cut -f1))"

say "3/8 Fetching code ($REF)"
git fetch origin --tags --prune
git checkout "$REF"
if git show-ref --verify --quiet "refs/remotes/origin/$REF"; then
  git merge --ff-only "origin/$REF"
fi
NEW_COMMIT="$(git rev-parse HEAD)"
echo "Deploying: $NEW_COMMIT"
echo "Changes since $PREV_COMMIT:"
git log --oneline "$PREV_COMMIT..$NEW_COMMIT" | head -50 || true

say "4/8 Composer (production dependencies)"
cd "$APP_DIR/backend"
composer install --no-dev --optimize-autoloader --no-interaction

say "5/8 Pending migrations (nothing is applied yet)"
php artisan migrate:status | grep -i "pending" || echo "(no pending migrations)"
php artisan migrate --pretend --force | head -200

if [ "${ASSUME_YES:-0}" != "1" ]; then
  printf '\nApply these migrations? Type "yes" to continue: '
  read -r answer
  [ "$answer" = "yes" ] || fail "Stopped before migrating. Code is at $NEW_COMMIT; to go back: cd $APP_DIR && git checkout $PREV_COMMIT"
fi

say "6/8 Applying migrations"
if ! php artisan migrate --force; then
  echo "Migration failed. Database backup: $DUMP"
  echo "Code rollback: cd $APP_DIR && git checkout $PREV_COMMIT && cd backend && composer install --no-dev"
  echo "Do NOT restore the dump blindly if new business records were written meanwhile."
  exit 1
fi

say "7/8 Caches and PHP-FPM"
php artisan config:cache
php artisan view:cache
FPM="$(systemctl list-units --type=service --no-legend 'php*-fpm.service' 2>/dev/null | awk '{print $1}' | head -1 || true)"
if [ -n "$FPM" ]; then systemctl reload "$FPM" && echo "Reloaded $FPM"; else echo "php-fpm service not found - reload it manually"; fi

if [ "${BUILD_WEB:-0}" = "1" ]; then
  say "7b Flutter Web build"
  [ -n "${WEB_DIR:-}" ] && [ -n "${API_BASE_URL:-}" ] || fail "BUILD_WEB=1 needs WEB_DIR and API_BASE_URL."
  FLUTTER_BIN="$(ls -d /opt/flutter-*/bin 2>/dev/null | tail -1 || true)"
  [ -n "$FLUTTER_BIN" ] && export PATH="$FLUTTER_BIN:$PATH"
  command -v flutter >/dev/null || fail "flutter not found."
  cd "$APP_DIR/windows_application"
  flutter pub get
  flutter build web --release --dart-define="API_BASE_URL=$API_BASE_URL" --base-href "${BASE_HREF:-/cafe18/}"
  [ -f build/web/index.html ] || fail "Web build did not produce build/web/index.html."
  if [ -d "$WEB_DIR" ]; then cp -a "$WEB_DIR" "${WEB_DIR}-old-$TS"; fi
  mkdir -p "$WEB_DIR"
  cp -a build/web/. "$WEB_DIR/"
  echo "Web published to $WEB_DIR (previous copy: ${WEB_DIR}-old-$TS). Ask users to hard-refresh (Ctrl+Shift+R)."
fi

say "8/8 Health check"
if [ -n "${HEALTH_URL:-}" ]; then
  code="$(curl -sk -o /dev/null -w '%{http_code}' "$HEALTH_URL" || true)"
  echo "$HEALTH_URL -> HTTP $code"
else
  echo "(set HEALTH_URL to check an endpoint automatically)"
fi

cat <<EOF

Done.
  Previous commit : $PREV_COMMIT
  Deployed commit : $NEW_COMMIT
  DB backup       : $DUMP
Smoke test: cash sale, delivery cash sale with a company, delivery on company account,
shift close, purchase invoice.
EOF
