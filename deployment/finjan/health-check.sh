#!/usr/bin/env bash
# Finjan health check. Exits non-zero if production looks unhealthy.
# Usage: sudo bash deployment/finjan/health-check.sh [--quiet]

set -uo pipefail  # deliberately not -e: we want to run every check and report all failures
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# common.sh enables `set -e`; this script's whole point is to run every check
# even when some fail, so relax that back for the remainder of this file.
set +e

FAILURES=0
check() {
  # check "description" -- command...
  local desc="$1"; shift
  if "$@" >/tmp/cafe618-healthcheck.$$ 2>&1; then
    log_ok "$desc"
  else
    log_err "$desc"
    sed 's/^/       /' /tmp/cafe618-healthcheck.$$ >&2
    FAILURES=$((FAILURES + 1))
  fi
  rm -f /tmp/cafe618-healthcheck.$$
}

load_state
PHP_MINOR="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "unknown")"

echo "== Git commit =="
if [[ -d "${REPO_ROOT}/.git" ]]; then
  ACTUAL_COMMIT="$(cd "${REPO_ROOT}" && git rev-parse HEAD)"
  log_info "Deployed commit: ${ACTUAL_COMMIT}"
  if [[ -n "${DEPLOYED_COMMIT:-}" && "${ACTUAL_COMMIT}" != "${DEPLOYED_COMMIT}" ]]; then
    log_warn "This differs from the last commit install.sh/deploy.sh recorded (${DEPLOYED_COMMIT})."
  fi
else
  log_warn "No .git directory at ${REPO_ROOT} — cannot verify deployed commit."
fi

echo "== System services =="
check "php${PHP_MINOR}-fpm is active"     systemctl is-active --quiet "php${PHP_MINOR}-fpm"
check "nginx is active"                   systemctl is-active --quiet nginx
check "postgresql is active"              systemctl is-active --quiet postgresql
check "cafe-admin (Next.js) is active"    systemctl is-active --quiet cafe-admin
check "cron is active"                    systemctl is-active --quiet cron

echo "== Laravel =="
check "Laravel boots (artisan --version)" sudo -u "${APP_LINUX_USER}" php "${BACKEND_DIR}/artisan" --version
check "backend/.env exists"               test -f "${BACKEND_DIR}/.env"

echo "== Database connectivity =="
check "PostgreSQL accepts local connections" sudo -u postgres psql -tAc "SELECT 1" -d postgres
check "Laravel can reach its database"       sudo -u "${APP_LINUX_USER}" php "${BACKEND_DIR}/artisan" db:show

echo "== Queue / scheduler =="
if [[ -f /etc/supervisor/conf.d/cafe-worker.conf ]] && grep -q "autostart=true" /etc/supervisor/conf.d/cafe-worker.conf; then
  check "queue worker running" supervisorctl status cafe-worker:* | grep -q RUNNING
else
  log_info "Queue worker is intentionally not running (QUEUE_CONNECTION=sync, no jobs in codebase — see FINDINGS.md)."
fi
if crontab -u "${APP_LINUX_USER}" -l 2>/dev/null | grep -q "artisan schedule:run"; then
  log_ok "Scheduler cron entry installed (currently a documented no-op — no scheduled commands registered in the app)."
else
  log_err "Scheduler cron entry missing for ${APP_LINUX_USER}."
  FAILURES=$((FAILURES + 1))
fi

echo "== Nginx =="
check "nginx config is valid" nginx -t

echo "== HTTP/HTTPS =="
API_CODE="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/up -H 'Host: api.cafesystemsyria.com' || echo 000)"
[[ "$API_CODE" == "200" ]] && log_ok "Laravel /up health endpoint responds 200 (HTTP)" || { log_err "Laravel /up returned HTTP ${API_CODE}"; FAILURES=$((FAILURES + 1)); }

ADMIN_CODE="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3000/ || echo 000)"
[[ "$ADMIN_CODE" =~ ^(200|307|308)$ ]] && log_ok "Next.js Super Admin responds on 127.0.0.1:3000 (HTTP ${ADMIN_CODE})" || { log_err "Next.js Super Admin returned HTTP ${ADMIN_CODE} on 127.0.0.1:3000"; FAILURES=$((FAILURES + 1)); }

