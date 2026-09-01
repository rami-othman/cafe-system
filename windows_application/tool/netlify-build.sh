#!/usr/bin/env bash

set -euo pipefail

: "${API_BASE_URL:?Set API_BASE_URL in Netlify to the Render HTTPS API URL, including /api/v1.}"
: "${NETLIFY_CACHE_DIR:?NETLIFY_CACHE_DIR is required by the Netlify build environment.}"

case "$API_BASE_URL" in
  https://*) ;;
  *)
    echo "API_BASE_URL must use HTTPS." >&2
    exit 1
    ;;
esac

flutter_version="${FLUTTER_VERSION:-3.44.8}"
flutter_root="$NETLIFY_CACHE_DIR/cafe-system-618/flutter-$flutter_version"

if [ ! -x "$flutter_root/bin/flutter" ]; then
  mkdir -p "$(dirname "$flutter_root")"
  git clone --depth 1 --branch "$flutter_version" \
    https://github.com/flutter/flutter.git "$flutter_root"
fi

export PATH="$flutter_root/bin:$PATH"
export PUB_CACHE="$NETLIFY_CACHE_DIR/cafe-system-618/pub-cache"

flutter config --no-analytics
flutter pub get
flutter build web --release --dart-define="API_BASE_URL=$API_BASE_URL"
