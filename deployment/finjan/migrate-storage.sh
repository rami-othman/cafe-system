#!/usr/bin/env bash
# Finjan storage migration: Supabase Storage (product-images bucket) -> local
# disk on this VPS.
#
# How product images actually work in this codebase (see FINDINGS.md and
# app/Services/Catalog/ProductImageStorage.php):
#   - products.image_url stores a FULL URL, not a bare path.
#   - Supabase-era rows look like: {SUPABASE_STORAGE_PUBLIC_URL}/tenants/{id}/products/{file}
#   - Local rows look like:        {APP_URL}/api/v1/product-images/{id}/{file}
#     served by ProductCatalogController::showProductImage() reading from the
#     local 'product-images-local' disk (storage/app/public/product-images/{id}/{file}).
#
# The actual copy+rewrite logic lives in a new, narrowly-scoped Artisan
# command shipped in THIS deployment commit:
#   backend/app/Console/Commands/MigrateProductImagesFromSupabase.php
# This script only prompts for temporary Supabase credentials (never written
# to backend/.env), exports them for the duration of the artisan calls, runs
# a dry-run first, asks for confirmation, then applies.
#
# Usage:
#   sudo bash deployment/finjan/migrate-storage.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

ARTISAN="${BACKEND_DIR}/artisan"
if ! sudo -u "$APP_LINUX_USER" php "$ARTISAN" list 2>/dev/null | grep -q "cafe618:migrate-product-images"; then
  fatal "The 'cafe618:migrate-product-images' Artisan command was not found. This deployment package expects backend/app/Console/Commands/MigrateProductImagesFromSupabase.php to be present in the checked-out commit."
fi

echo
log_info "This copies product images from your Supabase Storage bucket down to"
log_info "local disk on this VPS, and rewrites products.image_url accordingly."
log_info "The Supabase-side objects are never deleted by this script."
echo

prompt_value SUPABASE_STORAGE_ENDPOINT_VAL "Supabase Storage S3-compatible endpoint (e.g. https://<ref>.storage.supabase.co/storage/v1/s3)"
prompt_value SUPABASE_STORAGE_REGION_VAL "Supabase Storage region" "us-east-1"
prompt_value SUPABASE_STORAGE_BUCKET_VAL "Supabase Storage bucket" "product-images"
prompt_value SUPABASE_STORAGE_PUBLIC_URL_VAL "Supabase Storage PUBLIC URL prefix (used to recognize old rows, e.g. https://<ref>.supabase.co/storage/v1/object/public/product-images)"
prompt_secret SUPABASE_STORAGE_ACCESS_KEY_ID_VAL "Supabase Storage access key ID (temporary/rotatable credential, input hidden)"
prompt_secret SUPABASE_STORAGE_SECRET_ACCESS_KEY_VAL "Supabase Storage secret access key (input hidden)"

export SUPABASE_STORAGE_ENDPOINT="$SUPABASE_STORAGE_ENDPOINT_VAL"
export SUPABASE_STORAGE_REGION="$SUPABASE_STORAGE_REGION_VAL"
export SUPABASE_STORAGE_BUCKET="$SUPABASE_STORAGE_BUCKET_VAL"
export SUPABASE_STORAGE_PUBLIC_URL="$SUPABASE_STORAGE_PUBLIC_URL_VAL"
export SUPABASE_STORAGE_ACCESS_KEY_ID="$SUPABASE_STORAGE_ACCESS_KEY_ID_VAL"
export SUPABASE_STORAGE_SECRET_ACCESS_KEY="$SUPABASE_STORAGE_SECRET_ACCESS_KEY_VAL"
export SUPABASE_STORAGE_USE_PATH_STYLE=true

run_artisan_with_supabase_env() {
  sudo -u "$APP_LINUX_USER" \
    SUPABASE_STORAGE_ENDPOINT="$SUPABASE_STORAGE_ENDPOINT" \
    SUPABASE_STORAGE_REGION="$SUPABASE_STORAGE_REGION" \
    SUPABASE_STORAGE_BUCKET="$SUPABASE_STORAGE_BUCKET" \
    SUPABASE_STORAGE_PUBLIC_URL="$SUPABASE_STORAGE_PUBLIC_URL" \
    SUPABASE_STORAGE_ACCESS_KEY_ID="$SUPABASE_STORAGE_ACCESS_KEY_ID" \
    SUPABASE_STORAGE_SECRET_ACCESS_KEY="$SUPABASE_STORAGE_SECRET_ACCESS_KEY" \
    SUPABASE_STORAGE_USE_PATH_STYLE=true \
    php "$ARTISAN" "$@"
}

log_info "== Dry run =="
run_artisan_with_supabase_env cafe618:migrate-product-images --dry-run

echo
if ! confirm "Review the dry-run output above. Proceed with the REAL copy + database update?"; then
  unset SUPABASE_STORAGE_ENDPOINT SUPABASE_STORAGE_REGION SUPABASE_STORAGE_BUCKET SUPABASE_STORAGE_PUBLIC_URL SUPABASE_STORAGE_ACCESS_KEY_ID SUPABASE_STORAGE_SECRET_ACCESS_KEY SUPABASE_STORAGE_USE_PATH_STYLE
  fatal "Aborted by operator. No files were copied, no database rows were changed."
fi

log_info "== Applying =="
RESULT=0
run_artisan_with_supabase_env cafe618:migrate-product-images --apply || RESULT=$?

unset SUPABASE_STORAGE_ENDPOINT SUPABASE_STORAGE_REGION SUPABASE_STORAGE_BUCKET SUPABASE_STORAGE_PUBLIC_URL SUPABASE_STORAGE_ACCESS_KEY_ID SUPABASE_STORAGE_SECRET_ACCESS_KEY SUPABASE_STORAGE_USE_PATH_STYLE SUPABASE_STORAGE_ENDPOINT_VAL SUPABASE_STORAGE_ACCESS_KEY_ID_VAL SUPABASE_STORAGE_SECRET_ACCESS_KEY_VAL

chown -R "${APP_LINUX_USER}:${APP_LINUX_GROUP}" "${BACKEND_DIR}/storage/app/public/product-images" 2>/dev/null || true
find "${BACKEND_DIR}/storage/app/public/product-images" -type d -exec chmod 775 {} \; 2>/dev/null || true
find "${BACKEND_DIR}/storage/app/public/product-images" -type f -exec chmod 664 {} \; 2>/dev/null || true

if [[ "$RESULT" -eq 0 ]]; then
  log_ok "Storage migration completed. No Supabase-side objects were deleted — verify locally, THEN clean up Supabase manually per your own schedule."
else
  log_err "Storage migration reported failures — see output above. Nothing already-migrated was rolled back (each row commits independently)."
fi
exit "$RESULT"
