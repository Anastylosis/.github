# Contributing

Org-wide default. A repository with its own `CONTRIBUTING.md` overrides this.

These are small projects maintained by one person. That has two consequences
worth stating up front: a pull request may sit for a while before it gets
attention, and a *small* PR will get attention sooner than a large one. If you
are planning something substantial, open an issue first — not for permission,
but so you don't build something that turns out to duplicate work in progress.

## Before you start

**Open an issue for bugs and features.** For a typo or an obviously-correct
one-line fix, just send the PR.

**Say what you actually observed.** For a scraping or parsing bug, the useful
report is the input that broke it — the URL, the filename, the fixture — not a
description of the wrong output. The input is what becomes a regression test.

## Working on it

Every repo has a `Makefile`. `make help` lists the targets. In general:

```sh
make build     # build the binary
make test      # unit tests, race detector on
make lint      # go vet + golangci-lint
```

Three norms that CI enforces, so it's cheaper to know them now:

**Offline means offline.** Unit tests must not touch the network. A test that
reaches a live site passes on your machine and hides the fact that the code
under it is broken — this has happened, and the fix was a CI job that runs the
suite in a network namespace with only loopback up. Use fixtures. Where a repo
has live-site tests, they sit behind a `//go:build integration` tag and are run
manually, never in CI.

**Tests are part of the change.** A bug fix without a test that fails before it
is not finished. For parsers, the fixture that reproduced the bug is the test.

**Commits should explain why, not what.** The diff already says what changed.
The message is for the person — probably you, in a year — trying to work out
what problem this solved and what they'll break by undoing it.

## Signing

Commits in these repos are GPG-signed. If you're set up for it, please sign
yours:

```sh
git config --global user.signingkey <your-key-id>
git config --global commit.gpgsign true
```

If you aren't, say so in the PR rather than skipping it silently — it's not a
barrier to contributing, but the maintainer needs to know before merging.

## Pull requests

Branch from `master` (all repos here use `master`, not `main`).

CI runs tests, lint and a vulnerability scan on every PR. It must be green
before review, and the fastest way to get a PR merged is for it to arrive that
way. If a check fails for a reason unrelated to your change, say so — don't
force-push over it and hope.

Keep the PR to one thing. A change that fixes a bug and also reformats a file
and also renames a variable is three reviews wearing a trenchcoat.

## Releases

Maintainer only. Releases are cut by pushing a `v*` tag; the pipeline builds
binaries and packages, generates checksums, attaches SLSA build attestations,
and publishes. Some repos gate this behind a manual approval so a human can
confirm the checks CI cannot run were actually run.

You don't need to touch versioning in a PR.

## Security

Don't open a public issue for anything exploitable. See [SECURITY.md](SECURITY.md).
