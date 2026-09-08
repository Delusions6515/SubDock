#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
resources_dir="$project_dir/.subdock"
case "${SUBDOCK_MACOS_RUNTIME_TARGET:?missing SUBDOCK_MACOS_RUNTIME_TARGET}" in
  arm64) runtime_target=darwin-arm64 ;;
  x86_64) runtime_target=darwin-x64 ;;
  *)
    printf 'Unsupported macOS runtime architecture: %s\n' \
      "$SUBDOCK_MACOS_RUNTIME_TARGET" >&2
    exit 64
    ;;
esac
runtime_dir="$resources_dir/runtime/$runtime_target"
destination="${TARGET_BUILD_DIR:?}/${WRAPPER_NAME:?}/Contents/MacOS/data"

for file in \
  "$runtime_dir/node" \
  "$runtime_dir/bin/shoutrrr" \
  "$resources_dir/backend/sub-store.bundle.js" \
  "$resources_dir/backend/runtime-manifest.json" \
  "$resources_dir/backend/version" \
  "$resources_dir/frontend/index.html" \
  "$resources_dir/frontend/version"; do
  test -f "$file"
done

rm -rf "$destination"
mkdir -p "$destination"
cp -R "$runtime_dir" "$destination/runtime"
cp -R "$resources_dir/backend" "$destination/backend"
cp -R "$resources_dir/frontend" "$destination/frontend"
mkdir -p "$destination/licenses"
cp "$project_dir/LICENSE" "$destination/licenses/GPL-3.0-only.txt"
