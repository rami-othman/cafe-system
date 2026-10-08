#!/usr/bin/env bash
# Cafe 6:18 - the ONLY thing the GitHub Actions deploy key may run on the server.
#
# Installed as /usr/local/sbin/cafe618-ci-deploy and wired in /root/.ssh/authorized_keys as:
#   restrict,command="/usr/local/sbin/cafe618-ci-deploy" ssh-ed25519 AAAA... github-actions-cafe618
# so whatever the runner asks for, sshd runs this script and passes the request in SSH_ORIGINAL_COMMAND.
#
# Accepted requests (anything else is refused):
#   staging <40-char commit sha>          deploy that commit to staging (automatic, on every push to main)
#   production <40-char commit sha>       deploy to production - only the commit staging is running right now
#   production staging-head               same, "whatever staging is running"
#
# Paths and URLs come from /etc/cafe618-ci.conf (root-owned, not in git). The deploy itself is the reviewed
# /usr/local/sbin/cafe618-deploy.sh (a copy of deploy-staging.sh): DB backup first, clean worktree, migrations,
# caches, Flutter Web build. A push to the repo cannot change how deploys run until root copies a new version.

set -euo pipefail

die() { printf 'REFUSED: %s\n' "$*" >&2; exit 2; }

CONF=/etc/cafe618-ci.conf
[ -r "$CONF" ] || die "$CONF is missing."
# shellcheck source=/dev/null
. "$CONF"
: "${DEPLOY_SCRIPT:?} ${STAGING_APP_DIR:?} ${STAGING_WEB_DIR:?} ${STAGING_API_BASE_URL:?}"
: "${PRODUCTION_APP_DIR:?} ${PRODUCTION_WEB_DIR:?} ${PRODUCTION_API_BASE_URL:?}"

read -r target sha extra <<<"${SSH_ORIGINAL_COMMAND:-}" || true
[ -z "${extra:-}" ] || die "unexpected extra arguments."

staging_head() { git -C "$STAGING_APP_DIR" rev-parse HEAD; }

case "${target:-}" in
  staging)
    [[ "${sha:-}" =~ ^[0-9a-f]{40}$ ]] || die "staging needs a full 40-character commit sha."
    APP_DIR="$STAGING_APP_DIR"; WEB_DIR="$STAGING_WEB_DIR"; API_BASE_URL="$STAGING_API_BASE_URL"
    HEALTH_URL="${STAGING_HEALTH_URL:-}"
    ;;
  production)
    [ "${sha:-}" = "staging-head" ] && sha="$(staging_head)"
    [[ "${sha:-}" =~ ^[0-9a-f]{40}$ ]] || die "production needs a full commit sha or 'staging-head'."
    # Production only ever receives exactly what is already running (and was checked) on staging.
    [ "$sha" = "$(staging_head)" ] || die "production only accepts the commit staging runs now ($(staging_head)), not $sha."
    APP_DIR="$PRODUCTION_APP_DIR"; WEB_DIR="$PRODUCTION_WEB_DIR"; API_BASE_URL="$PRODUCTION_API_BASE_URL"
    HEALTH_URL="${PRODUCTION_HEALTH_URL:-}"
    ;;
  *)
    die "unknown request '${SSH_ORIGINAL_COMMAND:-}'. Use: staging <sha> | production <sha|staging-head>."
    ;;
esac

# One deploy at a time on this server (staging and production share nginx and PHP-FPM).
exec 9>/run/lock/cafe618-deploy.lock
flock -n 9 || die "another deploy is already running."

LOG_DIR=/var/log/cafe618-deploy
mkdir -p "$LOG_DIR"; chmod 700 "$LOG_DIR"
LOG="$LOG_DIR/$target-$(date -u +%Y%m%dT%H%M%SZ)-${sha:0:12}.log"
echo "==> $target <- $sha (log: $LOG)"

set +e
APP_DIR="$APP_DIR" REF="$sha" ASSUME_YES=1 BUILD_WEB=1 WEB_DIR="$WEB_DIR" API_BASE_URL="$API_BASE_URL" \
  HEALTH_URL="$HEALTH_URL" bash "$DEPLOY_SCRIPT" 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e
[ "$status" -eq 0 ] || { echo "DEPLOY FAILED (exit $status). Log: $LOG"; exit "$status"; }

# The deploy script only prints the health status; here an unexpected code fails the GitHub job so nobody misses it.
# HEALTH_OK_CODES: e.g. "401" for a protected Laravel endpoint (answers 401 only when PHP-FPM + Laravel are up).
if [ -n "$HEALTH_URL" ]; then
  code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 20 "$HEALTH_URL" || true)"
  case " ${HEALTH_OK_CODES:-200} " in
    *" $code "*) echo "Health OK: $HEALTH_URL -> $code" ;;
    *) echo "HEALTH CHECK FAILED: $HEALTH_URL -> HTTP $code (expected ${HEALTH_OK_CODES:-200}). Log: $LOG"; exit 3 ;;
  esac
fi
echo "==> $target is now on $sha"
