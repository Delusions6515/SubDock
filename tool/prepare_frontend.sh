#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$repo_root/tool/versions.sh"
output_dir="$repo_root/.subdock/frontend"
work_dir=$(mktemp -d)
frontend_tag=$(subdock_resolve_tag "$SUBDOCK_FRONTEND_VERSION" \
  https://github.com/sub-store-org/Sub-Store-Front-End.git)

cleanup() {
  rm -rf "$work_dir"
}
trap cleanup 0 HUP INT TERM

source_dir="$work_dir/source"
git clone --depth 1 --branch "$frontend_tag" \
  https://github.com/sub-store-org/Sub-Store-Front-End.git "$source_dir"

if command -v pnpm >/dev/null 2>&1; then
  pnpm --dir "$source_dir" install --frozen-lockfile
  pnpm --dir "$source_dir" build
else
  npx --yes pnpm@11.0.9 --dir "$source_dir" install --frozen-lockfile
  npx --yes pnpm@11.0.9 --dir "$source_dir" build
fi

staging_dir="$work_dir/frontend"
mkdir -p "$staging_dir"
cp -R "$source_dir/dist/." "$staging_dir"
test -f "$staging_dir/index.html"

rm -rf "$output_dir"
mv "$staging_dir" "$output_dir"
printf 'Prepared Sub-Store Front-End %s at %s\n' \
  "$frontend_tag" "$output_dir"
