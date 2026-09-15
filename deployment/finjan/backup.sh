#!/usr/bin/env bash
# Finjan local backup: PostgreSQL + product images + app config.
#
# *** IMPORTANT — READ THIS ***
# A backup stored only on this VPS does NOT protect you against total VPS
# loss (disk failure, provider account issue, accidental `rm -rf`, a
# compromised root account, etc.). This script intentionally does NOT ship an
# off-site destination, because the brief for this deployment is "runtime and
# data live on Finjan" and no external service credentials were provided.
# See deployment/finjan/README.md § Backups for how to add one later
# (S3-compatible storage, Cloudflare R2, Backblaze B2, or even a periodic
# `rsync`/`rclone` to another machine you control) — until you do, this is
# your ONLY copy of the data.
#
# Usage:
#   sudo bash deployment/finjan/backup.sh [daily|weekly|monthly]   # default: daily
# Intended to run from cron/systemd-timer; see README for the suggested schedule.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
load_state

KIND="${1:-daily}"
case "$KIND" in
  daily|weekly|monthly) ;;
  *) fatal "Usage: $0 [daily|weekly|monthly]" ;;
esac

DB_NAME="${DB_NAME:-cafe618_production}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="${BACKUP_ROOT}/${KIND}"
mkdir -p "$DEST"
chmod 700 "$BACKUP_ROOT" "$DEST"

DB_DUMP="${DEST}/db-${TS}.dump"
STORAGE_TAR="${DEST}/product-images-${TS}.tar.gz"
CONFIG_TAR="${DEST}/config-${TS}.tar.gz"

log_info "Backing up PostgreSQL database '${DB_NAME}'..."
sudo -u postgres pg_dump -Fc -d "$DB_NAME" -f "$DB_DUMP"
chmod 600 "$DB_DUMP"
log_ok "DB dump: ${DB_DUMP} ($(du -h "$DB_DUMP" | cut -f1))"

log_info "Backing up product images..."
if [[ -d "${BACKEND_DIR}/storage/app/public/product-images" ]]; then
  tar -czf "$STORAGE_TAR" -C "${BACKEND_DIR}/storage/app/public" product-images
  chmod 600 "$STORAGE_TAR"
  log_ok "Product images: ${STORAGE_TAR} ($(du -h "$STORAGE_TAR" | cut -f1))"
else
  log_warn "No storage/app/public/product-images directory found yet — skipping."
fi

log_info "Backing up application configuration (NOT secrets — .env is excluded; see note below)..."
# .env is deliberately excluded from the general config tarball: bundling
# secrets into a backup archive that later gets copied around (or, once you
# add off-site backup, uploaded to a third party) is exactly the kind of
# mistake this package is trying to avoid. .env is backed up SEPARATELY,
# encrypted-at-rest only by filesystem permissions (600, root-owned), in its
# own file so it can be excluded independently from any future off-site sync.
tar -czf "$CONFIG_TAR" -C "${REPO_ROOT}" \
  --exclude='backend/.env' \
  --exclude='super_admin_web/.env*' \
  deployment/finjan/nginx \
  backend/config \
  2>/dev/null || true
chmod 600 "$CONFIG_TAR"
log_ok "Config (secrets excluded): ${CONFIG_TAR}"

if [[ -f "${BACKEND_DIR}/.env" ]]; then
  ENV_BACKUP="${DEST}/backend-env-${TS}.tar.gz"
  tar -czf "$ENV_BACKUP" -C "${BACKEND_DIR}" .env
  chmod 600 "$ENV_BACKUP"
  log_ok ".env backed up separately (600, root-only): ${ENV_BACKUP}"
fi

# ---------------------------------------------------------------------------
# Retention: 7 daily, 4 weekly, 6 monthly (suggested minimum from the brief)
# ---------------------------------------------------------------------------
case "$KIND" in
  daily)   KEEP=7 ;;
  weekly)  KEEP=4 ;;
  monthly) KEEP=6 ;;
esac
for prefix in db- product-images- config- backend-env-; do
  # find never fails on zero matches (unlike an unglobbed ls pattern), which
  # matters under `set -e -o pipefail` on the very first run of a given kind.
  OLD_FILES="$(find "${DEST}" -maxdepth 1 -type f -name "${prefix}*" -printf '%T@ %p\n' 2>/dev/null | sort -rn | tail -n "+$((KEEP + 1))" | cut -d' ' -f2- || true)"
  if [[ -n "$OLD_FILES" ]]; then
    while IFS= read -r old; do
      [[ -n "$old" ]] || continue
      rm -f -- "$old"
      log_info "Pruned old backup (retention ${KEEP} for ${KIND}): $(basename "$old")"
    done <<< "$OLD_FILES"
  fi
done

log_ok "Backup (${KIND}) complete. Total size on disk for ${BACKUP_ROOT}: $(du -sh "$BACKUP_ROOT" 2>/dev/null | cut -f1)"
log_warn "Reminder: this is a LOCAL-ONLY backup. See README.md § Backups about off-site storage."
