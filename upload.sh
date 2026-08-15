#!/usr/bin/env bash
# Expands the comma-separated globs in $GOCOV_FILES and runs `gocov upload`
# for each match. The token and server reach the CLI via $GOCOV_TOKEN and
# $GOCOV_SERVER (never argv, so they cannot leak through process listings);
# repo/commit/branch/PR are auto-detected by the CLI from the GitHub
# Actions environment.
set -eo pipefail

if [ "${GOCOV_SKIP_UPLOAD:-}" = "1" ]; then
  echo "skipping upload: CLI install failed and fail-on-error is false"
  exit 0
fi

fail() {
  if [ "$GOCOV_FAIL_ON_ERROR" = "false" ]; then
    echo "::warning title=gocov::$1"
    exit 0
  fi
  echo "::error title=gocov::$1"
  exit 1
}

[ -n "$GOCOV_TOKEN" ] ||
  fail "no upload token: pass the 'token' input (add GOCOV_TOKEN as a repository secret — see the README)"
# Secrets are masked by Actions already; mask again in case the token was
# passed some other way.
echo "::add-mask::$GOCOV_TOKEN"

# globstar is a bash >= 4 feature; without it "**" still matches one level
# as "*", so degrade silently rather than erroring on old bash.
shopt -s nullglob
shopt -s globstar 2>/dev/null || true

files=()
IFS=',' read -ra patterns <<<"$GOCOV_FILES"
for pat in "${patterns[@]}"; do
  # trim surrounding whitespace
  pat="${pat#"${pat%%[![:space:]]*}"}"
  pat="${pat%"${pat##*[![:space:]]}"}"
  [ -n "$pat" ] || continue
  # shellcheck disable=SC2206 # unquoted on purpose: glob expansion
  matched=($pat)
  if [ ${#matched[@]} -eq 0 ]; then
    echo "::warning title=gocov::no files match '$pat'"
    continue
  fi
  files+=("${matched[@]}")
done
[ ${#files[@]} -gt 0 ] || fail "no coverage files matched: $GOCOV_FILES"

args=()
[ -n "${GOCOV_PART:-}" ] && args+=(-part "$GOCOV_PART")

failures=0
for f in "${files[@]}"; do
  echo "uploading $f"
  gocov upload ${args[@]+"${args[@]}"} "$f" || failures=$((failures + 1))
done
[ "$failures" -eq 0 ] || fail "$failures of ${#files[@]} upload(s) failed"
