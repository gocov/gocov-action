#!/usr/bin/env bash
# The action installs one gocov CLI release: the `version` input's default
# in action.yml. That default is the pin, and it is authoritative.
#
# This script fails CI when anything else in the repo pins a different CLI
# release. Today action.yml is the only place a version is written down —
# install.sh builds the download URL from $GOCOV_VERSION rather than
# spelling one out — so the check mostly holds the line: the moment a
# README example or a workflow hardcodes a version, the two have to agree.
#
# Only the two forms that actually pin a CLI are matched: a `version:`
# input and a release download URL. Bare version strings are not, because
# in this repo they are usually *action* releases — `gocov-action@v1`, the
# `(v1.2.3)` in a workflow comment — and a check that cannot tell those
# apart from a CLI pin would cry wolf until someone deleted it.
#
# Deliberately *not* checked here: whether that default is the newest
# gocov/gocov release. Between a CLI release and the bump PR that follows
# it, the pin is legitimately one version behind, and a check that went
# red in that window would just teach everyone to ignore it. Keeping the
# wrappers level with the CLI is scripts/verify-release.sh's job, over in
# the gocov repo, after the release exists.
set -euo pipefail

cd "$(dirname "$0")/.."

default=$(sed -n 's/^ *default: *\(v[0-9]*\.[0-9]*\.[0-9]*\) *$/\1/p' action.yml)
if [ -z "$default" ]; then
  echo "check-pins: no 'default: vX.Y.Z' found in action.yml." >&2
  echo "The version input must default to the CLI release this action was tested against." >&2
  exit 1
fi
if [ "$(echo "$default" | wc -l | tr -d ' ')" -ne 1 ]; then
  echo "check-pins: action.yml has more than one version-shaped default:" >&2
  printf '%s\n' "$default" | sed 's/^/  /' >&2
  exit 1
fi

pins=$(git grep -InEo \
  -e 'releases/download/v[0-9]+\.[0-9]+\.[0-9]+' \
  -e 'version: *v[0-9]+\.[0-9]+\.[0-9]+' \
  -- ':!scripts/check-pins.sh' ':!CHANGELOG.md' || true)

bad=$(echo "$pins" | grep -F -v "$default" || true)
if [ -n "$bad" ]; then
  echo "check-pins: these pin a gocov CLI release other than action.yml's default ($default):" >&2
  echo >&2
  printf '%s\n' "$bad" | sed 's/^/  /' >&2
  echo >&2
  echo "Either update them to $default, or update the pin." >&2
  exit 1
fi

echo "check-pins: CLI pinned at $default in action.yml; $(echo "$pins" | grep -c . | tr -d " ") other pin(s) agree"