for domain in api.cafesystemsyria.com admin.cafesystemsyria.com; do
  if [[ -f "/etc/letsencrypt/live/${domain}/fullchain.pem" ]]; then
    EXPIRY="$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/${domain}/fullchain.pem" 2>/dev/null | cut -d= -f2)"
    log_ok "SSL certificate present for ${domain} (expires: ${EXPIRY:-unknown})"
    HTTPS_CODE="$(curl -s -o /dev/null -w '%{http_code}' "https://${domain}/" || echo 000)"
    [[ "$HTTPS_CODE" =~ ^(200|301|302|307|308)$ ]] && log_ok "https://${domain}/ responds (HTTP ${HTTPS_CODE})" || log_warn "https://${domain}/ returned HTTP ${HTTPS_CODE} — check DNS/firewall from outside this VPS."
  else
    log_warn "No SSL certificate yet for ${domain} — expected until DNS points here and install.sh's Certbot step runs."
  fi
done

echo "== Redirect: HTTP -> HTTPS =="
for domain in api.cafesystemsyria.com admin.cafesystemsyria.com; do
  if [[ -f "/etc/letsencrypt/live/${domain}/fullchain.pem" ]]; then
    REDIR="$(curl -s -o /dev/null -w '%{http_code}' "http://${domain}/" || echo 000)"
    [[ "$REDIR" =~ ^(301|308)$ ]] && log_ok "${domain}: HTTP redirects to HTTPS (${REDIR})" || log_warn "${domain}: expected a 301/308 redirect, got ${REDIR}."
  fi
done

echo "== Firewall =="
if command -v ufw >/dev/null 2>&1; then
  UFW_OUT="$(ufw status 2>/dev/null)"
  echo "$UFW_OUT" | grep -q "Status: active" && log_ok "UFW is active" || { log_err "UFW is not active"; FAILURES=$((FAILURES + 1)); }
  echo "$UFW_OUT" | grep -qE "5432.*DENY|5432.*(deny|DENY)" && log_ok "Port 5432 is not publicly allowed" || log_warn "Could not confirm 5432 is denied — check 'ufw status' manually."
  echo "$UFW_OUT" | grep -qE "3000.*(DENY|deny)" && log_ok "Port 3000 is not publicly allowed" || log_warn "Could not confirm 3000 is denied — check 'ufw status' manually."
else
  log_warn "ufw not installed — cannot verify firewall state."
fi

echo "== Listening ports (should NOT show 0.0.0.0/:: for 5432 or 3000) =="
PORT_LINES="$(ss -tulpn 2>/dev/null | grep -E ':5432|:3000')"
if [[ -z "$PORT_LINES" ]]; then
  log_ok "Nothing listening on 5432/3000 at all (fine — Postgres may use a unix socket, Next.js binds 127.0.0.1)."
else
  while IFS= read -r line; do
    if echo "$line" | grep -qE '0\.0\.0\.0:(5432|3000)|\*:(5432|3000)|:::(5432|3000)'; then
      log_err "Port exposed beyond localhost: $line"
      FAILURES=$((FAILURES + 1))
    else
      log_ok "Port bound to loopback only: $line"
    fi
  done <<< "$PORT_LINES"
fi

echo "== Disk / memory =="
DISK_USED_PCT="$(df -P "${REPO_ROOT}" | tail -1 | awk '{print $5}' | tr -d '%')"
if [[ "$DISK_USED_PCT" -lt 85 ]]; then log_ok "Disk usage: ${DISK_USED_PCT}%"; else log_warn "Disk usage high: ${DISK_USED_PCT}%"; fi
free -h | sed -n '1,2p' | sed 's/^/  /'

echo
if [[ "$FAILURES" -eq 0 ]]; then
  log_ok "All health checks passed."
  exit 0
else
  log_err "${FAILURES} health check(s) failed."
  exit 1
fi
