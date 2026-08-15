#!/usr/bin/env bash
# Downloads the gocov CLI binary for this runner from the pinned
# gocov/gocov release and verifies its sha256 against the checksums.txt
# published with the same release. Only github.com/gocov/gocov/releases is
# ever contacted. On success the binary directory is appended to
# $GITHUB_PATH for the following steps.
set -eo pipefail

fail() {
  if [ "$GOCOV_FAIL_ON_ERROR" = "false" ]; then
    echo "::warning title=gocov::$1 (fail-on-error is false, skipping upload)"
    echo "GOCOV_SKIP_UPLOAD=1" >>"$GITHUB_ENV"
    exit 0
  fi
  echo "::error title=gocov::$1"
  exit 1
}

case "$RUNNER_OS" in
Linux) os=linux ;;
macOS) os=darwin ;;
Windows) os=windows ;;
*) fail "unsupported runner OS: $RUNNER_OS" ;;
esac
case "$RUNNER_ARCH" in
X64) arch=amd64 ;;
ARM64) arch=arm64 ;;
*) fail "unsupported runner architecture: $RUNNER_ARCH" ;;
esac

ext=""
[ "$os" = "windows" ] && ext=".exe"
asset="gocov-$os-$arch$ext"
base="https://github.com/gocov/gocov/releases/download/$GOCOV_VERSION"

dir="$RUNNER_TEMP/gocov-cli"
mkdir -p "$dir"

echo "downloading $base/$asset"
curl -fsSL --retry 3 --retry-delay 2 -o "$dir/$asset" "$base/$asset" ||
  fail "could not download $asset from gocov/gocov release $GOCOV_VERSION"
curl -fsSL --retry 3 --retry-delay 2 -o "$dir/checksums.txt" "$base/checksums.txt" ||
  fail "could not download checksums.txt from gocov/gocov release $GOCOV_VERSION"

# The trailing tr strips the "\" that sha256sum prefixes in its escaped
# output format, triggered on Windows by backslashes in $RUNNER_TEMP.
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}' | tr -d '\\'
  else
    shasum -a 256 "$1" | awk '{print $1}' | tr -d '\\'
  fi
}

want=$(awk -v f="$asset" '$2 == f {print $1}' "$dir/checksums.txt")
[ -n "$want" ] || fail "no checksum for $asset in release $GOCOV_VERSION"
got=$(sha256 "$dir/$asset")
[ "$want" = "$got" ] ||
  fail "sha256 mismatch for $asset: want $want, got $got"

mv "$dir/$asset" "$dir/gocov$ext"
chmod +x "$dir/gocov$ext"
echo "$dir" >>"$GITHUB_PATH"
"$dir/gocov$ext" version
