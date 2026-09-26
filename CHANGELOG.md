# Changelog

## 1.20.0

- Pin gocov CLI v0.26.1 (was v0.26.0).

## 1.19.0

- Pin gocov CLI v0.26.0 (was v0.25.0).
- docs: badge URLs carry the forge (gocov v0.25.0)

## 1.18.0

- Pin gocov CLI v0.25.0 (was v0.24.0).

## 1.17.0

- Pin gocov CLI v0.24.0 (was v0.23.0).

## 1.16.0

- Pin gocov CLI v0.23.0 (was v0.22.0).

## 1.15.0

- Pin gocov CLI v0.22.0 (was v0.21.0).

## 1.14.0

- Pin gocov CLI v0.21.0 (was v0.20.0).
- docs: say the workspace, not the repo, must exist for OIDC uploads (#22)

## 1.13.0

- Pin gocov CLI v0.20.0 (was v0.19.0).

## 1.12.0

- Pin gocov CLI v0.19.0 (was v0.18.0).

## 1.11.0

- Pin gocov CLI v0.18.0 (was v0.17.0).
- Retry CLI downloads on every transport error (#16)
- Move the workflows' actions to their Node 24 releases (#17)
- Bump the actions group with 2 updates (#18)

## 1.10.0

- Pin gocov CLI v0.17.0 (was v0.16.0).
- Add an `ignore` input for files that should not count toward coverage (#14)

## 1.9.0

- Pin gocov CLI v0.16.0 (was v0.15.0).
- docs: link the README coverage badges to their report pages (#11)
- Support tokenless OIDC uploads (#12)

## 1.8.0

- Pin gocov CLI v0.15.0 (was v0.14.0).

## 1.7.0

- Fork PRs upload tokenless through the GitHub App (#8)

## 1.6.0

- Pin gocov CLI v0.14.0 (was v0.13.2).
- The action checks its own version pin (#7)

## 1.5.0

- Pin gocov CLI v0.13.2 (was v0.13.1).

## 1.4.0

- Pin gocov CLI v0.13.1 (was v0.12.0).
- Point the README at docs.gocov.dev (#3)
- Merging a labeled bump PR is the release (#4)

## 1.3.0

- Pin gocov CLI v0.12.0 (was v0.11.0).

## 1.2.0

- Pin gocov CLI v0.11.0 (was v0.9.0).

## 1.1.0

- Pin gocov CLI v0.9.0 (was v0.8.3).
- Add coverage and CI badges to the README

## 1.0.1

- Drop the secrets expression example from the token description
- Strip sha256sum's escaped-format backslash prefix
- Fold the backslash strip into awk to appease shellcheck

## 1.0.0

- First release: install gocov CLI v0.8.3, verify its sha256, upload.
- Gate dogfood upload on the secret via job env, not steps.if
- Run CI steps under bash on all runners
