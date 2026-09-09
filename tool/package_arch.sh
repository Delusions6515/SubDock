#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bundle_dir="$repo_root/build/linux/x64/release/bundle"
pkgbuild="$repo_root/linux/packaging/arch/PKGBUILD"

test -x "$bundle_dir/sub_dock"
test -f "$pkgbuild"
command -v makepkg >/dev/null 2>&1

version=$(sed -n 's/^version: \([0-9][0-9.]*\).*/\1/p' "$repo_root/pubspec.yaml")
test -n "$version"
work_dir=$(mktemp -d)
cleanup() { rm -rf "$work_dir"; }
trap cleanup EXIT HUP INT TERM

cp "$pkgbuild" "$work_dir/PKGBUILD"
sed -i "s/^pkgver=.*/pkgver=$version/" "$work_dir/PKGBUILD"
cp -R "$bundle_dir" "$work_dir/bundle"
(cd "$work_dir" && makepkg --cleanbuild --noconfirm)
mkdir -p "$repo_root/dist"
find "$work_dir" -maxdepth 1 -type f -name '*.pkg.tar.zst' -exec cp {} "$repo_root/dist/" \;
