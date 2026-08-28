#!/usr/bin/env bash
# Take a freshly started, empty Stash and leave it configured, scanned,
# phashed and seeded. Idempotent enough to re-run against a half-finished
# instance, but it is written for a throwaway container.
#
# Usage: scripts/stash-seed.sh [base-url]        (default http://localhost:9999)
#
# Paths are the ones INSIDE the container and must match the `docker run`
# that started it; override via the environment if you mount things elsewhere.

set -euo pipefail

BASE="${1:-http://localhost:9999}"
GQL="$BASE/graphql"

STASH_LIBRARY_DIR="${STASH_LIBRARY_DIR:-/library}"
STASH_CONFIG_PATH="${STASH_CONFIG_PATH:-/root/stash-config.yml}"
STASH_DATA_DIR="${STASH_DATA_DIR:-/root/stash-data}"

# Long enough to be a real failure rather than a slow runner. The whole
# sequence takes about 5s on four 21-45 kB clips; anything approaching this
# means the scan found a library it should not have.
JOB_TIMEOUT="${JOB_TIMEOUT:-180}"

# Send a GraphQL document. The query is JSON-encoded with jq rather than
# interpolated, so quotes and newlines inside it cannot break out of the
# request body. Errors are fatal here: a GraphQL error arrives as HTTP 200
# with an "errors" key, so `curl -f` would not notice it.
gql() {
  local query="$1" vars="${2-}" body resp
  [ -n "$vars" ] || vars='{}'
  body=$(jq -nc --arg q "$query" --argjson v "$vars" '{query: $q, variables: $v}')
  resp=$(curl -sS -m 120 -X POST -H 'Content-Type: application/json' --data-binary "$body" "$GQL")
  if jq -e '.errors' >/dev/null 2>&1 <<<"$resp"; then
    echo "stash-seed: GraphQL error" >&2
    jq -r '.errors' >&2 <<<"$resp"
    return 1
  fi
  printf '%s' "$resp"
}

# Block until a job leaves the queue. metadataScan/metadataGenerate return
# immediately with a job id and do the work on a worker, so without this the
# next step would query a database that is still being written. Polling rather
# than sleeping: the scan takes ~3s here but a cold runner is slower, and a
# fixed sleep is either flaky or wasteful.
#
# A job that has finished is eventually dropped from the queue entirely, so a
# null findJob means "done", not "lost" — treat it as success and let the
# assertions afterwards be the real check.
wait_for_job() {
  local id="$1" label="$2" started status
  started=$(date +%s)
  while :; do
    status=$(gql 'query($id: ID!) { findJob(input: {id: $id}) { status error } }' \
      "$(jq -nc --arg id "$id" '{id: $id}')" | jq -r '.data.findJob.status // "GONE"')
    case "$status" in
      FINISHED|GONE)
        echo "stash-seed: $label finished in $(( $(date +%s) - started ))s"
        return 0
        ;;
      FAILED|CANCELLED)
        echo "stash-seed: $label ended as $status" >&2
        return 1
        ;;
    esac
    if [ $(( $(date +%s) - started )) -ge "$JOB_TIMEOUT" ]; then
      echo "stash-seed: $label did not finish within ${JOB_TIMEOUT}s (last status $status)" >&2
      return 1
    fi
    sleep 1
  done
}

# --- 1. Configure ----------------------------------------------------------
# Stash v0.31.1 does NOT come up configured from STASH_* environment variables
# alone. With no config file it logs "Assuming new system", serves GraphQL, and
# sits in status SETUP with an empty library and no database — findScenes then
# panics on a nil repository. Of the documented variables only STASH_GENERATED
# and STASH_PORT actually took effect; STASH_DATABASE, STASH_STASH and
# STASH_BLOBS_PATH did not. The supported headless path is this mutation, which
# writes the config file and finishes the migration.
#
# `excludeVideo`/`excludeImage` are non-null in StashConfigInput, so omitting
# them fails validation before the mutation runs.
if [ "$(gql '{ systemStatus { status } }' | jq -r '.data.systemStatus.status')" = "SETUP" ]; then
  setup_vars=$(jq -nc \
    --arg cfg "$STASH_CONFIG_PATH" \
    --arg lib "$STASH_LIBRARY_DIR" \
    --arg data "$STASH_DATA_DIR" \
    '{i: {
        configLocation: $cfg,
        stashes: [{path: $lib, excludeVideo: false, excludeImage: false}],
        databaseFile: ($data + "/stash.sqlite"),
        generatedLocation: ($data + "/generated"),
        cacheLocation: ($data + "/cache"),
        blobsLocation: ($data + "/blobs"),
        storeBlobsInDatabase: false
      }}')
  gql 'mutation($i: SetupInput!) { setup(input: $i) }' "$setup_vars" >/dev/null
  echo "stash-seed: setup complete"
fi

