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

# Without a token the CLI acquires the credential itself, in its own
# precedence order:
#   - OIDC: when the workflow granted `id-token: write`, GitHub exposes a
#     mint endpoint to the job as $ACTIONS_ID_TOKEN_REQUEST_URL and
#     $ACTIONS_ID_TOKEN_REQUEST_TOKEN — both, or neither. The CLI mints a
#     signed identity token the server verifies. This is a normal upload: it
#     honours fail-on-error, because the CLI already exits 0 on a clean OIDC
#     refusal, so a non-zero exit here is a real error worth surfacing.
#   - Tokenless: a fork pull_request has no secret and no id-token, so the
#     CLI sends the workflow run's identity for the server to verify through
#     the repo's gocov GitHub App installation. A fork contributor's build
#     must never break over coverage, so this path alone is always soft.
tokenless=0
if [ -z "$GOCOV_TOKEN" ]; then
  if [ -n "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ] && [ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
    echo "no token — uploading via OIDC (id-token permission), verified by the server"
  elif [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then
    tokenless=1
    echo "no token (fork pull request?) — uploading tokenless, verified via the gocov GitHub App"
  else
    fail "no upload token: pass the 'token' input (a GOCOV_TOKEN repository secret), or grant 'permissions: id-token: write' to upload via OIDC — see the README"
  fi
else
  # Secrets are masked by Actions already; mask again in case the token
  # was passed some other way.
  echo "::add-mask::$GOCOV_TOKEN"
fi

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
# One -ignore carries the whole list: the CLI splits on commas and
# newlines, so a multi-line YAML input arrives intact.
[ -n "${GOCOV_INPUT_IGNORE:-}" ] && args+=(-ignore "$GOCOV_INPUT_IGNORE")

failures=0
for f in "${files[@]}"; do
  echo "uploading $f"
  if [ "$tokenless" = "1" ]; then
    # A fork contributor's build must never break: a CLI new enough to know
    # tokenless mode already exits 0 on refusal, and an older `version` pin
    # exits 1 with "upload token required" — swallow that too.
    gocov upload ${args[@]+"${args[@]}"} "$f" ||
      echo "::notice title=gocov::tokenless upload of $f did not land — see the log above"
  else
    # Token and OIDC uploads both honour fail-on-error via this accounting.
    gocov upload ${args[@]+"${args[@]}"} "$f" || failures=$((failures + 1))
  fi
done
[ "$failures" -eq 0 ] || fail "$failures of ${#files[@]} upload(s) failed"
