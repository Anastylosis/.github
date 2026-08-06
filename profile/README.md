# Anastylosis

> *Anastylosis (n.):* reassembling a ruin from its own scattered pieces, using
> original material wherever it can be found.

You have the file. That's the fragment.

The title, the performers, the studio, the release date, the subtitles, the
knowledge that two files on your disk are the same scene — all of it existed
somewhere, and most of it is still out there.

These tools go and find those pieces, and rebuild the whole thing around the
file you already have.

| Project | The piece it recovers |
|---|---|
| [**Custodian**](https://github.com/Anastylosis/Custodian) | **Identity.** Which files are the same scene, which scene is missing its metadata, and what to do about it — safely. |
| [**MoanSubs**](https://github.com/Anastylosis/MoanSubs) | **Subtitles that already exist.** A database keyed by video fingerprint, so a subtitle reaches your copy even though your file differs from the one it was made for. |
| [**Scriptorium**](https://github.com/Anastylosis/Scriptorium) | **Subtitles that don't exist yet.** Transcription and translation for the scenes you mark, generated on your own hardware. |
| [**MSD**](https://github.com/Anastylosis/MSD) | **The material.** Resolves album, folder, and creator URLs into files and fetches them concurrently, with resume. |

Self-hosted, offline-capable, and built to run against libraries you own.

[Stash](https://stashapp.cc) is the media manager these integrate with today.
[COVE](https://github.com/yourcove/cove) support is planned, and more players
after it. The pieces these tools recover belong to your library — not to
whichever thing happens to be cataloguing it.

Shared CI/CD lives in [`.github`](https://github.com/Anastylosis/.github).
