#!/usr/bin/env bash
# Runtime regression test for random_secret() in lib/common.sh.
#
# A previous implementation used `tr -dc 'A-Za-z0-9' </dev/urandom | head -c N`,
# which crashed install.sh on a real VPS run: /dev/urandom is an infinite
# stream, `head -c N` exits as soon as it has its N bytes, `tr` gets SIGPIPE
# while still writing, and under this package's `set -euo pipefail` that
# non-zero pipeline status silently killed the calling script mid-run (no
# error printed — SIGPIPE termination writes nothing to stderr). This test
# runs random_secret() many times, at several lengths, under the exact
# `set -euo pipefail` mode every deployment script uses, so that class of bug
# can't silently come back.
#
# Usage: bash deployment/finjan/lib/test-random-secret.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

RUNS_PER_LENGTH=200
LENGTHS=(1 8 16 20 24 32 33 64 100)
FAIL=0
TOTAL=0

for len in "${LENGTHS[@]}"; do
  for _ in $(seq 1 "$RUNS_PER_LENGTH"); do
    TOTAL=$((TOTAL + 1))
    val="$(random_secret "$len")"
    if [[ "${#val}" -ne "$len" ]]; then
      log_err "random_secret ${len} returned length ${#val}, not ${len} (value: '${val}')"
      FAIL=1
    fi
    if [[ ! "$val" =~ ^[A-Za-z0-9]+$ ]]; then
      log_err "random_secret ${len} returned a non-alphanumeric character: '${val}'"
      FAIL=1
    fi
  done
done

if [[ "$FAIL" -eq 0 ]]; then
  log_ok "random_secret: ${TOTAL} calls across ${#LENGTHS[@]} lengths, all correctly sized and alphanumeric, no SIGPIPE/pipefail abort under set -euo pipefail."
  exit 0
else
  log_err "random_secret self-test failed — see above."
  exit 1
fi
