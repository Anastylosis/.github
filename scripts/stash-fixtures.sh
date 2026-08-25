#!/usr/bin/env bash
# Generate a tiny, deterministic Stash library for integration tests.
#
# Everything here exists to make a *specific* Stash behaviour observable, and
# each file is shaped by how Stash identifies and de-duplicates media:
#
#   * oshash is computed from the file size plus its head and tail bytes, so
#     two byte-identical copies under different names hash the same and Stash
#     folds them into ONE scene with TWO files. That is the only way to get a
#     multi-file scene without touching the database.
#   * phash is computed from the decoded frames, so remuxing a clip into a
#     different container changes the size (hence the oshash) while leaving
#     every frame — hence the phash — identical. That is a duplicate pair at
#     distance 0, in two separate scenes.
#
# Do not "tidy" the two clips into one source: if both scenes shared a phash
# the duplicate group would swallow the multi-file scene as well, and a test
# asserting "exactly one group" would see something else.
#
# Determinism matters because a re-run must not produce a different oshash and
# invalidate a cached database. `-fflags/-flags +bitexact` and
# `-map_metadata -1` strip the encoder string and the creation timestamp,
# which otherwise land in the container header and change the file byte for
# byte on every run. The lavfi sources used (testsrc, mandelbrot) take no
# random input, so the pixels are fixed too.
#
# Usage: scripts/stash-fixtures.sh [library-dir]   (default ./stash-library)

set -euo pipefail

LIB="${1:-./stash-library}"

command -v ffmpeg >/dev/null 2>&1 || {
  echo "stash-fixtures: ffmpeg not found on PATH" >&2
  exit 1
}

rm -rf "$LIB"
mkdir -p "$LIB"

# Small on purpose: a scan plus phash generation over these has to finish in
# seconds, and Stash decodes every frame to phash a file. 160x120 at 10fps for
# 2s is 20 frames per clip.
BITEXACT=(-fflags +bitexact -flags +bitexact -map_metadata -1)
ENCODE=("${BITEXACT[@]}" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -g 10)
FF=(ffmpeg -hide_banner -loglevel error -y)

# --- Fixture 1: multi-file scene -------------------------------------------
# One encode, copied twice. Identical bytes => identical oshash => one scene
# holding two files.
"${FF[@]}" -f lavfi -i "testsrc=size=160x120:rate=10:duration=2" \
  "${ENCODE[@]}" "$LIB/multifile-take1.mp4"
cp "$LIB/multifile-take1.mp4" "$LIB/multifile-take2.mp4"

# --- Fixture 2: phash duplicate pair ---------------------------------------
# Visually unrelated to fixture 1 so the two never share a phash bucket.
# The mkv is a stream copy: same frames, different container, different size.
"${FF[@]}" -f lavfi -i "mandelbrot=size=160x120:rate=10" -t 2 \
  "${ENCODE[@]}" "$LIB/dupe-source.mp4"
"${FF[@]}" -i "$LIB/dupe-source.mp4" \
  "${BITEXACT[@]}" -c copy "$LIB/dupe-remux.mkv"

# A remux that happened to produce the same size would silently turn the
# duplicate pair back into a multi-file scene, and the failure would surface
# far away as "no duplicate groups found". Catch it here instead.
if [ "$(stat -c %s "$LIB/dupe-source.mp4")" = "$(stat -c %s "$LIB/dupe-remux.mkv")" ]; then
  echo "stash-fixtures: remux is the same size as its source; oshash would collide" >&2
  exit 1
fi

echo "stash-fixtures: wrote library to $LIB"
ls -l "$LIB"
