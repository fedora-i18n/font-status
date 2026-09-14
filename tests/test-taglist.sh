#!/usr/bin/env bash
#
# Tests for .github/scripts/taglist.sh — selects the date tags at which a
# file's font data really changed, ignoring the volatile fq_id.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
script="$here/../.github/scripts/taglist.sh"

fail=0
check() { # desc actual expected
    if [ "$2" = "$3" ]; then
        echo "ok   - $1"
    else
        echo "FAIL - $1 (got '$2', want '$3')"
        fail=1
    fi
}

repo=$(mktemp -d)
(
    cd "$repo"
    git init -q
    git config user.email t@example.com
    git config user.name test
    mkdir json

    commit_tag() { # date fq_id family
        cat > json/x.json <<EOF
{"id":"fedora","fq_id":"$2","fonts":[{"lang":"af","family":"$3"}]}
EOF
        git add json/x.json
        GIT_AUTHOR_DATE="$1T00:00:00" GIT_COMMITTER_DATE="$1T00:00:00" \
            git commit -q -m "$1"
        git tag "$1"
    }

    # 0101: first appearance -> change point
    commit_tag 20260101 100 "Noto Sans"
    # 0102: only fq_id changed -> NOT a change point (legacy noise commit+tag)
    commit_tag 20260102 200 "Noto Sans"
    # 0103: real font change -> change point
    commit_tag 20260103 300 "Cantarell"
    # 0104: fq_id-only again -> NOT a change point
    commit_tag 20260104 400 "Cantarell"
)

out=$(cd "$repo" && "$script" json/x.json 12)
check "only real change points selected" "$out" '["20260101","20260103"]'

out=$(cd "$repo" && "$script" json/x.json 1)
check "max_count keeps newest only" "$out" '["20260103"]'

out=$(cd "$repo" && "$script" json/missing.json 12)
check "missing file yields empty array" "$out" '[]'

rm -rf "$repo"

if [ "$fail" -ne 0 ]; then
    echo "TESTS FAILED"
    exit 1
fi
echo "All tests passed"
