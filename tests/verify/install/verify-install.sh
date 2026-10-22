#!/bin/bash
# verify-install.sh — the properties the install promises, checked against the
# REAL ./setup script.
#
#   verify-install.sh <repo>
#
# Four properties:
#   P1 convergence  a crash at any point, then a clean run, lands on the same
#                   tree as a clean install
#   P2 honesty      the manifest never names a path that is not there
#   P3 uninstall    ./setup uninstall removes what was installed, exits 0, and
#                   leaves everything else in $HOME alone
#   P4 idempotence  two installs land on the same tree as one
#
# Every HOME here is a throwaway. Nothing touches the real one.
set -u
REPO=$(cd "${1:?repo}" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
fails=0
bad() { printf 'FAIL %s\n' "$*"; fails=$((fails+1)); }
good() { printf 'ok   %s\n' "$*"; }

# install_into <home> [shim-path] — the real script, into <home>.
install_into() {
    local home=$1 shim=${2:-}
    local path=$PATH
    [ -n "$shim" ] && path="$shim:$path"
    HOME="$home" XDG_STATE_HOME="$home/.local/state" \
        XDG_DATA_HOME="$home/.local/share" PATH="$path" \
        sh "$REPO/setup" files >"$home.install.log" 2>&1
    echo $?
}

# tree_of <home> — the installed tree, without the run's log (the backups)
# and the manifest (the state).
tree_of() {
    (cd "$1" && find . -path ./.config-backups -prune -o \
        -path ./.local/state -prune -o -print | sort)
}

# ── the reference: one clean install ─────────────────────────────────────────
mkdir -p "$WORK/ref"
"$HERE/crash-install.sh" "$REPO" 0 "$WORK/refw" >"$WORK/ref.out" 2>&1
REF="$WORK/refw/home"
cp -a "$REF" "$WORK/ref" 2>/dev/null || { mkdir -p "$WORK/ref"; cp -a "$REF" "$WORK/ref/home"; }
REF="$WORK/ref/home"
ops=$(sed -n 's/.*ops=//p' "$WORK/ref.out")
printf 'the installer makes %s filesystem operations in a clean run\n' "$ops"

# ── P4 idempotence: install twice ───────────────────────────────────────────
mkdir -p "$WORK/twice"
cp -a "$REF" "$WORK/twice/home"
rc=$(install_into "$WORK/twice/home")
if [ "$rc" -eq 0 ] && diff <(tree_of "$REF") <(tree_of "$WORK/twice/home") >/dev/null; then
    good "P4 two installs leave the same tree as one"
else
    bad "P4 two installs leave the same tree as one" "rc=$rc $(diff <(tree_of "$REF") <(tree_of "$WORK/twice/home") | head -4 | tr '\n' ' ')"
fi
if diff "$REF/.local/state/notch/files" "$WORK/twice/home/.local/state/notch/files" >/dev/null 2>&1; then
    good "P4 the manifest is the same after two installs"
else
    bad "P4 the manifest is the same after two installs"
fi

# ── P3 uninstall: what it installed, and nothing else ────────────────────────
mkdir -p "$WORK/un"
cp -a "$REF" "$WORK/un/home"
echo "keep me" > "$WORK/un/home/someones-else.txt"
mkdir -p "$WORK/un/home/.config/other" && echo "keep me too" > "$WORK/un/home/.config/other/file"
HOME="$WORK/un/home" XDG_STATE_HOME="$WORK/un/home/.local/state" \
    XDG_DATA_HOME="$WORK/un/home/.local/share" \
    sh "$REPO/setup" uninstall >"$WORK/uninstall.log" 2>&1
urc=$?
if [ "$urc" -eq 0 ]; then
    good "P3 uninstall exits 0"
else
    bad "P3 uninstall exits 0" "rc=$urc: $(tail -1 "$WORK/uninstall.log")"
fi
if [ -e "$WORK/un/home/.config/quickshell" ]; then
    bad "P3 uninstall removes the shell" "~/.config/quickshell is still there"
else
    good "P3 uninstall removes the shell"
fi
if [ -e "$WORK/un/home/.local/bin/notch" ]; then
    bad "P3 uninstall removes the cli" "~/.local/bin/notch is still there"
else
    good "P3 uninstall removes the cli"
fi
if [ -e "$WORK/un/home/someones-else.txt" ] && [ -e "$WORK/un/home/.config/other/file" ]; then
    good "P3 uninstall leaves everything else alone"
else
    bad "P3 uninstall leaves everything else alone"
fi

# ── P1 and P2: crash at every point, then recover ───────────────────────────
crash_fail=0
honesty_fail=0
k=1
while [ "$k" -le "$ops" ]; do
    out=$("$HERE/crash-install.sh" "$REPO" "$k" "$WORK/c" 2>&1)
    lies=$(printf '%s\n' "$out" | sed -n 's/^manifest_lies=//p')
    if [ -n "$lies" ]; then
        honesty_fail=$((honesty_fail+1))
        printf '  P2 crash at op %s: the manifest names %s, which is not there\n' "$k" "$lies"
    fi
    # Recover: a clean run, with no shim in front of the filesystem commands.
    rc=$(install_into "$WORK/c/home")
    if [ "$rc" -ne 0 ] || ! diff <(tree_of "$REF") <(tree_of "$WORK/c/home") >/dev/null; then
        crash_fail=$((crash_fail+1))
        printf '  P1 crash at op %s: the recovered tree differs (rc=%s)\n' "$k" "$rc"
        diff <(tree_of "$REF") <(tree_of "$WORK/c/home") | head -4 | sed 's/^/    /'
    fi
    rm -rf "$WORK/c"
    k=$((k+1))
done
if [ "$crash_fail" -eq 0 ]; then
    good "P1 a crash at any of the $ops points recovers to a clean tree"
else
    bad "P1 a crash at any of the $ops points recovers to a clean tree" "$crash_fail of $ops did not"
fi
if [ "$honesty_fail" -eq 0 ]; then
    good "P2 the manifest never names a path that is not there"
else
    bad "P2 the manifest never names a path that is not there" "$honesty_fail of $ops did not"
fi

printf '\n%s property checks failed\n' "$fails"
[ "$fails" -eq 0 ]
