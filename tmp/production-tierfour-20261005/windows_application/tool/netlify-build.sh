#!/usr/bin/env bash

set -euo pipefail

: "${API_BASE_URL:?Set API_BASE_URL in Netlify to the Render HTTPS API URL, including /api/v1.}"

netlify_cache_dir="${NETLIFY_CACHE_DIR:-${HOME:-/tmp}/.cache/netlify}"

case "$API_BASE_URL" in
  https://*) ;;
  *)
    echo "API_BASE_URL must use HTTPS." >&2
    exit 1
    ;;
esac

flutter_version="3.44.8"
flutter_root="$netlify_cache_dir/cafe-system-618/flutter-$flutter_version"
pub_cache="$netlify_cache_dir/cafe-system-618/pub-cache"

mkdir -p "$(dirname "$flutter_root")" "$pub_cache"

if [ ! -x "$flutter_root/bin/flutter" ]; then
  git clone --depth 1 --branch "$flutter_version" \
    https://github.com/flutter/flutter.git "$flutter_root"
fi

export PATH="$flutter_root/bin:$PATH"
export PUB_CACHE="$pub_cache"

flutter config --no-analytics
flutter pub get
flutter build web --release --dart-define="API_BASE_URL=$API_BASE_URL"
