#!/usr/bin/env bash
# Regression test: this package must never modify the git-tracked mode bits
# of its own files. A previous version of install.sh ran
# `chmod +x "${SCRIPT_DIR}"/*.sh` as a defensive "fix the executable bit"
# step. That's harmless in isolation, but on a Linux checkout (where
# core.fileMode normally defaults to true, unlike the Windows checkout this
# repo was originally committed from) it flips every script's tracked mode
# from 100644 to 100755 -- git then reports every script as a worktree
# modification, which blocks a later `git checkout <other-commit>` for a
# future deploy or rollback until an operator manually discards or commits
# that mode-only change. Since every invocation in this package uses
# `bash <script>`, never `./<script>`, the executable bit was never actually
# required (see the comment above `require_root` in install.sh).
#
# This test has two parts:
#   1. A static guard: grep this package's own scripts for any chmod call
#      that would touch its own tracked .sh files, so that pattern can never
#      silently come back.
#   2. A live check: build a disposable throwaway git repo containing a copy
#      of this package, record every tracked file's mode and `git status`,
#      exercise the same repo-root-detection logic install.sh runs before
#      any root/Postgres/etc-dependent step, and assert both are byte-for-
#      byte unchanged afterward.
#
# Usage: bash deployment/finjan/lib/test-clean-worktree.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FINJAN_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

FAIL=0

echo "== Static guard: no chmod +x targeting this package's own tracked scripts =="
# Scoped to actual code lines (not comments) in the real deployment scripts
# and lib/common.sh -- deliberately excludes this test file itself, which
# legitimately does `chmod 644` (not `+x`) to seed a known starting mode for
# the live check below.
GUARD_HIT=0
for f in "${FINJAN_DIR}"/*.sh "${FINJAN_DIR}/lib/common.sh"; do
  MATCH="$(grep -nE '^[[:space:]]*chmod[[:space:]]+\+x.*\*\.sh' "$f" 2>/dev/null || true)"
  if [[ -n "$MATCH" ]]; then
    echo "$f: $MATCH"
    GUARD_HIT=1
  fi
done
if [[ "$GUARD_HIT" -eq 1 ]]; then
  echo "FAIL: found a chmod +x call that would touch this package's own tracked .sh files (shown above) -- this dirties the git worktree on any Linux checkout. See LINT_REPORT.md." >&2
  FAIL=1
else
  echo "OK: no script in this package chmod +x's its own tracked .sh files."
fi

echo
echo "== Live check: disposable git repo, before/after status+mode comparison =="
TMPROOT="$(mktemp -d)"
cleanup() { rm -rf "$TMPROOT"; }
trap cleanup EXIT

REPO="${TMPROOT}/repo"
mkdir -p "${REPO}/deployment"
cp -r "${FINJAN_DIR}" "${REPO}/deployment/finjan"
# install.sh's repo-root detection (via common.sh) requires backend/composer.json
# to exist two directories up from lib/common.sh -- give it a minimal stand-in
# so that check succeeds without needing the real cafe-system repo checked out.
mkdir -p "${REPO}/backend" "${REPO}/super_admin_web"
echo '{}' > "${REPO}/backend/composer.json"

(
  cd "$REPO"
  git init -q
  git config user.email test@example.com
  git config user.name test
  git config core.fileMode true
  chmod 644 deployment/finjan/*.sh deployment/finjan/lib/*.sh
  git add -A
  git commit -q -m "initial"
)

BEFORE_STATUS="$(cd "$REPO" && git status --porcelain)"
BEFORE_MODES="$(cd "$REPO" && git ls-files -s deployment/finjan | awk '{print $1, $4}')"

# Exercise the part of install.sh's startup that runs before require_root's
# privileged/system-changing steps: sourcing lib/common.sh (which no longer
# chmod's anything) and the same repo-root/composer.json detection install.sh
# performs immediately afterward.
(
  cd "$REPO"
  # shellcheck source=/dev/null
  source deployment/finjan/lib/common.sh
  [[ -f "${REPO_ROOT}/backend/composer.json" ]]
)

AFTER_STATUS="$(cd "$REPO" && git status --porcelain)"
AFTER_MODES="$(cd "$REPO" && git ls-files -s deployment/finjan | awk '{print $1, $4}')"

if [[ "$BEFORE_STATUS" != "$AFTER_STATUS" ]]; then
  echo "FAIL: git status changed after sourcing common.sh / detecting repo root:" >&2
  echo "--- before ---"; printf '%s\n' "$BEFORE_STATUS"
  echo "--- after ---"; printf '%s\n' "$AFTER_STATUS"
  FAIL=1
elif [[ "$BEFORE_MODES" != "$AFTER_MODES" ]]; then
  echo "FAIL: tracked file modes changed:" >&2
  diff <(printf '%s\n' "$BEFORE_MODES") <(printf '%s\n' "$AFTER_MODES") || true
  FAIL=1
else
  echo "OK: git worktree is byte-for-byte clean (status and tracked modes unchanged)."
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "PASS: this package does not dirty its own git worktree."
  exit 0
else
  echo "FAIL: worktree-cleanliness regression test failed -- see above." >&2
  exit 1
fi
