#!/usr/bin/env bash
#
# taglist.sh TARGET MAX
#
# Print a JSON array of the date tags (YYYYMMDD) at which TARGET's font data
# actually changed, newest MAX kept. Comparison is done with fq_id removed
# (fontquery stamps a fresh fq_id build timestamp on every run), so the result
# is independent of the raw commit history, which may still contain legacy
# fq_id-only commits that touch the file without changing any font.
#
# Must be run inside the git working tree that holds the tags.
set -euo pipefail

target="$1"
max="$2"

prev=""
sel=""
for t in $(git tag | grep -E '^[0-9]{8}$' | sort); do
    c=$(git show "$t:$target" 2>/dev/null | jq -S 'del(.fq_id)' 2>/dev/null || true)
    # Skip tags where the file did not exist yet.
    [ -z "$c" ] && continue
    [ "$c" != "$prev" ] && sel="$sel $t"
    prev="$c"
done

# Keep the newest ${max} change points.
sel=$(echo $sel | tr ' ' '\n' | grep . | tail -n "$max" || true)
json="["
for t in $sel; do json="$json\"$t\","; done
json="${json%,}]"
echo "$json"
