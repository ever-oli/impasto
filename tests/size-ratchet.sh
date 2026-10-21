#!/bin/sh
# The size ratchet: no file may grow past the cap, and the ones recorded
# in the manifest may only get smaller. The same rule the pre-commit
# hook keeps, run over everything that is tracked.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
CAP=20000
fail=0

# The recorded ones: they may only shrink.
awk -F'\t' 'NF == 2 {print $1, $2}' .size-ratchet | while read -r size file; do
    [ -z "${file:-}" ] && continue
    case "$file" in \#*) continue ;; esac
    [ -f "$file" ] || continue
    now=$(wc -c < "$file")
    if [ "$now" -gt "$size" ]; then
        echo "$file is $now bytes; the ratchet allows $size"
        exit 1
    fi
done || fail=1

# Everything else: under the cap.
recorded=$(awk -F'\t' 'NF == 2 {print $2}' .size-ratchet)
git ls-files | while read -r file; do
    if printf '%s\n' "$recorded" | grep -qxF "$file"; then
        continue
    fi
    case "$file" in
        .*|.githooks/*|.github/*|tests/*) continue ;;
        *.png|*.jpg|*.jpeg|*.webp|*.gif|*.svg|*.mp4|*.webm|*.wav|*.flac|*.ogg|\
        *.woff*|*.ttf|*.otf|*.asar|*.lock|*package-lock.json|LICENSE*|THIRD_PARTY*|\
        CREDITS*|CHANGELOG*|MAINTAINING.md|.size-ratchet) continue ;;
    esac
    [ -f "$file" ] || continue
    now=$(wc -c < "$file")
    if [ "$now" -gt "$CAP" ]; then
        echo "$file is $now bytes, over the $CAP cap"
        exit 1
    fi
done || fail=1

exit $fail
