#!/usr/bin/env bash
# Finjan database migration: Supabase PostgreSQL -> local PostgreSQL on this VPS.
#
# Safety rules enforced by this script:
#   - source connection string is prompted with `read -s` and NEVER printed or logged
#   - dump uses pg_dump custom format (-Fc): schema + data + sequences + indexes +
#     constraints + the migrations table, all preserved natively by pg_restore
#   - the LOCAL target database must be empty (or you must explicitly confirm
#     an intentional overwrite) before restore proceeds
#   - never runs migrate:fresh, db:wipe, DROP DATABASE, or any seeder
#   - produces a written report after restore: table count, migration count,
#     a handful of real row counts, and a sequence sanity check
#
# Usage:
#   sudo bash deployment/finjan/migrate-database.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
load_state
command -v pg_dump >/dev/null 2>&1 || fatal "pg_dump not found. Install postgresql-client (install.sh already does this on this VPS)."

DB_NAME="${DB_NAME:-cafe618_production}"
DB_APP_USER="${DB_APP_USER:-cafe618_app}"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
DUMP_DIR="/var/backups/cafe618/migration"
mkdir -p "$DUMP_DIR"
DUMP_FILE="${DUMP_DIR}/supabase-source-${TS}.dump"

echo
log_info "This migrates data FROM your Supabase PostgreSQL source INTO the local"
log_info "database '${DB_NAME}' already created by install.sh on this VPS."
echo

prompt_secret SOURCE_DB_URL "Paste the FULL Supabase source connection string (postgresql://user:pass@host:port/db?sslmode=require) — input hidden, never logged"
[[ -n "$SOURCE_DB_URL" ]] || fatal "No source connection string entered."

log_info "Testing source connection (no password will be printed)..."
if ! psql "$SOURCE_DB_URL" -tAc "SELECT 1" >/dev/null 2>/tmp/cafe618-src-test.err; then
  log_err "Could not connect to the source database. Details:"
  # Scrub any accidental password echo from driver error text before showing it.
  sed -E 's#(://[^:]+:)[^@]+(@)#\1********\2#g' /tmp/cafe618-src-test.err >&2
  rm -f /tmp/cafe618-src-test.err
  exit 1
fi
rm -f /tmp/cafe618-src-test.err
log_ok "Source connection OK."

# ---------------------------------------------------------------------------
# Safety gate: is the LOCAL target empty?
# ---------------------------------------------------------------------------
LOCAL_TABLE_COUNT="$(sudo -u postgres psql -d "$DB_NAME" -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")"
LOCAL_TABLE_COUNT="$(echo "$LOCAL_TABLE_COUNT" | tr -d '[:space:]')"

if [[ "${LOCAL_TABLE_COUNT:-0}" -gt 0 ]]; then
  log_warn "Local database '${DB_NAME}' already has ${LOCAL_TABLE_COUNT} table(s)."
  log_warn "This looks like it may already contain production data."
  echo
  sudo -u postgres psql -d "$DB_NAME" -c "\dt" || true
  echo
  if ! confirm "Type-confirm: I have verified the above and want to OVERWRITE '${DB_NAME}' with the Supabase dump"; then
    fatal "Aborted — local database was not touched. (No DROP DATABASE is ever run automatically by this script.)"
  fi
  log_warn "Proceeding with explicit operator approval. A safety dump of the CURRENT local database will be taken first."
  sudo -u postgres pg_dump -Fc -d "$DB_NAME" -f "${DUMP_DIR}/local-pre-overwrite-safety-${TS}.dump"
  log_ok "Safety dump of existing local DB saved: ${DUMP_DIR}/local-pre-overwrite-safety-${TS}.dump"
else
  log_ok "Local database '${DB_NAME}' is empty — safe to restore into."
fi

# ---------------------------------------------------------------------------
# Dump the source (custom format: schema + data + sequences + indexes +
# constraints + the migrations table, all in one file pg_restore understands).
# ---------------------------------------------------------------------------
log_info "Dumping source database (this can take a while for large data)..."
pg_dump "$SOURCE_DB_URL" -Fc --no-owner --no-privileges -f "$DUMP_FILE"
unset SOURCE_DB_URL
log_ok "Source dump written: ${DUMP_FILE} ($(du -h "$DUMP_FILE" | cut -f1))"
chmod 600 "$DUMP_FILE"

