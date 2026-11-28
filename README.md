# gocov-action

[![coverage](https://app.gocov.dev/badge/github/gocov/gocov-action.svg)](https://app.gocov.dev/repos/github/gocov/gocov-action?ref=badge)
![ci](https://github.com/gocov/gocov-action/actions/workflows/ci.yml/badge.svg)

Upload test coverage to [gocov](https://app.gocov.dev) from GitHub Actions —
Go, JavaScript/TypeScript, Java, Python, .NET, Swift and
[more](https://docs.gocov.dev/languages/), with the format detected from the
file: PR diff coverage, commit statuses and a README badge, on the hosted
service or your own server.

Full documentation: [docs.gocov.dev](https://docs.gocov.dev) — in particular
[GitHub Actions](https://docs.gocov.dev/github-actions/),
[the coverage gate](https://docs.gocov.dev/coverage-gate/) and
[parts](https://docs.gocov.dev/parts/) for matrix builds.

## Quickstart

Grant the job `id-token: write` and it needs no secret at all:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-go@v7
        with:
          go-version: stable
      - run: go test -covermode=atomic -coverprofile=coverage.out ./...
      - uses: gocov/gocov-action@v1
        with:
          files: coverage.out
```

For another language, only the test command and the `files:` path change —
[Languages & formats](https://docs.gocov.dev/languages/) lists what each test
tool writes.

Then add the badge to your README:

```markdown
[![coverage](https://app.gocov.dev/badge/github/{workspace}/{repo}.svg)](https://app.gocov.dev/repos/github/{workspace}/{repo}?ref=badge)
```

### Uploading without a token (OIDC)

With `id-token: write` granted and `token` left unset, the action asks GitHub
for a short-lived, signed identity token that proves which repository the run
belongs to, and the server verifies it. Nothing to create in the settings UI,
nothing to rotate. This covers your own repository's `push` and same-repo pull
request builds.

The repository's workspace (its GitHub org or user) must already be
registered on gocov and connected through the
[gocov GitHub App](https://github.com/apps/gocov) — the same connection that
posts the PR comment and check run. The repository itself needs no setup: its
first OIDC upload registers it. OIDC replaces only the upload token;
publishing still goes through that App identity, so the reported status is
**not** marked unverified. A rejected OIDC upload logs the reason and exits 0.
Full details:
[uploading without a token](https://docs.gocov.dev/github-actions/#uploading-without-a-token).

### Using an upload token instead

If you'd rather use a secret, the workspace has an upload token: owners can
reveal and rotate it in the workspace settings on gocov, under *Uploads*. In
GitHub, add it as an organization secret (or a repository secret: **Settings →
Secrets and variables → Actions → New repository secret**) named
`GOCOV_TOKEN`, and pass it to the action:

```yaml
- uses: gocov/gocov-action@v1
  with:
    files: coverage.out
    token: ${{ secrets.GOCOV_TOKEN }}
```

A token always takes precedence over the identity token, so existing setups
are untouched; the job then needs no `id-token` permission.

### Pull requests from forks

Fork PRs can't read your secrets and get no identity token, so on their
`pull_request` runs neither form above has anything to upload with — that's
fine. On a **public** repo with the
[gocov GitHub App](https://github.com/apps/gocov) installed, the action
uploads tokenless: the server verifies the workflow run itself through the
App, and the contributor gets the PR comment and check run with zero setup.
No workflow change needed — the same snippet covers both cases.

A tokenless upload never fails the build: if it's refused (App not
installed, private repo, verification failed), the job logs the reason and
carries on green. Details and limits:
[fork PRs without a token](https://docs.gocov.dev/pull-requests/#fork-prs-without-a-token).

## Inputs

| Input           | Required | Default                 | Description |
|-----------------|----------|-------------------------|-------------|
| `files`         | yes      | —                       | Coverage profile(s) to upload. Comma-separated, globs allowed (`coverage.out`, `cover/*.out`). |
| `token`         | no       | —                       | gocov upload token, from a `GOCOV_TOKEN` secret. Leave it unset to upload via [OIDC](#uploading-without-a-token-oidc) (grant `id-token: write`) on your own builds; fork `pull_request` runs upload [tokenless](#pull-requests-from-forks). |
| `part`          | no       | —                       | Label for this upload when coverage is split across jobs; the server merges parts for the same commit — see [Several jobs per commit](#several-jobs-per-commit-part). |
| `ignore`        | no       | —                       | Glob patterns for files to leave out of the report (`cmd/preview/**,*_mock.go`), on top of the repo's own settings — see [Ignoring files](#ignoring-files-ignore). |
| `server`        | no       | `https://app.gocov.dev` | gocov server URL; override when self-hosting. |
| `fail-on-error` | no       | `true`                  | Fail the workflow when install/upload fails. Set `false` to only warn. We default to honest failures — flip this if you'd rather never block CI on coverage upload. |
| `version`       | no       | pinned per release      | gocov CLI version to download ([gocov/gocov release tag](https://github.com/gocov/gocov/releases)). Each action release pins the CLI version it was tested against; everything in this README assumes that default, and an older release may not support every input or OIDC. |

Linux, macOS and Windows runners are supported, on amd64 and arm64. The
CLI binary is downloaded only from `github.com/gocov/gocov/releases` and
verified against the release's sha256 checksums; the action has no
third-party action dependencies.

## Several jobs per commit (`part`)

When a commit's coverage comes from several jobs — a Go backend, a JS/TS
frontend, the shards of a test matrix — give each upload a `part`. gocov
merges the parts uploaded for the same commit into one report, so the status,
badge, gate and PR comment reflect the combined total instead of whichever job
finished last. Separate jobs for separate languages:

```yaml
permissions:
  contents: read
  id-token: write

jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-go@v7
        with:
          go-version: stable
      - run: go test -coverprofile=coverage.out ./...
      - uses: gocov/gocov-action@v1
        with:
          files: coverage.out
          part: backend
  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - run: npm ci
      - run: npm test -- --coverage       # writes coverage/lcov.info
      - uses: gocov/gocov-action@v1
        with:
          files: coverage/lcov.info
          part: frontend
```

Or one job split into matrix shards, each its own part:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    strategy:
      matrix:
        include:
          - shard: unit
            tests: TestUnit
          - shard: integration
            tests: TestIntegration
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-go@v7
        with:
          go-version: stable
      - run: go test -coverprofile=coverage.out -run '${{ matrix.tests }}' ./...
      - uses: gocov/gocov-action@v1
        with:
          files: coverage.out
          part: ${{ matrix.shard }}
```

Re-running a job replaces its part rather than double-counting. Uploads with
no `part` land in a single `default` bucket, so single-job setups are
unchanged. Parts are merged as they arrive, so until the last one lands the
total can read low. Details: [parts](https://docs.gocov.dev/parts/).

## Ignoring files (`ignore`)

Keep generated code, mocks or dev tooling out of the number without touching
the test command:

```yaml
- uses: gocov/gocov-action@v1
  with:
    files: coverage.out
    ignore: |
      cmd/preview/**
      **/*.pb.go
      *_mock.go
```

Patterns are globs in the `.gitignore` spirit, matched against the paths in
the report (for Go profiles the module path is stripped first). They add to
whatever the repository's **Ignored files** setting already lists. Syntax and
details: [Ignoring files](https://docs.gocov.dev/ignoring-files/).

## Self-hosting

The same action talks to your own gocov instance — just point `server` at
it:

```yaml
- uses: gocov/gocov-action@v1
  with:
    files: coverage.out
    server: https://gocov.example.com
```

Uploads authenticate as above: OIDC, whose identity token is minted for the
`server` you set, or a `GOCOV_TOKEN` from your instance passed as `token`.

## Versioning

Use `gocov/gocov-action@v1` to track the latest v1 release, or pin an exact
tag (`@v1.0.0`). Each release pins a default gocov CLI version; `version`
overrides it.

## License

[MIT](LICENSE). The action is a thin wrapper around the gocov CLI and is
deliberately MIT-licensed so it never pulls AGPL terms into your workflow;
the gocov server remains separately licensed.
