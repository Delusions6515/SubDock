#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir="$repo_root/.subdock/backend"
work_dir=$(mktemp -d)

cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT HUP INT TERM

git clone --depth 1 --branch feat/runtime-manifest \
  https://github.com/sub-store-org/Sub-Store.git "$work_dir/sub-store"

backend_dir="$work_dir/sub-store/backend"
if command -v pnpm >/dev/null 2>&1; then
  pnpm --dir "$backend_dir" install --frozen-lockfile
  pnpm --dir "$backend_dir" bundle:esbuild
else
  npx --yes pnpm@11.0.9 --dir "$backend_dir" install --frozen-lockfile
  npx --yes pnpm@11.0.9 --dir "$backend_dir" bundle:esbuild
fi

mkdir -p "$output_dir"
install -m 0644 "$backend_dir/dist/sub-store.bundle.js" "$output_dir/sub-store.bundle.js"
install -m 0644 "$backend_dir/dist/runtime-manifest.json" "$output_dir/runtime-manifest.json"
git -C "$work_dir/sub-store" rev-parse HEAD > "$output_dir/source-commit"

printf 'Prepared Sub-Store backend at %s\n' "$output_dir"
