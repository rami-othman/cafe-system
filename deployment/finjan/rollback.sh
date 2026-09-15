#!/usr/bin/env bash
# Finjan CODE rollback — reverts the deployed commit only.
#
# IMPORTANT DISTINCTION:
#   CODE ROLLBACK (this script)  = git checkout an older commit, rebuild, restart.
#   DATABASE RESTORE (separate)  = restore-backup.sh, restores a PostgreSQL dump.
# Rolling back code does NOT undo database migrations or data changes. If the
# commit you're rolling back past ran a migration that is not backward
# compatible with the older code, rolling back code alone can break the app.
# This script warns you and requires confirmation before touching migrations.
#
# Usage:
#   sudo bash deployment/finjan/rollback.sh <known-good-commit>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
load_state

TARGET="${1:-}"
[[ -n "$TARGET" ]] || fatal "Usage: sudo bash deployment/finjan/rollback.sh <known-good-commit-sha>"

cd "${REPO_ROOT}"
CURRENT_SHA="$(git rev-parse HEAD)"
TARGET_SHA="$(git rev-parse "${TARGET}^{commit}" 2>/dev/null)" || fatal "Revision '${TARGET}' not found."

log_warn "About to CODE-ROLLBACK from ${CURRENT_SHA} to ${TARGET_SHA}."
log_warn "This does NOT touch the database. If migrations ran between these two"
log_warn "commits, the OLD code may not understand the NEW schema. Review"
log_warn "'git log ${TARGET_SHA}..${CURRENT_SHA} --oneline -- backend/database/migrations' first."
git log "${TARGET_SHA}..${CURRENT_SHA}" --oneline -- backend/database/migrations 2>/dev/null || true

confirm "Proceed with code rollback to ${TARGET_SHA}?" || fatal "Aborted by operator."

log_info "Deploying ${TARGET_SHA} using the same path as a normal deploy..."
exec bash "${SCRIPT_DIR}/deploy.sh" "${TARGET_SHA}"