# The setup mutation runs the schema migration on the way through, so give the
# instance a moment to report OK before asking it to scan.
for _ in $(seq 1 60); do
  [ "$(gql '{ systemStatus { status } }' | jq -r '.data.systemStatus.status')" = "OK" ] && break
  sleep 1
done

# --- 2. Scan ---------------------------------------------------------------
# Covers and phashes only. Previews, sprites and transcodes each re-encode
# every file and would dominate the runtime while proving nothing the
# assertions look at.
scan_job=$(gql 'mutation($i: ScanMetadataInput!) { metadataScan(input: $i) }' '{
  "i": {
    "rescan": false,
    "scanGenerateCovers": true,
    "scanGeneratePhashes": true,
    "scanGeneratePreviews": false,
    "scanGenerateImagePreviews": false,
    "scanGenerateSprites": false,
    "scanGenerateThumbnails": false,
    "scanGenerateClipPreviews": false
  }
}' | jq -r '.data.metadataScan')
wait_for_job "$scan_job" "metadataScan"

# --- 3. Phash generation ---------------------------------------------------
# The scan above already phashes new files, so this is normally a no-op that
# finishes instantly. It stays because it is the step that makes the
# duplicate-detection fixture a guarantee rather than a side effect: if a
# future Stash stops phashing during a scan, this still fills them in.
generate_job=$(gql 'mutation($i: GenerateMetadataInput!) { metadataGenerate(input: $i) }' '{
  "i": {
    "phashes": true,
    "covers": false,
    "sprites": false,
    "previews": false,
    "imagePreviews": false,
    "markers": false,
    "transcodes": false,
    "interactiveHeatmapsSpeeds": false,
    "imageThumbnails": false,
    "clipPreviews": false,
    "overwrite": false
  }
}' | jq -r '.data.metadataGenerate')
wait_for_job "$generate_job" "metadataGenerate (phashes)"

# --- 4. Non-file fixtures --------------------------------------------------
# A performer and a studio cannot fall out of a scan; they exist because
# Custodian's creator-name test skips itself when the library has neither.
# Created only when absent so a re-run does not pile up duplicates.
if [ "$(gql '{ findPerformers(filter: {per_page: 1}) { count } }' | jq -r '.data.findPerformers.count')" = "0" ]; then
  gql 'mutation { performerCreate(input: {name: "CI Fixture Performer"}) { id } }' >/dev/null
fi
if [ "$(gql '{ findStudios(filter: {per_page: 1}) { count } }' | jq -r '.data.findStudios.count')" = "0" ]; then
  gql 'mutation { studioCreate(input: {name: "CI Fixture Studio"}) { id } }' >/dev/null
fi

# The phash-duplicate pair also needs to agree on a stash-box id, so
# Custodian's stash_id evidence generator has something to cluster: a
# fabricated stashdb.org UUID on both dupe-source.mp4 and dupe-remux.mkv.
# Scene ids are not stable across a re-seed, so the pair is found by path
# rather than assumed to be scenes 2 and 3; skipped per-scene once already
# set, so a re-run does not just re-send the same mutation.
STASHDB_ENDPOINT="https://stashdb.org/graphql"
STASHDB_ID="00000000-0000-4000-8000-00000000c1a5"
for path in dupe-source.mp4 dupe-remux.mkv; do
  scene_id=$(gql 'query($v: String!) { findScenes(scene_filter: {path: {value: $v, modifier: INCLUDES}}) { scenes { id stash_ids { endpoint stash_id } } } }' \
    "$(jq -nc --arg v "$path" '{v: $v}')" | \
    jq -r --arg ep "$STASHDB_ENDPOINT" --arg id "$STASHDB_ID" '
      (.data.findScenes.scenes[0] // {}) as $s
      | (($s.stash_ids // []) | map(select(.endpoint == $ep and .stash_id == $id)) | length) as $already
      | if $already == 0 then ($s.id // empty) else empty end')
  if [ -n "$scene_id" ]; then
    gql 'mutation($i: SceneUpdateInput!) { sceneUpdate(input: $i) { id } }' \
      "$(jq -nc --arg id "$scene_id" --arg ep "$STASHDB_ENDPOINT" --arg sid "$STASHDB_ID" \
        '{i: {id: $id, stash_ids: [{endpoint: $ep, stash_id: $sid}]}}')" >/dev/null
    echo "stash-seed: set shared stash_id on scene $scene_id ($path)"
  fi
done

# --- 5. Report -------------------------------------------------------------
gql '{
  stats { scene_count performer_count studio_count }
  findDuplicateScenes(distance: 0) { id }
  sharedStashID: findScenes(scene_filter: {stash_id_endpoint: {modifier: NOT_NULL}}) { count }
}' | jq -c '{
  scenes: .data.stats.scene_count,
  performers: .data.stats.performer_count,
  studios: .data.stats.studio_count,
  duplicate_groups: (.data.findDuplicateScenes | length),
  shared_stash_id_scenes: .data.sharedStashID.count
}'
