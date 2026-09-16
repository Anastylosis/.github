# Anastylosis

> *Anastylosis (n.):* reassembling a ruin from its own scattered pieces, using
> original material wherever it can be found.

You have the file. That's the fragment.

The title, the performers, the studio, the release date, the subtitles, the
knowledge that two files on your disk are the same scene: all of it existed
somewhere, and most of it is still out there.

These tools go and find those pieces, and rebuild the whole thing around the
file you already have.

## The tools

| Project | The piece it recovers |
|---|---|
| [**FSS**](https://github.com/Anastylosis/FSS) | **The metadata itself.** Every scene a studio has published: title, performers, date, description, scraped from the studio's own site, across 1800+ sites and 30+ platforms. |
| [**Custodian**](https://github.com/Anastylosis/Custodian) | **Identity.** Which files are the same scene, which scene is missing its metadata, and what to do about it, safely. |
| [**MoanSubs**](https://github.com/Anastylosis/MoanSubs) | **Subtitles someone else already made.** A subtitle database keyed by video fingerprint, so a track reaches your copy even though your file is a different encode under a different name. Self-host the server and its Stash plugin, or point them at the public node on [moansubs.org](https://moansubs.org). |
| [**MoanDrop**](https://github.com/Anastylosis/MoanDrop) | **The same subtitles, with no Stash in the picture.** Drop a video on the window, or use the CLI, and the subtitle lands next to the file as a sidecar that Plex, Jellyfin, Kodi and VLC all pick up unprompted. |
| [**Scriptorium**](https://github.com/Anastylosis/Scriptorium) | **Subtitles that don't exist yet.** faster-whisper transcribes, Ollama translates, both on your own hardware. Point it at a folder and leave it alone, or let it take requests from Stash tags. |
| [**MSD**](https://github.com/Anastylosis/MSD) | **The material.** Resolves album, folder, and creator URLs into files and fetches them concurrently, with resume. |

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

**Windows** gets no package manager, but it is a supported platform: the full
test suite runs on `windows-latest` in CI, not just a cross-compile. Grab
`fss-<version>-windows-amd64.zip`, extract `fss.exe`, and put it on your
`PATH`; there is a PowerShell walkthrough in
[FSS's README](https://github.com/Anastylosis/FSS#windows-powershell). One
thing to know: the lock that stops two scrapes of the same studio colliding
is a no-op there, so do not run overlapping scrapes of the same URL.

## Building on them

Three pieces were pulled out of the tools above because they are useful on
their own:

- [**stash-go**](https://github.com/Anastylosis/stash-go), a dependency-free Go
  client for a running Stash server's GraphQL API.
- [**mediahash**](https://github.com/Anastylosis/mediahash), which computes
  Stash's `oshash` and perceptual video hash bit-for-bit, without importing the
  Stash module or running a Stash.
- [**subtitlematch**](https://github.com/Anastylosis/subtitlematch), which pairs
  loose subtitle files with the videos they belong to when the filenames only
  partly agree, using studio codes, title tokens and runtime.

FSS also exposes its scraper registry, scene model and matching engine as
[importable
packages](https://github.com/Anastylosis/FSS/blob/master/docs/library.md).

## What these are, and are not

Self-hosted, offline-capable, and built to run against libraries you own. They
read public pages and write to your disk, and nothing reports back on what your
library holds. MoanSubs is the one that talks to a server, and only halfway:
looking a subtitle up is anonymous and needs no account, the lookup sends
bucketed hash prefixes rather than your file's fingerprint, and only sharing a
subtitle back needs a free account on whichever node you use, which can be one
you run yourself.

[Stash](https://stashapp.cc) is the media manager these integrate with most
deeply, but a media manager is not a requirement: MoanDrop writes sidecars any
player reads, Scriptorium is happy watching a folder, and FSS will write JSON
or NFO and leave the filing to you.
[COVE](https://github.com/yourcove/cove) support is planned, and more players
after it. The pieces these tools recover belong to your library, not to
whichever thing happens to be cataloguing it.

---

Shared CI/CD lives in [`.github`](https://github.com/Anastylosis/.github); the
Homebrew formulae in [`homebrew-tap`](https://github.com/Anastylosis/homebrew-tap).
