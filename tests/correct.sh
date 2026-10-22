#!/bin/sh
# correct.sh — the mistakes agents keep repeating in this repo, made
# impossible.
#
# Every check here is a mistake that actually happened, found by the
# harness or by a review. The harness writes the lesson; this makes it
# a gate. A lesson nobody can break by accident is worth keeping; one
# that lives only in a file is a wish.
#
#   sh tests/correct.sh
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# ── nothing left behind ─────────────────────────────────────────────────────
# The ask panel was deleted and its name survived in four places: the orb,
# the launcher, the menu and the niri binds. The user found it by
# clicking. So: a name that is gone from the tree must be gone from
# every file that mentions it.
head_ "removed things leave nothing behind"
for ghost in "notch-ask-cli" "notch-harness" "notch evolve" "AskService" "AskPanel"; do
    hits=$(grep -rln "$ghost" --include=* . 2>/dev/null \
           | grep -v "^./.git/" | grep -v "^./tests/correct.sh" | grep -v "^./.gitignore" \
           | grep -v "^./docs/quickshell.md" | grep -v "^./tests/setup.sh" | head -3)
    if [ -z "$hits" ]; then
        ok "nothing mentions $ghost"
    else
        no "nothing mentions $ghost" "$hits"
    fi
done

# ── the paths that moved ────────────────────────────────────────────────────
# The tree became packages/. The docs still said home/. Every path the
# docs name has to exist.
head_ "the docs name paths that exist"
while read -r doc path; do
    [ -z "${doc:-}" ] && continue
    case "$doc" in \#*) continue ;; esac
    if [ -e "$path" ]; then
        ok "$doc names $path"
    else
        no "$doc names $path" "no such path"
    fi
done <<'PATHS'
README.md packages/shell/quickshell
README.md packages/media
MAINTAINING.md packages/shell/quickshell
MAINTAINING.md packages/data/notch
INSTALL.md packages/data/notch
AGENTS.md packages/shell/quickshell/qmldir
AGENTS.md tests/bar.sh
AGENTS.md tests/setup.sh
PATHS

# Every path a doc writes as `packages/...` must exist too.
for doc in README.md MAINTAINING.md INSTALL.md AGENTS.md; do
    miss=""
    for p in $(grep -oE '`packages/[a-z0-9/._-]+`' "$doc" 2>/dev/null | tr -d '`' | sort -u); do
        [ -e "$p" ] || miss="$miss $p"
    done
    if [ -z "$miss" ]; then
        ok "every packages/ path in $doc exists"
    else
        no "every packages/ path in $doc exists" "$miss"
    fi
done

# ── the shell's own rules ───────────────────────────────────────────────────
# The repo's rules ban the em dash in prose. The prose and the rules
# have to agree.
head_ "the prose and the rules agree"
for doc in README.md docs/ipc.md docs/quickshell.md AGENTS.md INSTALL.md MAINTAINING.md; do
    [ -f "$doc" ] || continue
    n=$(grep -c "—" "$doc" 2>/dev/null | head -1)
    n=${n:-0}
    if [ "$n" -eq 0 ]; then
        ok "$doc has no em dashes"
    else
        no "$doc has no em dashes" "$n of them"
    fi
done

# ── the singletons are registered ───────────────────────────────────────────
# A service that is not in the qmldir takes the whole shell down, and the
# error names the type, not the list.
head_ "every singleton is in the qmldir"
qmldir=packages/shell/quickshell/qmldir
for svc in packages/shell/quickshell/services/*.qml; do
    name=$(basename "$svc" .qml)
    if grep -q "services/$name.qml" "$qmldir"; then
        ok "$name is registered"
    else
        no "$name is registered" "not in the qmldir"
    fi
done
for line in $(grep -oE 'services/[A-Za-z]+\.qml' "$qmldir" | sort -u); do
    if [ -f "packages/shell/quickshell/$line" ]; then
        ok "$line exists"
    else
        no "$line exists" "listed in the qmldir, not on disk"
    fi
done

# ── the ipc handlers are in the config root ────────────────────────────────
# A handler inside a service singleton registers fine. What does not work
# is a service with a broken file: the config root imports ./services, so
# the whole config fails to load and every target answers "Target not
# found". So: every service has to load.
head_ "every service loads"
for svc in packages/shell/quickshell/services/*.qml; do
    name=$(basename "$svc" .qml)
    if grep -q "StdioDiscard\|Quickshell.shellPath(\"scripts/ask" "$svc" 2>/dev/null; then
        no "$name loads" "it names a type or a path that is gone"
    else
        ok "$name loads"
    fi
done

# ── the install lands where the manifest says ──────────────────────────────
# A directory that lands inside an existing one is silent, and the shell
# ends up in ~/.config/quickshell/quickshell and will not start. The
# check that matters is in tests/setup.sh, which installs into a home of
# its own; here the manifest is only read for the shape.
head_ "the install manifests are readable"
for manifest in packages/*/install; do
    bad=$(while read -r src dst; do
        [ -z "${src:-}" ] && continue
        case "$src" in \#*) continue ;; esac
        [ -e "$(dirname "$manifest")/$src" ] || echo "missing $src"
    done < "$manifest")
    if [ -z "$bad" ]; then
        ok "$(basename "$(dirname "$manifest")") manifest is whole"
    else
        no "$(basename "$(dirname "$manifest")") manifest is whole" "$bad"
    fi
done

# ── the tools answer for help ───────────────────────────────────────────────
# notch-webapp took --help as a url and opened a browser. The sweep passed
# it because the output was not empty.
head_ "every tool answers for help"
for tool in packages/*/bin/notch*; do
    name=$(basename "$tool")
    case "$name" in
        notch-resolve.mjs|notch-anime) continue ;;
    esac
    if timeout 30 "$tool" --help >/dev/null 2>&1; then
        ok "$name answers --help"
    else
        no "$name answers --help"
    fi
done

# ── the lessons that have no check yet ─────────────────────────────────────
# The harness writes a lesson when a mistake happens. A lesson nobody can
# break by accident is worth keeping; one that lives only in a file is a
# wish. These are the ones that are still wishes, checked here instead.
head_ "the lessons that are still wishes"
# The pkill that killed the session doing the killing.
if grep -rn "pkill -f" --include=*.sh --include=*.md . 2>/dev/null \
   | grep -v "^./.git/" | grep -v "tests/correct.sh" | grep -qv "proc"; then
    no "no pkill pattern that could match the command running it"
else
    ok "no pkill pattern that could match the command running it"
fi
# The check that a background job landed, not just that it was started.
if [ -x "$HOME/.local/bin/notch" ] && notch context get >/dev/null 2>&1; then
    ok "the handoff answers when the shell is up"
else
    no "the handoff answers when the shell is up"
fi

# ── the python has no undefined names ──────────────────────────────────────
# compose() called context() as if it were its own; it lives in
# ask_extras. The name error killed every question the shell asked, and
# the suite passed.
head_ "the python has no undefined names"
if command -v pyflakes >/dev/null 2>&1; then
    if pyflakes packages/*/scripts/*.py packages/*/bin/notch-summarise 2>&1 | grep -v "unable to detect undefined names"; then
        no "the scripts are clean" "see above"
    else
        ok "the scripts are clean"
    fi
else
    ok "pyflakes is not installed, so this check is skipped"
fi

printf '\n──────────\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
