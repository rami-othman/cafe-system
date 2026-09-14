#!/usr/bin/env bash
# Runtime regression test for install_cron_line() in lib/common.sh, exercised
# through the exact same function install.sh's "scheduler cron" step calls.
#
# The original Step 22 one-liner:
#   ( crontab -u "$APP_LINUX_USER" -l 2>/dev/null | grep -vF "artisan schedule:run" ; echo "$CRON_LINE" ) | crontab -u "$APP_LINUX_USER" -
# aborted install.sh silently, under set -euo pipefail, whenever the target
# user had no crontab yet (crontab -l exits 1) or whenever the existing
# crontab contained ONLY a previous schedule:run line (grep -v then selects
# zero lines and also exits 1) -- both entirely normal conditions, observed
# to kill a real VPS run at "Step 22/27: scheduler cron". This test drives
# install_cron_line() against a REAL `crontab` binary (not a mock) for the
# current user, across exactly those scenarios plus a repeated-call check,
# under the exact set -euo pipefail mode every script in this package uses.
#
# Requires: crontab (the `cron` package) and permission to manage crontabs
# for $TEST_CRON_USER (defaults to the current user; safe as non-root too --
# crontab -u only requires root when managing SOMEONE ELSE's crontab).
# Destructively replaces, then restores, that user's crontab.
#
# Usage: bash deployment/finjan/lib/test-scheduler-cron.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

command -v crontab >/dev/null 2>&1 || fatal "crontab is required for this test (apt-get install -y cron)."

TEST_CRON_USER="${TEST_CRON_USER:-$(id -un)}"
MATCH="artisan schedule:run"
CRON_LINE="* * * * * cd /var/www/cafe-system/backend && php artisan schedule:run >> /var/log/cafe618/scheduler.log 2>&1"

FAIL=0
ORIGINAL_CRONTAB="$(crontab -u "$TEST_CRON_USER" -l 2>/dev/null || true)"
HAD_ORIGINAL=0
[[ -n "$ORIGINAL_CRONTAB" ]] && HAD_ORIGINAL=1

restore_original_crontab() {
  if [[ "$HAD_ORIGINAL" -eq 1 ]]; then
    printf '%s\n' "$ORIGINAL_CRONTAB" | crontab -u "$TEST_CRON_USER" -
  else
    crontab -u "$TEST_CRON_USER" -r 2>/dev/null || true
  fi
}
trap restore_original_crontab EXIT

check() {
  local desc="$1" expected_lines="$2" expected_match_count="$3"
  local actual
  actual="$(crontab -u "$TEST_CRON_USER" -l 2>/dev/null || true)"
  local actual_lines actual_match_count
  actual_lines="$(printf '%s' "$actual" | grep -c '.' || true)"
  actual_match_count="$(printf '%s' "$actual" | grep -cF "$MATCH" || true)"
  if [[ "$actual_lines" -ne "$expected_lines" ]]; then
    log_err "$desc: expected $expected_lines line(s), got $actual_lines. Crontab was:"$'\n'"$actual"
    FAIL=1
  elif [[ "$actual_match_count" -ne "$expected_match_count" ]]; then
    log_err "$desc: expected $expected_match_count schedule:run line(s), got $actual_match_count. Crontab was:"$'\n'"$actual"
    FAIL=1
  else
    log_ok "$desc"
  fi
}

# --- Scenario 1: no existing crontab at all -------------------------------
crontab -u "$TEST_CRON_USER" -r 2>/dev/null || true
install_cron_line "$TEST_CRON_USER" "$MATCH" "$CRON_LINE"
check "no existing crontab -> installs the one scheduler line" 1 1

# --- Scenario 2: only the scheduler entry exists (simulates a re-run) ----
install_cron_line "$TEST_CRON_USER" "$MATCH" "$CRON_LINE"
check "only scheduler entry exists -> still exactly one scheduler line" 1 1

# --- Scenario 3: unrelated entries + a scheduler entry --------------------
printf '%s\n' \
  "0 3 * * * /usr/bin/bash /var/www/cafe-system/deployment/finjan/backup.sh daily" \
  "$CRON_LINE" \
  "0 4 * * 0 /usr/bin/bash /var/www/cafe-system/deployment/finjan/backup.sh weekly" \
  | crontab -u "$TEST_CRON_USER" -
install_cron_line "$TEST_CRON_USER" "$MATCH" "$CRON_LINE"
check "unrelated entries + scheduler entry -> unrelated kept, exactly one scheduler line" 3 1
if ! crontab -u "$TEST_CRON_USER" -l 2>/dev/null | grep -qF "backup.sh daily"; then
  log_err "unrelated 'backup.sh daily' entry was lost"
  FAIL=1
fi
if ! crontab -u "$TEST_CRON_USER" -l 2>/dev/null | grep -qF "backup.sh weekly"; then
  log_err "unrelated 'backup.sh weekly' entry was lost"
  FAIL=1
fi

# --- Scenario 4: repeated calls stay idempotent (simulates repeated install.sh runs) ---
for _ in 1 2 3 4 5; do
  install_cron_line "$TEST_CRON_USER" "$MATCH" "$CRON_LINE"
done
check "5 repeated calls -> unrelated entries still intact, still exactly one scheduler line" 3 1

# --- Scenario 5: unrelated-only crontab (no scheduler line yet) ----------
printf '%s\n' "0 3 * * * /usr/bin/bash /var/www/cafe-system/deployment/finjan/backup.sh daily" \
  | crontab -u "$TEST_CRON_USER" -
install_cron_line "$TEST_CRON_USER" "$MATCH" "$CRON_LINE"
check "unrelated-only crontab -> scheduler line added, unrelated kept" 2 1

echo
if [[ "$FAIL" -eq 0 ]]; then
  log_ok "install_cron_line: all scenarios passed under set -euo pipefail (no SIGPIPE/pipefail abort on empty crontab-list or empty grep result)."
  exit 0
else
  log_err "install_cron_line self-test failed — see above."
  exit 1
fi
