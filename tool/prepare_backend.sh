#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$repo_root/tool/versions.sh"
output_dir="$repo_root/.subdock/backend"
work_dir=$(mktemp -d)
backend_tag=$(subdock_resolve_tag "$SUBDOCK_BACKEND_VERSION" \
  https://github.com/sub-store-org/Sub-Store.git)

cleanup() {
  rm -rf "$work_dir"
}
trap cleanup 0 HUP INT TERM

download() {
  curl --fail --location --retry 3 --retry-all-errors --output "$work_dir/$1" \
    "https://github.com/sub-store-org/Sub-Store/releases/download/$backend_tag/$1"
}

download sub-store.bundle.js
download runtime-manifest.json

mkdir -p "$output_dir"
install -m 0644 "$work_dir/sub-store.bundle.js" "$output_dir/sub-store.bundle.js"
install -m 0644 "$work_dir/runtime-manifest.json" "$output_dir/runtime-manifest.json"
printf '%s\n' "$backend_tag" > "$output_dir/version"

printf 'Prepared Sub-Store %s at %s\n' "$backend_tag" "$output_dir"
