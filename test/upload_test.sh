#!/usr/bin/env bash
# Unit tests for upload.sh's auth and soft-mode logic. A stub `gocov` on
# PATH stands in for the CLI, its exit code driven by $FAKE_GOCOV_EXIT, so
# the cases exercise which credential path upload.sh picks and whether a
# failure fails the build. Run: bash test/upload_test.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
UPLOAD="$PWD/upload.sh"

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

bin="$scratch/bin"
mkdir -p "$bin"
# Records the call (with the token it saw in the environment) and exits with
# the code the case asked for.
cat >"$bin/gocov" <<'FAKE'
#!/usr/bin/env bash
echo "GOCOV_CALLED token=${GOCOV_TOKEN:-<none>} args=$*"
exit "${FAKE_GOCOV_EXIT:-0}"
FAKE
chmod +x "$bin/gocov"
printf 'mode: atomic\n' >"$scratch/cov.out"

fails=0
OUT=""

# reset clears every input upload.sh reads, then sets the two the action
# always provides. Each case sets the rest before calling run.
reset() {
  unset GOCOV_TOKEN GITHUB_EVENT_NAME FAKE_GOCOV_EXIT GOCOV_SKIP_UPLOAD \
    ACTIONS_ID_TOKEN_REQUEST_TOKEN ACTIONS_ID_TOKEN_REQUEST_URL GOCOV_INPUT_IGNORE
  export GOCOV_FAIL_ON_ERROR=true GOCOV_SERVER=https://gocov.example GOCOV_PART=
}

run() { # run <expected-exit> <description>
  local want=$1 desc=$2 rc
  OUT=$(cd "$scratch" && PATH="$bin:$PATH" GOCOV_FILES="cov.out" bash "$UPLOAD" 2>&1)
  rc=$?
  if [ "$rc" != "$want" ]; then
    echo "FAIL: $desc: exit $rc, want $want"
    printf '%s\n' "$OUT" | sed 's/^/    /'
    fails=$((fails + 1))
  else
    echo "ok: $desc"
  fi
}

has() { grep -qF -- "$1" <<<"$OUT" || { echo "  FAIL: output missing '$1'"; fails=$((fails + 1)); }; }
lacks() { ! grep -qF -- "$1" <<<"$OUT" || { echo "  FAIL: output should not contain '$1'"; fails=$((fails + 1)); }; }

reset
export GOCOV_TOKEN=secret
run 0 "token upload succeeds"
has "GOCOV_CALLED token=secret"
lacks "uploading via OIDC"
lacks "-ignore"

# The ignore input becomes one -ignore flag; the CLI splits the list.
reset
export GOCOV_TOKEN=secret GOCOV_INPUT_IGNORE='cmd/preview/**,*_mock.go'
run 0 "ignore input is passed as -ignore"
has "args=upload -ignore cmd/preview/**,*_mock.go cov.out"

# A job-level GOCOV_IGNORE reaches the CLI on its own; no input, no flag.
reset
export GOCOV_TOKEN=secret GOCOV_IGNORE='gen/**'
run 0 "job-level GOCOV_IGNORE is left to the CLI"
lacks "-ignore"
unset GOCOV_IGNORE

reset
export GOCOV_TOKEN=secret FAKE_GOCOV_EXIT=1
run 1 "token upload failure fails the build"
has "upload(s) failed"

reset
export ACTIONS_ID_TOKEN_REQUEST_TOKEN=t ACTIONS_ID_TOKEN_REQUEST_URL=u GITHUB_EVENT_NAME=push
run 0 "oidc upload succeeds when both id-token vars are present"
has "uploading via OIDC"
has "GOCOV_CALLED token=<none>"

# K2: an OIDC upload honours fail-on-error rather than always swallowing.
reset
export ACTIONS_ID_TOKEN_REQUEST_TOKEN=t ACTIONS_ID_TOKEN_REQUEST_URL=u GITHUB_EVENT_NAME=push FAKE_GOCOV_EXIT=1
run 1 "oidc failure fails the build (fail-on-error=true)"
has "upload(s) failed"

reset
export ACTIONS_ID_TOKEN_REQUEST_TOKEN=t ACTIONS_ID_TOKEN_REQUEST_URL=u GITHUB_EVENT_NAME=push \
  FAKE_GOCOV_EXIT=1 GOCOV_FAIL_ON_ERROR=false
run 0 "oidc failure warns when fail-on-error=false"
has "warning"

# K4: the id-token endpoint needs both vars; half of it is not OIDC.
reset
export ACTIONS_ID_TOKEN_REQUEST_TOKEN=t GITHUB_EVENT_NAME=push
run 1 "half the id-token env is not treated as OIDC"
has "no upload token"
lacks "uploading via OIDC"

# Fork PR stays always-soft: a contributor's build must never break.
reset
export GITHUB_EVENT_NAME=pull_request FAKE_GOCOV_EXIT=1
run 0 "fork tokenless never fails the build"
has "tokenless"
has "did not land"

reset
export GITHUB_EVENT_NAME=push
run 1 "no credential on a push fails"
has "no upload token"

# Precedence: an explicit token wins even when id-token is available.
reset
export GOCOV_TOKEN=secret ACTIONS_ID_TOKEN_REQUEST_TOKEN=t ACTIONS_ID_TOKEN_REQUEST_URL=u GITHUB_EVENT_NAME=push
run 0 "token takes precedence over OIDC"
has "GOCOV_CALLED token=secret"
lacks "uploading via OIDC"

if [ "$fails" -ne 0 ]; then
  echo "$fails assertion(s) failed"
  exit 1
fi
echo "all upload.sh tests passed"
