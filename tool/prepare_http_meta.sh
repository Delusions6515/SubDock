#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$repo_root/tool/versions.sh"
target=${1:?usage: tool/prepare_http_meta.sh <linux-x64|windows-x64|darwin-arm64|darwin-x64>}
output_dir="$repo_root/.subdock/http-meta/$target"
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' 0 HUP INT TERM

http_meta_tag=$(subdock_resolve_release_tag "$SUBDOCK_HTTP_META_VERSION" xream/http-meta \
  http-meta.bundle.js)
curl --fail --location --retry 3 --retry-all-errors --output "$work_dir/http-meta.bundle.js" \
  "https://github.com/xream/http-meta/releases/download/$http_meta_tag/http-meta.bundle.js"
curl --fail --location --retry 3 --retry-all-errors --output "$work_dir/tpl.yaml" \
  "https://github.com/xream/http-meta/releases/download/$http_meta_tag/tpl.yaml"

case "$target" in
  linux-x64) mihomo_asset="mihomo-linux-amd64-v1"; mihomo_archive=gz ;;
  windows-x64) mihomo_asset="mihomo-windows-amd64-v1"; mihomo_archive=zip ;;
  darwin-arm64) mihomo_asset="mihomo-darwin-arm64"; mihomo_archive=gz ;;
  darwin-x64) mihomo_asset="mihomo-darwin-amd64-v1"; mihomo_archive=gz ;;
  *) printf 'Unsupported http-meta target: %s\n' "$target" >&2; exit 64 ;;
esac
if test "$SUBDOCK_MIHOMO_VERSION" = latest; then
  mihomo_tag=$(curl --fail --location --retry 3 --retry-all-errors --silent \
    https://github.com/MetaCubeX/mihomo/releases/latest/download/version.txt |
    tr -d '\r\n')
else
  mihomo_tag=$SUBDOCK_MIHOMO_VERSION
fi
test -n "$mihomo_tag"
case "$mihomo_tag" in v*) ;; *) mihomo_tag="v$mihomo_tag" ;; esac
case "$mihomo_tag" in v*) mihomo_version=${mihomo_tag#v};; *) mihomo_version=$mihomo_tag;; esac
mihomo_file="$mihomo_asset-v$mihomo_version.$mihomo_archive"
version_file="$work_dir/mihomo-version.txt"
curl --fail --location --retry 3 --retry-all-errors --output "$version_file" \
  "https://github.com/MetaCubeX/mihomo/releases/download/$mihomo_tag/version.txt"
test "$(tr -d '\r\n' < "$version_file")" = "v$mihomo_version"
curl --fail --location --retry 3 --retry-all-errors --output "$work_dir/$mihomo_file" \
  "https://github.com/MetaCubeX/mihomo/releases/download/$mihomo_tag/$mihomo_file"
test -s "$work_dir/$mihomo_file"

output_staging="$work_dir/http-meta"
staging="$output_staging/meta"
mkdir -p "$staging"
install -m 0644 "$work_dir/http-meta.bundle.js" "$output_staging/http-meta.bundle.js"
install -m 0644 "$work_dir/tpl.yaml" "$staging/tpl.yaml"
if test "$mihomo_archive" = gz; then gzip -dc "$work_dir/$mihomo_file" > "$staging/mihomo"; else unzip -p "$work_dir/$mihomo_file" "$mihomo_asset.exe" > "$staging/mihomo.exe"; fi
if test "$mihomo_archive" = gz; then chmod 0755 "$staging/mihomo"; fi
printf '%s\n' "$http_meta_tag" > "$output_staging/version"
printf '%s\n' "$mihomo_tag" > "$staging/mihomo-version"
rm -rf "$output_dir"
mkdir -p "$(dirname -- "$output_dir")"
mv "$output_staging" "$output_dir"
printf 'Prepared http-meta %s with mihomo %s at %s\n' "$http_meta_tag" "$mihomo_tag" "$output_dir"
