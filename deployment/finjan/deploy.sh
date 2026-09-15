#!/usr/bin/env bash
# Finjan repeatable deployment script — updates code to a specific commit/tag.
# Never deploys "latest main" blindly: you must name the revision explicitly.
#
# Usage:
#   sudo bash deployment/finjan/deploy.sh <commit-or-tag>
#
# Example:
#   sudo bash deployment/finjan/deploy.sh 6d4f26145162dd78156f9ceb25cd9edcf260836e

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
load_state

REVISION="${1:-}"
[[ -n "$REVISION" ]] || fatal "Usage: sudo bash deployment/finjan/deploy.sh <exact-commit-or-tag>  (deploying 'latest main' is not supported on purpose)"

cd "${REPO_ROOT}"

log_info "== 1/10: verify clean Git state =="
if [[ -n "$(git status --porcelain)" ]]; then
  fatal "Working tree is not clean. Resolve or stash local changes before deploying:\n$(git status --short)"
fi

log_info "== 2/10: fetch =="
git fetch origin --tags

log_info "== 3/10: resolve and checkout ${REVISION} =="
RESOLVED_SHA="$(git rev-parse "${REVISION}^{commit}" 2>/dev/null)" || fatal "Revision '${REVISION}' does not exist locally or on origin (did you fetch the right remote?)."
git checkout --detach "$RESOLVED_SHA"
log_ok "Checked out ${RESOLVED_SHA}"

PHP_MINOR="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"

log_info "== 4/10: maintenance mode =="
sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" down --secret="$(random_secret 24)" --render="errors::503" || true

cleanup_maintenance() {
  sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" up || true
}
trap cleanup_maintenance EXIT

log_info "== 5/10: composer install =="
sudo -u "$APP_LINUX_USER" composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction --working-dir="${BACKEND_DIR}"

log_info "== 6/10: frontend dependencies + build =="
if [[ -f "${ADMIN_DIR}/package-lock.json" ]]; then
  sudo -u "$APP_LINUX_USER" npm --prefix "${ADMIN_DIR}" ci
else
  sudo -u "$APP_LINUX_USER" npm --prefix "${ADMIN_DIR}" install
fi
[[ -f "${ADMIN_DIR}/.env.production" ]] || cat > "${ADMIN_DIR}/.env.production" <<'EOF'
NEXT_PUBLIC_API_URL=https://api.cafesystemsyria.com/api/super-admin/v1
EOF
sudo -u "$APP_LINUX_USER" npm --prefix "${ADMIN_DIR}" run build
rm -rf "${ADMIN_DIR}/.next/standalone/.next/static" "${ADMIN_DIR}/.next/standalone/public"
cp -r "${ADMIN_DIR}/.next/static" "${ADMIN_DIR}/.next/standalone/.next/static"
[[ -d "${ADMIN_DIR}/public" ]] && cp -r "${ADMIN_DIR}/public" "${ADMIN_DIR}/.next/standalone/public"
chown -R "$APP_LINUX_USER:$APP_LINUX_GROUP" "${ADMIN_DIR}/.next"

log_info "== 7/10: inspect pending migrations =="
PENDING="$(sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" migrate:status 2>/dev/null | grep -c 'Pending' || true)"
if [[ "${PENDING:-0}" -gt 0 ]]; then
  log_warn "${PENDING} pending migration(s) found:"
  sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" migrate:status | grep 'Pending' >&2 || true
  if confirm "Run 'php artisan migrate --force' now? (never migrate:fresh / db:wipe — this only applies forward migrations)"; then
    sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" migrate --force
    log_ok "Migrations applied."
  else
    log_warn "Skipped migrations. The deployed code may not match the database schema until you run them manually."
  fi
else
  log_ok "No pending migrations."
fi

log_info "== 8/10: rebuild Laravel caches =="
chown -R "${APP_LINUX_USER}:${APP_LINUX_GROUP}" "${REPO_ROOT}"
find "${BACKEND_DIR}/storage" "${BACKEND_DIR}/bootstrap/cache" -type d -exec chmod 775 {} \;
find "${BACKEND_DIR}/storage" "${BACKEND_DIR}/bootstrap/cache" -type f -exec chmod 664 {} \;
sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" config:clear
sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" config:cache
sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" view:cache
sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" storage:link || true
# Route caching intentionally skipped — see docker/cloud-entrypoint.sh's own comment
# about the route table not yet being audited for cache compatibility.

log_info "== 9/10: restart services =="
systemctl restart "php${PHP_MINOR}-fpm"
systemctl restart cafe-admin
if grep -q "autostart=true" /etc/supervisor/conf.d/cafe-worker.conf 2>/dev/null; then
  supervisorctl restart cafe-worker:* || true
fi
nginx -t && systemctl reload nginx

log_info "== 10/10: health checks =="
trap - EXIT
sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" up
bash "${SCRIPT_DIR}/health-check.sh" || log_warn "Some health checks failed — review output above before considering this deploy fully verified."

save_state DEPLOYED_COMMIT "$RESOLVED_SHA"
save_state LAST_DEPLOY_AT "$(date -u +%FT%TZ)"
log_ok "Deployed and verified commit ${RESOLVED_SHA}."
