#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$repo_root/tool/versions.sh"
output_dir="$repo_root/.subdock/frontend"
work_dir=$(mktemp -d)
frontend_repository=sub-store-org/Sub-Store-Front-End
frontend_tag=$(subdock_resolve_release_tag "$SUBDOCK_FRONTEND_VERSION" \
  "$frontend_repository" dist.zip)

cleanup() {
  rm -rf "$work_dir"
}
trap cleanup 0 HUP INT TERM

archive="$work_dir/dist.zip"
curl --fail --location --retry 3 --retry-all-errors --output "$archive" \
  "$(subdock_release_asset_url "$frontend_repository" "$frontend_tag" dist.zip)"
unzip -q "$archive" -d "$work_dir/extracted"
source_dir="$work_dir/extracted/dist"
test -f "$source_dir/index.html"

staging_dir="$work_dir/frontend"
mkdir -p "$staging_dir"
cp -R "$source_dir/." "$staging_dir"
test -f "$staging_dir/index.html"
printf '%s\n' "$frontend_tag" > "$staging_dir/version"

rm -rf "$output_dir"
mv "$staging_dir" "$output_dir"
printf 'Prepared Sub-Store Front-End %s at %s\n' \
  "$frontend_tag" "$output_dir"
