#!/usr/bin/env bash
# Shared helpers for the Finjan deployment package.
# Source this from every script: source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

set -euo pipefail

# ---- paths -------------------------------------------------------------
# FINJAN_DIR = deployment/finjan (this file's parent's parent)
FINJAN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${FINJAN_DIR}/../.." && pwd)"
BACKEND_DIR="${REPO_ROOT}/backend"
ADMIN_DIR="${REPO_ROOT}/super_admin_web"

APP_LINUX_USER="${APP_LINUX_USER:-cafe618}"
APP_LINUX_GROUP="${APP_LINUX_GROUP:-cafe618}"
DEPLOY_STATE_DIR="/etc/cafe618"
DEPLOY_STATE_FILE="${DEPLOY_STATE_DIR}/deploy-state.env"
BACKUP_ROOT="/var/backups/cafe618"

# ---- logging -------------------------------------------------------------
_c_red=$'\033[31m'; _c_yel=$'\033[33m'; _c_grn=$'\033[32m'; _c_blu=$'\033[34m'; _c_rst=$'\033[0m'

log_info()  { printf '%s[INFO]%s  %s\n'  "$_c_blu" "$_c_rst" "$*"; }
log_ok()    { printf '%s[ OK ]%s  %s\n'  "$_c_grn" "$_c_rst" "$*"; }
log_warn()  { printf '%s[WARN]%s  %s\n'  "$_c_yel" "$_c_rst" "$*" >&2; }
log_err()   { printf '%s[FAIL]%s  %s\n'  "$_c_red" "$_c_rst" "$*" >&2; }
fatal()     { log_err "$*"; exit 1; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    fatal "This script must be run as root (use: sudo bash $0)."
  fi
}

confirm() {
  # confirm "Question?" -> returns 0 for yes, 1 for no. Defaults to "no".
  local prompt="$1" reply
  read -r -p "${prompt} [y/N]: " reply || true
  [[ "${reply}" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# Prompt for a secret without echoing it, and without ever printing it back.
prompt_secret() {
  # prompt_secret VAR_NAME "Prompt text"
  local __var="$1" __prompt="$2" __val
  read -r -s -p "${__prompt}: " __val
  echo >&2
  printf -v "$__var" '%s' "$__val"
}

prompt_value() {
  # prompt_value VAR_NAME "Prompt text" "default"
  local __var="$1" __prompt="$2" __default="${3:-}" __val
  if [[ -n "$__default" ]]; then
    read -r -p "${__prompt} [${__default}]: " __val
    __val="${__val:-$__default}"
  else
    read -r -p "${__prompt}: " __val
  fi
  printf -v "$__var" '%s' "$__val"
}

random_secret() {
  # Cryptographically random alphanumeric string, $1 characters (default 32).
  #
  # Previously this piped /dev/urandom through `tr -dc | head -c N`. /dev/urandom
  # is an infinite stream, so `head -c N` exits the instant it has its N bytes —
  # which SIGPIPEs `tr` while it's still writing. `tr`'s resulting exit status
  # (141) becomes the pipeline's status under `set -o pipefail`, and every
  # script in this package runs with `set -euo pipefail`, so that non-zero
  # status silently killed the calling script (observed on a real VPS run:
  # install.sh exited mid "PostgreSQL app user + database" step, right at
  # `DB_APP_PASSWORD="$(random_secret 32)"`, with no error printed because
  # SIGPIPE termination doesn't write anything to stderr). `openssl rand` runs
  # as a single command with no pipe, so there's no early-exiting downstream
  # consumer to trigger this.
  local len="${1:-32}"
  command -v openssl >/dev/null 2>&1 || fatal "openssl is required to generate secrets but was not found on PATH."
  local hex
  hex="$(openssl rand -hex "$(( (len + 1) / 2 ))")"
  printf '%s' "${hex:0:len}"
}

pkg_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

ensure_packages() {
  local missing=()
  for p in "$@"; do
    pkg_installed "$p" || missing+=("$p")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_info "Installing missing packages: ${missing[*]}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
  else
    log_ok "All requested packages already present: $*"
  fi
}

php_ext_present() {
  php -m 2>/dev/null | grep -qi "^$1\$"
}

save_state() {
  # save_state KEY VALUE  -- persists to DEPLOY_STATE_FILE (root-only readable)
  mkdir -p "$DEPLOY_STATE_DIR"
  touch "$DEPLOY_STATE_FILE"
  chmod 600 "$DEPLOY_STATE_FILE"
  if grep -q "^$1=" "$DEPLOY_STATE_FILE" 2>/dev/null; then
    sed -i "s#^$1=.*#$1=$2#" "$DEPLOY_STATE_FILE"
  else
    echo "$1=$2" >> "$DEPLOY_STATE_FILE"
  fi
}

load_state() {
  [[ -f "$DEPLOY_STATE_FILE" ]] && source "$DEPLOY_STATE_FILE"
  true
}

dns_resolves_to_this_host() {
  # dns_resolves_to_this_host DOMAIN -> 0 if an A record was found (any IP);
  # caller decides whether the IP needs to match this VPS.
  local domain="$1"
  command -v dig >/dev/null 2>&1 && dig +short A "$domain" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
}

install_cron_line() {
  # install_cron_line USER MATCH_PATTERN CRON_LINE
  #
  # Idempotently replaces any existing crontab line for USER that contains
  # the fixed string MATCH_PATTERN with exactly one copy of CRON_LINE,
  # leaving every other line untouched. Used instead of the tempting
  # one-liner `(crontab -l | grep -v PATTERN; echo LINE) | crontab -` because
  # that pipes two commands that both have entirely normal non-zero exit
  # codes straight into a pipefail-checked pipeline:
  #   - `crontab -l` exits 1 whenever USER has no crontab yet (true on every
  #     fresh system user, e.g. a first install).
  #   - `grep -v` exits 1 whenever it selects zero lines (true whenever the
  #     existing crontab contains ONLY a previous MATCH_PATTERN line, e.g.
  #     any re-run).
  # Under `set -euo pipefail` (every script in this package), either of those
  # ordinary conditions kills the pipeline and aborts the calling script
  # before the new line is ever written — confirmed on a real VPS run, where
  # install.sh exited silently mid "scheduler cron" step. Both are captured
  # here explicitly with `|| true`, and the result is written to a temp file
  # and installed with a plain `crontab file` (not a pipe), so a genuine
  # crontab-install failure still aborts normally.
  local user="$1" match_pattern="$2" cron_line="$3"
  local existing other_lines tmp

  existing="$(crontab -u "$user" -l 2>/dev/null || true)"
  other_lines="$(printf '%s' "$existing" | grep -vF "$match_pattern" || true)"

  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' RETURN
  {
    # Only emit $other_lines if non-empty, so a fresh/all-matching crontab
    # doesn't end up with a stray leading blank line.
    [[ -n "$other_lines" ]] && printf '%s\n' "$other_lines"
    printf '%s\n' "$cron_line"
  } > "$tmp"
  crontab -u "$user" "$tmp"
  rm -f "$tmp"
  trap - RETURN
}
