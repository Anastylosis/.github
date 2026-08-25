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
| `tofu-ci.yml` | an OpenTofu/Terraform repo's `ci.yml` | `fmt -check` and `validate`; deliberately no `plan` |
| `python-ci.yml` | a Python repo's `ci.yml` | lint · test · informational pip-audit, plus opt-in offline isolation |
| `go-ci.yml` | a repo's `ci.yml` | test · lint · vulncheck · cross-build, plus opt-in platform, offline-isolation and fuzz jobs |
| `go-release.yml` | a repo's `release.yml` | build · SHA256SUMS · attestation · changelog · GitHub release, plus opt-in nfpm, AUR and Homebrew |
| `docker-publish.yml` | a repo's `docker.yml` **and** the docker job in its `release.yml` | one workflow, `mode: dev` or `mode: release` |
| `dependency-review.yml` | a repo's `dependency-review.yml` | opt-in; flags a PR introducing a known-vulnerable dependency |
| `stash-integration.yml` | a manual "I tested it against my Stash" release gate | boots a throwaway Stash, seeds a fixture library, runs the caller's integration suite against it |

CodeQL is GitHub's default setup, enabled per repo in Settings → Code security;
there is deliberately no reusable workflow for it.

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
- **`secrets: inherit` is required** for anything using `AUR_SSH_PRIVATE_KEY`
  or `HOMEBREW_TAP_SSH_KEY`. Reusable workflows receive no secrets by default.
  Codecov needs no secret at all — it authenticates with an OIDC token, which
  is why the CI callers grant `id-token: write`.
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

Callers pin `@v1`, and `v1` is a pointer you move by hand. **`uses:` resolves
the literal ref** — a SHA, a tag, or a branch. There is no semver lookup, so
tagging `v1.2.0` and stopping there changes nothing for any caller, and the
edit looks like it simply had no effect. Moving `v1` is the act that ships it.

On every backward-compatible change, tag the release and move the pointer:

```sh
git tag -a v1.2.0 -m "<what changed>" && git push origin v1.2.0
git tag -f v1 v1.2.0^{} && git push --force origin v1
```

The immutable `v1.x.y` tag is what you pin to if a `v1` ever breaks a repo, and
the only way to answer "what did `v1` mean last month". It is optional; `v1`
alone works.

The `release-tags` ruleset protects `refs/tags/v*.*.*` against deletion and
update, so `v1.2.0` cannot be rewritten. It deliberately does **not** match
`refs/tags/v*`, or it would also freeze `v1` — the one tag that has to move.
Widening that pattern will break releases.

Breaking an input means `v2` and a per-repo migration, so prefer adding an
input with a default that preserves current behaviour.

`@v1` moving is a deliberate exception to the pinning policy above: this
repository is ours, and pinning callers to a SHA would mean a PR per repo per
change — the exact problem this repository exists to remove.

## Publishing to the Homebrew tap

`go-release.yml` renders the caller's `packaging/homebrew/<formula>.rb`
template into [`homebrew-tap`](https://github.com/Anastylosis/homebrew-tap),
substituting the version and the per-platform checksums it reads back out of
that release's own `SHA256SUMS` — so a formula cannot claim a hash the release
does not have. Set `homebrew: true` and `homebrew-tap: Anastylosis/homebrew-tap`.

The credential is `HOMEBREW_TAP_SSH_KEY`, an org secret holding a **write
deploy key** on the tap. A deploy key rather than a token because it never
expires (nothing to rotate) and reaches exactly one repository; `GITHUB_TOKEN`
cannot write to another repo at all. Deploy keys are enabled org-wide, which
they are not by default.

One tap holds every project's formula, so two repos releasing at once both
clone, commit and push, and the slower one is rejected as non-fast-forward.
The job rebases and retries — the commits touch different `Formula/*.rb` files,
so there is nothing to conflict over.

The tap has its own CI that runs `brew audit --online`, `brew install` and
`brew test` on every formula, plus a weekly cron: formulae point at release
assets, so a deleted or retagged release breaks installs without anything in
either repository changing.

## Stash integration

`stash-integration.yml` starts `stashapp/stash` in a container, generates a
four-clip library with the ffmpeg inside that image (the runner image no
longer ships one), scans and phashes it, creates a performer and a
studio, then runs the caller's test command with the endpoint in the
environment. The caller needs `contents: read` and nothing else — no OIDC
token, no secrets.

| Input | Default | What it is for |
|---|---|---|
| `url-env-var` | *(required)* | Variable the tests read the URL from. Custodian uses `SFX_INT_STASH_URL`, stash-go uses `STASH_URL` |
| `seeded-env-var` | `''` | Exported as `1`. The switch that lets tests **assert** the fixtures exist instead of skipping on an empty library |
| `api-key-env-var` | `''` | Exported **empty** — Stash runs unauthenticated here (see below) |
| `test-command` | `go test -tags=integration -count=1 ./...` | Run under `bash -c` |
| `go-version-file` | `go.mod` | Empty skips `setup-go`, for a non-Go test command |
| `stash-image` | `stashapp/stash:v0.31.1` | Pinned |
| `stash-port` | `9999` | Published straight through to the container |
| `harness-ref` | `v1` | Ref this repo's `scripts/stash-*.sh` are taken from |

What the fixtures give the tests: **three scenes**, one of them a single scene
holding **two files** with the same oshash; **one duplicate group** at phash
distance 0 (an mp4 and its stream-copy mkv remux); **one performer and one
studio**. Scan plus phash takes about five seconds.

Two things worth knowing before adopting it:

- **`seeded-env-var` is what makes the job able to fail.** A suite that skips
  when it finds nothing passes just as happily against an empty Stash, and
  that is the state most integration tests are written in. Gate the
  assertions on this variable and keep the old skip when `url-env-var` is
  unset, so a plain `go test ./...` stays hermetic.
- **Stash boots headless via a GraphQL mutation, not env vars.** Contrary to
  what the `STASH_*` variables suggest, v0.31.1 comes up in `SETUP` state with
  an empty library and panics on `findScenes`; `scripts/stash-seed.sh` calls
  `setup(input: {...})` to write the config and migrate. The same reason there
  is no API key: `generateAPIKey` returns `""` until a username is configured,
  and configuring one locks the instance to 401 before the key can be read.

## What deliberately stays per-repo

- **`scripts/go-version.sh`.** Still useful locally
  (`docker build --build-arg GO_VERSION=$(scripts/go-version.sh) .`), but the
  workflows read `go.mod` inline, so no repo needs a copy for CI to work.
- **Release install instructions.** Genuinely per-project; passed in via the
  `install-instructions` input. The checksum and attestation verification
  sections that follow it were identical everywhere and are generated here.

## License

GPL-3.0-only, matching the projects it serves. See [LICENSE](LICENSE).
