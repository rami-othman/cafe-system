#!/usr/bin/env bash
# Finjan DATABASE RESTORE from a backup.sh dump.
#
# IMPORTANT DISTINCTION (see also rollback.sh):
#   DATABASE RESTORE (this script)  = replace the live database with an older dump.
#   CODE ROLLBACK (rollback.sh)     = git checkout an older commit.
# Restoring the database is destructive to whatever is in the database RIGHT
# NOW. This script always takes a fresh "pre-restore" safety dump first and
# never runs without an explicit typed confirmation.
#
# Usage:
#   sudo bash deployment/finjan/restore-backup.sh /var/backups/cafe618/daily/db-20260101T000000Z.dump

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
load_state

DUMP_FILE="${1:-}"
[[ -n "$DUMP_FILE" && -f "$DUMP_FILE" ]] || fatal "Usage: $0 /path/to/db-<timestamp>.dump   (list available dumps: find ${BACKUP_ROOT} -name 'db-*.dump')"

DB_NAME="${DB_NAME:-cafe618_production}"

log_warn "About to RESTORE database '${DB_NAME}' from: ${DUMP_FILE}"
log_warn "Everything currently in '${DB_NAME}' will be REPLACED."
sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" migrate:status >/dev/null 2>&1 && \
  log_info "Current row counts (for your reference before restoring):" && \
  for t in orders products tenants; do
    EXISTS="$(sudo -u postgres psql -d "$DB_NAME" -tAc "SELECT to_regclass('public.${t}')" 2>/dev/null || true)"
    [[ -n "$(echo "$EXISTS" | tr -d '[:space:]')" ]] && sudo -u postgres psql -d "$DB_NAME" -c "SELECT '${t}' AS table_name, count(*) FROM ${t};" 2>/dev/null || true
  done

echo
if ! confirm "Type-confirm: take a safety dump of the CURRENT database, then OVERWRITE it with ${DUMP_FILE}"; then
  fatal "Aborted by operator. Nothing was touched."
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
SAFETY_DUMP="${BACKUP_ROOT}/pre-restore-safety-${TS}.dump"
mkdir -p "$BACKUP_ROOT"
log_info "Taking safety dump of the current database before restoring..."
sudo -u postgres pg_dump -Fc -d "$DB_NAME" -f "$SAFETY_DUMP"
chmod 600 "$SAFETY_DUMP"
log_ok "Safety dump: ${SAFETY_DUMP}"

log_info "Putting Laravel into maintenance mode..."
sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" down || true

log_info "Restoring ${DUMP_FILE} into '${DB_NAME}'..."
sudo -u postgres pg_restore -d "$DB_NAME" --clean --if-exists --no-owner --no-privileges -j2 "$DUMP_FILE" \
  || log_warn "pg_restore reported warnings — review above. If this looks wrong, restore the safety dump immediately: sudo bash $0 ${SAFETY_DUMP}"

DB_APP_USER="${DB_APP_USER:-cafe618_app}"
sudo -u postgres psql -d "$DB_NAME" -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_APP_USER};" >/dev/null
sudo -u postgres psql -d "$DB_NAME" -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_APP_USER};" >/dev/null

sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" up || true

log_ok "Restore complete. Safety dump of the PREVIOUS state kept at: ${SAFETY_DUMP}"
log_info "Run health-check.sh next to verify the application looks correct."
