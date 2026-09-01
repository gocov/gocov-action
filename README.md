# gocov-action

[![coverage](https://app.gocov.dev/badge/gocov/gocov-action.svg)](https://app.gocov.dev/repos/gocov/gocov-action?ref=badge)
![ci](https://github.com/gocov/gocov-action/actions/workflows/ci.yml/badge.svg)

Upload test coverage to [gocov](https://app.gocov.dev) from GitHub Actions —
Go, JavaScript/TypeScript (LCOV), Java (JaCoCo), Python (Cobertura) and more:
PR diff coverage, commit statuses and a README badge, on the hosted service
or your own server.

Full documentation: [docs.gocov.dev](https://docs.gocov.dev) — in particular
[uploading from CI](https://docs.gocov.dev/ci-upload/),
[the coverage gate](https://docs.gocov.dev/coverage-gate/) and
[parts](https://docs.gocov.dev/parts/) for matrix builds.

## Quickstart

```yaml
- uses: actions/checkout@v4
- uses: actions/setup-go@v5
- run: go test -coverprofile=coverage.out ./...
- uses: gocov/gocov-action@v1
  with:
    files: coverage.out
    token: ${{ secrets.GOCOV_TOKEN }}
```

Then add the badge to your README:

```markdown
[![coverage](https://app.gocov.dev/badge/{workspace}/{repo}.svg)](https://app.gocov.dev/repos/{workspace}/{repo}?ref=badge)
```

### Splitting coverage across jobs (matrix)

When a commit's coverage comes from several jobs — a Go backend, a
JS/TS frontend, an e2e suite — give each upload a `part`. gocov merges the
parts uploaded for the same commit into one report, so the status, badge,
gate and PR comment reflect the combined total instead of whichever job
finished last:

```yaml
jobs:
  backend:
    steps:
      - uses: actions/checkout@v4
      - run: go test -coverprofile=coverage.out ./...
      - uses: gocov/gocov-action@v1
        with:
          files: coverage.out
          token: ${{ secrets.GOCOV_TOKEN }}
          part: backend
  frontend:
    steps:
      - uses: actions/checkout@v4
      - run: npm test -- --coverage       # writes coverage/lcov.info
      - uses: gocov/gocov-action@v1
        with:
          files: coverage/lcov.info
          token: ${{ secrets.GOCOV_TOKEN }}
          part: frontend
```

Re-running a job replaces its part rather than double-counting. Uploads with
no `part` land in a single `default` bucket, so single-job setups are
unchanged.

### Adding the token

Grab the repo's upload token from the gocov dashboard, then in your GitHub
repo go to **Settings → Secrets and variables → Actions → New repository
secret**, name it `GOCOV_TOKEN` and paste the token. That's the only setup
step.

### Pull requests from forks

Fork PRs can't read your secrets, so `secrets.GOCOV_TOKEN` comes through
empty on their `pull_request` runs — that's fine. On a **public** repo with
the [gocov GitHub App](https://github.com/apps/gocov) installed, the action
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
| `token`         | no       | —                       | gocov upload token, from a repository secret. Required in practice — except on fork `pull_request` runs, where the empty secret triggers a tokenless upload (see above). |
| `part`          | no       | —                       | Label for this upload when coverage is split across matrix jobs; the server merges parts for the same commit. |
| `server`        | no       | `https://app.gocov.dev` | gocov server URL; override when self-hosting. |
| `fail-on-error` | no       | `true`                  | Fail the workflow when install/upload fails. Set `false` to only warn. We default to honest failures — flip this if you'd rather never block CI on coverage upload. |
| `version`       | no       | pinned per release      | gocov CLI version to download ([gocov/gocov release tag](https://github.com/gocov/gocov/releases)). Each action release pins the CLI version it was tested against. |

Linux, macOS and Windows runners are supported, on amd64 and arm64. The
CLI binary is downloaded only from `github.com/gocov/gocov/releases` and
verified against the release's sha256 checksums; the action has no
third-party action dependencies.

## Matrix builds (`part`)

When tests are split across jobs, upload each job's profile with a distinct
`part` and the server merges them into one report for the commit:

```yaml
jobs:
  test:
    strategy:
      matrix:
        shard: [unit, integration]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
      - run: go test -coverprofile=coverage.out ./... -run "${{ matrix.shard == 'unit' && 'TestUnit' || 'TestIntegration' }}"
      - uses: gocov/gocov-action@v1
        with:
          files: coverage.out
          token: ${{ secrets.GOCOV_TOKEN }}
          part: ${{ matrix.shard }}
```

`part` requires a gocov CLI version with multi-part upload support; set the
`version` input if the action's default pin doesn't include it yet.

## Self-hosting

The same action talks to your own gocov instance — just point `server` at
it:

```yaml
- uses: gocov/gocov-action@v1
  with:
    files: coverage.out
    token: ${{ secrets.GOCOV_TOKEN }}
    server: https://gocov.example.com
```

## Versioning

Use `gocov/gocov-action@v1` to track the latest v1 release, or pin an exact
tag (`@v1.0.0`). Each release pins a default gocov CLI version; `version`
overrides it.

## License

[MIT](LICENSE). The action is a thin wrapper around the gocov CLI and is
deliberately MIT-licensed so it never pulls AGPL terms into your workflow;
the gocov server remains separately licensed.
