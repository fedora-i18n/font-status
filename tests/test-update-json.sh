#!/usr/bin/env bash
#
# Tests for .github/scripts/update-json.sh — the fq_id-aware JSON updater that
# prevents spurious daily commits/tags.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
script="$here/../.github/scripts/update-json.sh"

fail=0
check() { # desc actual expected
    if [ "$2" = "$3" ]; then
        echo "ok   - $1"
    else
        echo "FAIL - $1 (got '$2', want '$3')"
        fail=1
    fi
}

# fq_id-only change: committed file must be preserved untouched.
work=$(mktemp -d)
mkdir -p "$work/json" "$work/out"
cat > "$work/json/a.json" <<'EOF'
{"id":"fedora","fq_id":"20260101000000","fonts":[{"lang":"af","family":"Noto Sans"}]}
EOF
cat > "$work/out/a.json" <<'EOF'
{"id":"fedora","fq_id":"20260914999999","fonts":[{"lang":"af","family":"Noto Sans"}]}
EOF
before=$(cat "$work/json/a.json")
"$script" "$work/json" "$work/out/a.json" >/dev/null
after=$(cat "$work/json/a.json")
check "fq_id-only change keeps committed version" "$after" "$before"
check "fq_id-only change leaves output in place (no move)" "$([ -e "$work/out/a.json" ] && echo yes || echo no)" "yes"
rm -rf "$work"

# Real font change: committed file must be replaced by the new one.
work=$(mktemp -d)
mkdir -p "$work/json" "$work/out"
cat > "$work/json/b.json" <<'EOF'
{"id":"fedora","fq_id":"20260101000000","fonts":[{"lang":"af","family":"Noto Sans"}]}
EOF
cat > "$work/out/b.json" <<'EOF'
{"id":"fedora","fq_id":"20260914999999","fonts":[{"lang":"af","family":"Cantarell"}]}
EOF
new=$(jq -S 'del(.fq_id)' "$work/out/b.json")
"$script" "$work/json" "$work/out/b.json" >/dev/null
check "real font change updates committed version" "$(jq -S 'del(.fq_id)' "$work/json/b.json")" "$new"
rm -rf "$work"

# New file (no committed counterpart): must be moved in.
work=$(mktemp -d)
mkdir -p "$work/json" "$work/out"
cat > "$work/out/c.json" <<'EOF'
{"id":"fedora","fq_id":"20260914999999","fonts":[]}
EOF
"$script" "$work/json" "$work/out/c.json" >/dev/null
check "brand-new file is added" "$([ -f "$work/json/c.json" ] && echo yes || echo no)" "yes"
rm -rf "$work"

if [ "$fail" -ne 0 ]; then
    echo "TESTS FAILED"
    exit 1
fi
echo "All tests passed"
