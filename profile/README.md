# Anastylosis

> *Anastylosis (n.):* reassembling a ruin from its own scattered pieces, using
> original material wherever it can be found.

You have the file. That's the fragment.

The title, the performers, the studio, the release date, the subtitles, the
knowledge that two files on your disk are the same scene — all of it existed
somewhere, and most of it is still out there.

These tools go and find those pieces, and rebuild the whole thing around the
file you already have.

## The tools

| Project | The piece it recovers |
|---|---|
| [**FSS**](https://github.com/Anastylosis/FSS) | **The metadata itself.** Every scene a studio has published — title, performers, date, description - scraped from the studio's own site, across 1,670+ of them. |
| [**Custodian**](https://github.com/Anastylosis/Custodian) | **Identity.** Which files are the same scene, which scene is missing its metadata, and what to do about it - safely. |
| [**MSD**](https://github.com/Anastylosis/MSD) | **The material.** Resolves album, folder, and creator URLs into files and fetches them concurrently, with resume. |
| [**subtitlematch**](https://github.com/Anastylosis/subtitlematch) | **Subtitles you already have.** Pairs loose subtitle files with the videos they belong to when the filenames only partly agree. |
| [**Scriptorium**](https://github.com/Anastylosis/Scriptorium) | **Subtitles that don't exist yet.** Transcription and translation for the scenes you mark, generated on your own hardware. |

**MoanSubs** - a subtitle database keyed by video fingerprint, so a subtitle
reaches your copy even though your file differs from the one it was made for -
is still private. It will appear here when it is ready to be used by someone
who did not write it.

## Start here

FSS is the one to try first: it is the piece everything else builds on, and it
works against a library you already have.

```sh
yay -S fss                          # Arch
sudo dpkg -i fss_*_amd64.deb        # Debian, Ubuntu
sudo rpm -i fss-*.x86_64.rpm        # Fedora, RHEL
brew install anastylosis/tap/fss    # Homebrew, on Linux or macOS

fss scrape https://example.com/studio/some-studio
```

The `.deb` and `.rpm` are on the
[releases page](https://github.com/Anastylosis/FSS/releases/latest), alongside
a multi-arch Docker image and plain binaries for Linux, macOS and Windows.
Full instructions, including checksum and attestation verification, are in
[FSS's README](https://github.com/Anastylosis/FSS#install).

**Windows** gets no package manager, but it is a supported platform - the full
test suite runs on `windows-latest` in CI, not just a cross-compile. Grab
`fss-<version>-windows-amd64.zip`, extract `fss.exe`, and put it on your
`PATH`; there is a PowerShell walkthrough in
[FSS's README](https://github.com/Anastylosis/FSS#windows-powershell). One
thing to know: the lock that stops two scrapes of the same studio colliding
is a no-op there, so do not run overlapping scrapes of the same URL.

## Building on them

[**stash-go**](https://github.com/Anastylosis/stash-go) is a dependency-free Go
client for a running Stash server's GraphQL API — pulled out of these tools so
it is useful on its own. FSS also exposes its scraper registry, scene model and
matching engine as [importable
packages](https://github.com/Anastylosis/FSS/blob/master/docs/library.md).

## What these are, and are not

Self-hosted, offline-capable, and built to run against libraries you own. They
read public pages and write to your disk; none of them phone home, and none of
them need an account with us, because there is no us to have an account with.

[Stash](https://stashapp.cc) is the media manager these integrate with today.
[COVE](https://github.com/yourcove/cove) support is planned, and more players
after it. The pieces these tools recover belong to your library - not to
whichever thing happens to be cataloguing it.

---

Shared CI/CD lives in [`.github`](https://github.com/Anastylosis/.github); the
Homebrew formulae in [`homebrew-tap`](https://github.com/Anastylosis/homebrew-tap).
