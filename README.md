# Anastylosis/.github

Reusable GitHub Actions workflows and org-wide defaults for the Anastylosis
projects, Go and Python alike.

Each project used to carry its own hand-maintained copy of the same pipeline.
They drifted — most visibly in action pins, where the same action sat at three
different versions across repos at once. These are the workflows themselves,
factored out so a change lands once.

## Workflows

| Workflow | Replaces | Notes |
|---|---|---|
| `python-ci.yml` | a Python repo's `ci.yml` | lint · test · informational pip-audit, plus opt-in offline isolation |
| `go-ci.yml` | a repo's `ci.yml` | test · lint · vulncheck · cross-build, plus opt-in platform, offline-isolation and fuzz jobs |
| `go-release.yml` | a repo's `release.yml` | build · SHA256SUMS · attestation · changelog · GitHub release, plus opt-in nfpm and AUR |
| `docker-publish.yml` | a repo's `docker.yml` **and** the docker job in its `release.yml` | one workflow, `mode: dev` or `mode: release` |
| `dependency-review.yml` | a repo's `dependency-review.yml` | opt-in; flags a PR introducing a known-vulnerable dependency |
| `codeql.yml` | a repo's `codeql.yml` | opt-in; taint tracking, for code that parses input it does not control |

Ready-to-copy caller files are in [`docs/callers/`](docs/callers/).

## Using these

```yaml
jobs:
  ci:
    uses: Anastylosis/.github/.github/workflows/go-ci.yml@v1
    permissions:
      contents: read
      checks: write
    secrets: inherit
    with:
      binary-name: my-tool
```

Three things that bite:

- **The path is doubled.** Reusable workflows must live in `.github/workflows/`
  of the repository that hosts them, and this repository is named `.github` —
  hence `Anastylosis/.github/.github/workflows/…`. Not a typo.
- **`secrets: inherit` is required** for anything using `AUR_SSH_PRIVATE_KEY`.
  Reusable workflows receive no secrets by default. Codecov needs no secret at
  all — it authenticates with an OIDC token, which is why the CI callers grant
  `id-token: write`.
- **Permissions are capped by the caller, and a shortfall is fatal.** The
  `permissions:` block in the calling job is the ceiling; the reusable
  workflow cannot grant itself more. If it *requests* more, the run fails at
  startup — `startup_failure`, before a single step executes and with no log
  to read.

  In particular **every `go-ci.yml` caller must grant `id-token: write`**, even
  with `codecov: false`, because the test job declares it unconditionally for
  Codecov's OIDC auth. Copy the blocks from `docs/callers/` verbatim.

## Action pinning policy

Actions are pinned to **exact versions**, not moving major tags. A major tag
like `@v7` advances whenever `v7.x` ships, so an unrelated commit can turn CI
red — which is how one repo's linter silently moved from v1 to v2.

The reason to avoid exact pinning is normally that it means one Dependabot PR
per repo per bump. Centralising here makes it one PR total, so the policy costs
nothing.

## Versioning

Callers pin `@v1`. Push a moving `v1` tag on every backward-compatible change:

```sh
git tag -fa v1 -m "v1: <what changed>" && git push --force origin v1
```

Breaking an input means `v2` and a per-repo migration, so prefer adding an
input with a default that preserves current behaviour.

`@v1` moving is a deliberate exception to the pinning policy above: this
repository is ours, and pinning callers to a SHA would mean a PR per repo per
change — the exact problem this repository exists to remove.

## What deliberately stays per-repo

- **`scripts/go-version.sh`.** Still useful locally
  (`docker build --build-arg GO_VERSION=$(scripts/go-version.sh) .`), but the
  workflows read `go.mod` inline, so no repo needs a copy for CI to work.
- **Release install instructions.** Genuinely per-project; passed in via the
  `install-instructions` input. The checksum and attestation verification
  sections that follow it were identical everywhere and are generated here.

## License

GPL-3.0-only, matching the projects it serves. See [LICENSE](LICENSE).
