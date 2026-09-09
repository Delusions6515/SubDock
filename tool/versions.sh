#!/bin/sh

SUBDOCK_BACKEND_VERSION=${SUBDOCK_BACKEND_VERSION:-latest}
SUBDOCK_FRONTEND_VERSION=${SUBDOCK_FRONTEND_VERSION:-latest}
SUBDOCK_NODE_VERSION=${SUBDOCK_NODE_VERSION:-}
SUBDOCK_SHOUTRRR_VERSION=${SUBDOCK_SHOUTRRR_VERSION:-latest}

subdock_release_asset_url() {
  repository=$1
  version=$2
  asset=$3
  if test "$version" = latest; then
    printf 'https://github.com/%s/releases/latest/download/%s\n' \
      "$repository" "$asset"
  else
    printf 'https://github.com/%s/releases/download/%s/%s\n' \
      "$repository" "$version" "$asset"
  fi
}

subdock_latest_tag() {
  git ls-remote --refs --tags --sort=-v:refname "$1" | awk '
    $2 ~ /refs\/tags\/v?[0-9]+\.[0-9]+\.[0-9]+$/ {
      sub("refs/tags/", "", $2)
      print $2
      exit
    }
  '
}

subdock_resolve_tag() {
  requested=$1
  repository=$2
  if test "$requested" = latest; then
    requested=$(subdock_latest_tag "$repository")
  fi
  test -n "$requested"
  printf '%s\n' "$requested"
}

subdock_resolve_release_tag() {
  requested=$1
  repository=$2
  asset=$3
  if test "$requested" = latest; then
    location=$(curl --fail --silent --show-error --head --dump-header - \
      --output /dev/null "$(subdock_release_asset_url "$repository" latest "$asset")" |
      tr -d '\r' |
      sed -n 's#^[Ll]ocation: .*releases/download/\([^/]*\)/.*#\1#p' |
      tail -n 1)
    test -n "$location"
    requested=$location
  fi
  test -n "$requested"
  printf '%s\n' "$requested"
}
