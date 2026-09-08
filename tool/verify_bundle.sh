#!/bin/sh
set -eu

bundle_dir=${1:?usage: tool/verify_bundle.sh <bundle-dir> [windows]}
platform=${2:-unix}
suffix=
if test "$platform" = windows; then
  suffix=.exe
fi

for file in \
  "$bundle_dir/data/runtime/node$suffix" \
  "$bundle_dir/data/runtime/bin/shoutrrr$suffix" \
  "$bundle_dir/data/backend/sub-store.bundle.js" \
  "$bundle_dir/data/backend/runtime-manifest.json" \
  "$bundle_dir/data/backend/version" \
  "$bundle_dir/data/frontend/index.html" \
  "$bundle_dir/data/frontend/version" \
  "$bundle_dir/data/licenses/GPL-3.0-only.txt"; do
  test -f "$file"
done

if test "$platform" != windows; then
  test -x "$bundle_dir/data/runtime/node"
  test -x "$bundle_dir/data/runtime/bin/shoutrrr"
fi

for version in \
  "$bundle_dir/data/backend/version" \
  "$bundle_dir/data/frontend/version"; do
  test "$(wc -l < "$version" | tr -d ' ')" = 1
  test -n "$(tr -d '\r\n' < "$version")"
done
