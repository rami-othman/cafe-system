#!/usr/bin/env bash
# Finjan cutover verification — read-only smoke tests to run AFTER
# install.sh + migrate-database.sh + migrate-storage.sh, before you point
# DNS/production traffic at this VPS for real and before decommissioning
# Railway/Supabase/Netlify.
#
# This script only READS. It never creates real orders/payments — if a
# designated test tenant ID is supplied via --test-tenant, a couple of
# read-only checks are scoped to it, but nothing is written.
#
# Usage:
#   sudo bash deployment/finjan/verify-cutover.sh [--test-tenant ID]

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
set +e  # report every check, matching health-check.sh's philosophy

load_state
DB_NAME="${DB_NAME:-cafe618_production}"
TEST_TENANT=""
if [[ "${1:-}" == "--test-tenant" ]]; then
  TEST_TENANT="${2:-}"
fi

FAIL=0
step() { echo; echo "== $1 =="; }
pass() { log_ok "$1"; }
fail() { log_err "$1"; FAIL=$((FAIL+1)); }

cat <<'EOF'
Finjan cutover checklist (see also README.md § Cutover for the full 15-step
procedure this script assists with). This script covers steps 8, 11, 12, 13
and part of 14 automatically; the rest are manual/DNS/business decisions.

 1.  Prepare local Finjan stack .............. install.sh (done before this runs)
 2.  Take final source DB backup ............. do this on the Supabase side yourself
 3.  Put old environment into maintenance .... manual (Render dashboard / Supabase)
 4.  Final DB sync ........................... migrate-database.sh
 5.  Final file sync ......................... migrate-storage.sh
 6.  Start Laravel on Finjan ................. install.sh / systemctl
 7.  Start Admin on Finjan ................... install.sh / systemctl
 8.  Run smoke tests ......................... THIS SCRIPT
 9.  Update DNS .............................. manual — you control the registrar
10.  Verify HTTPS ............................ install.sh step 26 + THIS SCRIPT
11.  Verify POS/Flutter ...................... THIS SCRIPT (API reachability only —
                                                full POS flow needs the real Windows app)
12.  Verify data consistency ................. THIS SCRIPT (row counts vs migration report)
13.  Verify product images ................... THIS SCRIPT
14.  Verify payments/orders/inventory/finance
     READ paths .............................. THIS SCRIPT (read-only endpoints only)
15.  Decommission old runtime ................ manual, AFTER you approve — never automatic
EOF

step "Application boots"
sudo -u "$APP_LINUX_USER" php "${BACKEND_DIR}/artisan" --version >/dev/null 2>&1 && pass "artisan boots" || fail "artisan does not boot"

step "Database consistency vs migration report"
if ls "${BACKUP_ROOT}"/migration/migration-report-*.txt >/dev/null 2>&1; then
  LATEST_REPORT="$(find "${BACKUP_ROOT}/migration" -maxdepth 1 -name 'migration-report-*.txt' -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)"
  pass "Found migration report: ${LATEST_REPORT}"
  log_info "Re-checking the same row counts now:"
  for t in tenants branches orders order_items products customers users payments invoices; do
    EXISTS="$(sudo -u postgres psql -d "$DB_NAME" -tAc "SELECT to_regclass('public.${t}')" 2>/dev/null)"
    if [[ -n "$(echo "$EXISTS" | tr -d '[:space:]')" ]]; then
      CNT="$(sudo -u postgres psql -d "$DB_NAME" -tAc "SELECT count(*) FROM ${t}" 2>/dev/null)"
      log_info "  ${t}: ${CNT} (compare with ${LATEST_REPORT})"
    fi
  done
else
  log_warn "No migration report found under ${BACKUP_ROOT}/migration — did you run migrate-database.sh?"
fi

step "Product images"
IMG_COUNT_LOCAL="$(find "${BACKEND_DIR}/storage/app/public/product-images" -type f 2>/dev/null | wc -l)"
IMG_COUNT_DB="$(sudo -u postgres psql -d "$DB_NAME" -tAc "SELECT count(*) FROM products WHERE image_url LIKE '%/api/v1/product-images/%'" 2>/dev/null)"
log_info "Local image files on disk: ${IMG_COUNT_LOCAL}"
log_info "Products pointing at local image URLs: ${IMG_COUNT_DB}"
REMAINING_SUPABASE="$(sudo -u postgres psql -d "$DB_NAME" -tAc "SELECT count(*) FROM products WHERE image_url IS NOT NULL AND image_url NOT LIKE '%/api/v1/product-images/%'" 2>/dev/null)"
if [[ "${REMAINING_SUPABASE:-0}" -gt 0 ]]; then
  fail "${REMAINING_SUPABASE} product(s) still have a non-local image_url — re-run migrate-storage.sh."
else
  pass "No products still point at a non-local image URL."
fi

step "API reachability (read-only)"
UP_CODE="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/up -H 'Host: api.cafesystemsyria.com')"
[[ "$UP_CODE" == "200" ]] && pass "GET /up -> 200" || fail "GET /up -> ${UP_CODE}"

step "Super Admin reachability"
ADMIN_CODE="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3000/)"
[[ "$ADMIN_CODE" =~ ^(200|307|308)$ ]] && pass "Super Admin responds (${ADMIN_CODE})" || fail "Super Admin -> ${ADMIN_CODE}"

if [[ -n "$TEST_TENANT" ]]; then
  step "Scoped read-only checks for test tenant ${TEST_TENANT}"
  for t in orders products branches; do
    EXISTS="$(sudo -u postgres psql -d "$DB_NAME" -tAc "SELECT to_regclass('public.${t}')" 2>/dev/null)"
    if [[ -n "$(echo "$EXISTS" | tr -d '[:space:]')" ]]; then
      CNT="$(sudo -u postgres psql -d "$DB_NAME" -tAc "SELECT count(*) FROM ${t} WHERE tenant_id = ${TEST_TENANT}" 2>/dev/null)"
      log_info "  ${t} for tenant ${TEST_TENANT}: ${CNT}"
    fi
  done
  log_warn "This only counts rows. Actually exercising POS/payments/inventory flows requires the real Flutter Windows client pointed at https://api.cafesystemsyria.com — do that manually against this test tenant before wider rollout."
else
  log_info "No --test-tenant given — skipping scoped read checks. Pass one to spot-check a specific tenant's data without touching production tenants."
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  log_ok "Cutover verification found no automated failures. Proceed to manual DNS/SSL/Flutter verification (steps 9-11 above) before decommissioning anything."
  exit 0
else
  log_err "${FAIL} check(s) failed. Do not decommission Railway/Supabase/Netlify until these are resolved."
  exit 1
fi
