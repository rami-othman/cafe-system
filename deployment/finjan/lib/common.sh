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
  # 32 bytes, URL-safe-ish, no shell-special characters.
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-32}"
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
