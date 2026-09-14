#!/usr/bin/env bash
#
# update-json.sh JSON_DIR FILE...
#
# Move freshly built fontquery JSON files into the tracked JSON_DIR, but skip
# files whose only difference from the committed copy is the volatile "fq_id"
# build timestamp that fontquery stamps into every run. Without this, git would
# see a diff on every run and force a daily commit (and thus a daily tag) even
# when no font actually changed.
set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 JSON_DIR [FILE...]" >&2
    exit 2
fi

json_dir="$1"
shift

for f in "$@"; do
    # A non-matching glob is passed through literally; ignore those.
    [ -e "$f" ] || continue
    b=$(basename "$f")
    cur="$json_dir/$b"
    if [ -f "$cur" ] && diff -q \
            <(jq -S 'del(.fq_id)' "$cur") \
            <(jq -S 'del(.fq_id)' "$f") >/dev/null 2>&1; then
        echo "No font change in $b (fq_id only); keeping committed version"
    else
        echo "Font change detected in $b; updating"
        mv "$f" "$json_dir/"
    fi
done
