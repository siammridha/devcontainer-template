#!/bin/sh
# Builds the devbase image on this machine and pushes it to ghcr.io. Needs
# Docker and a one-time `docker login ghcr.io` with a token that has
# `write:packages`.
#
# Usage: ./release-devbase.sh [version]   (default: last v* tag + 1 patch)
set -eu

image=ghcr.io/siammridha/devbase
platform="${PLATFORM:-linux/arm64}"

cd "$(dirname "$0")"
if [ -n "$(git status --porcelain)" ]; then
  echo "Commit or stash your changes first: the image is built from this folder." >&2
  exit 1
fi

git fetch -q --tags origin
if [ $# -gt 0 ]; then
  version="${1#v}"
else
  last=$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n 1)
  if [ -z "$last" ]; then
    version=1.0.0
  else
    version="${last#v}"
    version="${version%.*}.$((${last##*.} + 1))"
  fi
fi
echo "Releasing $image:$version"

git rev-parse -q --verify "refs/tags/v$version" >/dev/null || git tag "v$version"
git push origin "v$version"

# --pull and --no-cache so rustup, Claude Code, cargo install and apk fetch
# the newest versions instead of reusing old layers.
docker buildx build --platform "$platform" --pull --no-cache \
  -t "$image:latest" -t "$image:$version" \
  --push base