# ---------------------------------------------------------------------------
# Restore into local target
# ---------------------------------------------------------------------------
log_info "Restoring into local database '${DB_NAME}'..."
if [[ "${LOCAL_TABLE_COUNT:-0}" -gt 0 ]]; then
  sudo -u postgres pg_restore -d "$DB_NAME" --clean --if-exists --no-owner --no-privileges -j2 "$DUMP_FILE" \
    || log_warn "pg_restore reported warnings/errors above — some are expected for extensions Supabase pre-installs (pg_stat_statements, etc.) that don't exist here. Review the report below before trusting the result."
else
  sudo -u postgres pg_restore -d "$DB_NAME" --no-owner --no-privileges -j2 "$DUMP_FILE" \
    || log_warn "pg_restore reported warnings/errors above — review the report below before trusting the result."
fi
sudo -u postgres psql -d "$DB_NAME" -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_APP_USER};" >/dev/null
sudo -u postgres psql -d "$DB_NAME" -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_APP_USER};" >/dev/null
sudo -u postgres psql -d "$DB_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_APP_USER};" >/dev/null

# ---------------------------------------------------------------------------
# Verification report (never destructive)
# ---------------------------------------------------------------------------
REPORT="${DUMP_DIR}/migration-report-${TS}.txt"
{
  echo "Finjan database migration report — ${TS}"
  echo "Target database: ${DB_NAME}"
  echo
  echo "-- Table count --"
  sudo -u postgres psql -d "$DB_NAME" -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'"
  echo
  echo "-- Laravel migrations table --"
  if sudo -u postgres psql -d "$DB_NAME" -tAc "SELECT to_regclass('public.migrations')" | grep -q migrations; then
    sudo -u postgres psql -d "$DB_NAME" -c "SELECT count(*) AS migrations_recorded FROM migrations;"
  else
    echo "WARNING: no 'migrations' table found after restore — Laravel will think NO migrations have ever run."
  fi
  echo
  echo "-- Row counts for key business tables (only those that exist) --"
  for t in tenants branches orders order_items products customers users payments invoices; do
    EXISTS="$(sudo -u postgres psql -d "$DB_NAME" -tAc "SELECT to_regclass('public.${t}')")"
    if [[ -n "$(echo "$EXISTS" | tr -d '[:space:]')" ]]; then
      CNT="$(sudo -u postgres psql -d "$DB_NAME" -tAc "SELECT count(*) FROM ${t}")"
      echo "  ${t}: ${CNT}"
    fi
  done
  echo
  echo "-- Sequences found (spot-check these — pg_dump/pg_restore preserve sequence values, but verify a couple manually) --"
  sudo -u postgres psql -d "$DB_NAME" -tAc "
    SELECT
      t.relname AS table_name,
      s.relname AS sequence_name
    FROM pg_class s
    JOIN pg_depend d ON d.objid = s.oid AND d.deptype = 'a'
    JOIN pg_class t ON t.oid = d.refobjid
    WHERE s.relkind = 'S'
  " | while read -r seq_line; do
    [[ -n "$seq_line" ]] || continue
    log_info "Sequence check: ${seq_line}"
  done
  echo "(Run: SELECT setval(pg_get_serial_sequence('table','id'), (SELECT COALESCE(MAX(id),1) FROM table)); for any table where inserts fail with a duplicate-key error after migration.)"
  echo
  echo "-- Pending Laravel migrations (compares migrations table to files on disk; does NOT run anything) --"
} > "$REPORT"
sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" migrate:status >> "$REPORT" 2>&1 || echo "(could not run migrate:status — check DB connectivity in backend/.env)" >> "$REPORT"

log_ok "Migration report written: ${REPORT}"
cat "$REPORT"

echo
log_warn "This script never ran migrate:fresh, db:wipe, DROP DATABASE, or any seeder."
log_warn "If 'Pending' migrations are listed above, review them manually — they were not applied automatically."
log_info "Next: bash deployment/finjan/migrate-storage.sh, then bash deployment/finjan/health-check.sh"
