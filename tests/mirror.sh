#!/bin/sh
# The repository is the source; the machine is the install. Every file
# the packages own must be the same file in both.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
fail=0
for manifest in packages/*/install; do
    dir=$(dirname "$manifest")
    while read -r src dst; do
        [ -z "${src:-}" ] && continue
        case "$src" in \#*) continue ;; esac
        [ -e "$dir/$src" ] || continue
        if [ -d "$dir/$src" ]; then
            (cd "$dir/$src" && find . \( -type f -o -type l \) -printf '%P\n') | while read -r rel; do
                live="$HOME/$dst/$rel"
                case "$rel" in __pycache__/*|*.pyc) continue ;; esac
                if [ ! -e "$live" ]; then
                    echo "missing on the machine: $live"
                    exit 1
                fi
                cmp -s "$dir/$src/$rel" "$live" || {
                    echo "differs: $live"
                    exit 1
                }
            done || fail=1
            continue
        fi
        case "$src" in __pycache__/*|*.pyc) continue ;; esac
        live="$HOME/$dst"
        if [ ! -e "$live" ]; then
            echo "missing on the machine: $live"
            fail=1
        elif ! cmp -s "$dir/$src" "$live"; then
            echo "differs: $live"
            fail=1
        fi
    done < "$manifest"
done
exit $fail
