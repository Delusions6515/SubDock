#!/bin/sh

SUBDOCK_BACKEND_VERSION=${SUBDOCK_BACKEND_VERSION:-latest}
SUBDOCK_FRONTEND_VERSION=${SUBDOCK_FRONTEND_VERSION:-latest}
SUBDOCK_NODE_VERSION=${SUBDOCK_NODE_VERSION:-}
SUBDOCK_SHOUTRRR_VERSION=${SUBDOCK_SHOUTRRR_VERSION:-latest}

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
