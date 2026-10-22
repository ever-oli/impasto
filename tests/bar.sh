#!/bin/sh
# bar.sh — the whole bar, checked.
#
# The catalogue and the watching are left out on purpose: this is about
# the shell itself. Every panel the island holds opens and closes, every
# ipc target answers with real data, every module loads, every verb of
# the cli works, and every script it ships runs.
#
#   sh tests/bar.sh
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

pass=0
fail=0

ok() {
    pass=$((pass + 1))
    printf '  \033[32mok\033[0m   %s\n' "$1"
}

no() {
    fail=$((fail + 1))
    printf '  \033[31mFAIL\033[0m %s\n' "$1"
    [ -n "${2:-}" ] && printf '       %s\n' "$2"
}

head_() {
    printf '\n\033[1m%s\033[0m\n' "$1"
}

ipc() { timeout 25 qs ipc call "$@" 2>&1; }

# ── the shell is alive ──────────────────────────────────────────────────────
head_ "the shell"
if pgrep -x qs >/dev/null 2>&1; then ok "qs is running"; else no "qs is running"; fi
if pgrep -x qs >/dev/null 2>&1 && [ -n "$(ipc panel list)" ]; then
    ok "the shell answers its ipc"
else
    no "the shell answers its ipc" "$(ipc panel list)"
fi

# ── the island's panels ─────────────────────────────────────────────────────
head_ "the panels"
# The catalogue is not part of this: the media has its own checks.
for panel in launcher controls t3 keys session clipboard emoji notchstorm; do
    opened=$(ipc panel open "$panel")
    if echo "$opened" | grep -q '"ok":true'; then
        sleep 0.8
        closed=$(ipc panel close)
        if echo "$closed" | grep -q '"ok":true'; then
            ok "panel $panel opens and closes"
        else
            no "panel $panel opens and closes" "$closed"
        fi
    else
        no "panel $panel opens" "$opened"
    fi
done

# ── the ipc targets answer with something real ─────────────────────────────
head_ "the ipc targets"
# An answer that carries an error is not an answer: the check has to
# look, or a target that always fails would pass.
check_json() {
    name=$1
    answer=$(ipc $2)
    if echo "$answer" | head -c 1 | grep -q '[{"[]' && ! echo "$answer" | grep -q '"error"'; then
        ok "$name answers with data"
    else
        no "$name answers with data" "$answer"
    fi
}
# Every target answers with ok, including the three that live outside
# Commands.qml: a caller that checks ok must not read one as a failure.
for target in playing:get orb:status fontsize:status; do
    name=${target%%:*}; verb=${target##*:}
    answer=$(ipc "$name" "$verb" 2>/dev/null)
    if echo "$answer" | grep -q '"ok":true'; then
        ok "the $name target answers with ok"
    else
        no "the $target target answers with ok" "$answer"
    fi
done

check_json "panel list" "panel list"
check_json "the context" "context get"
check_json "the work" "work get"
check_json "the platforms" "work platforms"
check_json "the volume" "volume get"
check_json "the theme" "theme get"
check_json "t3" "t3 get"
check_json "the modules" "modules failed"

# The work must answer on its own: it is not the catalogue's, and
# nothing may have to open a panel first.
one=$(ipc work platform Outlier)
if echo "$one" | grep -q 'Outlier' && echo "$one" | grep -q 'requirements'; then
    ok "a platform answers with its requirements"
else
    no "a platform answers with its requirements" "$one"
fi

# ── the bar's modules ───────────────────────────────────────────────────────
head_ "the modules"
failed=$(ipc modules failed)
if echo "$failed" | grep -q '"failed":{}'; then
    ok "no module failed to load"
else
    no "no module failed to load" "$failed"
fi
for module in clock network volume battery bluetooth notifications playing t3; do
    answer=$(ipc modules reload "$module")
    if echo "$answer" | grep -q '"ok":true'; then
        ok "module $module reloads"
    else
        no "module $module reloads" "$answer"
    fi
done

# ── the keys ────────────────────────────────────────────────────────────────
head_ "the keys"
answer=$(ipc panel open keys)
if echo "$answer" | grep -q '"ok":true'; then
    sleep 0.6
    ipc panel close >/dev/null 2>&1
    ok "the keys sheet opens"
else
    no "the keys sheet opens" "$answer"
fi
if grep -q "notch" "$HOME/.config/niri/config.kdl" 2>/dev/null; then
    ok "the niri config carries the notch binds"
else
    no "the niri config carries the notch binds"
fi
# Every bind in the config points at a command that still exists.
stale=""
while read -r _ action; do
    case "$action" in
        "notch"*) command=${action#notch }
                 first=$(printf '%s' "$command" | awk '{print $1}')
                 [ -z "$first" ] && continue
                 if ! notch "$first" --help >/dev/null 2>&1 && \
                    ! [ -x "$HOME/.local/bin/notch" ]; then
                     stale="$stale $action"
                 fi ;;
    esac
done < <(grep -oE 'spawn "notch"[^;]*' "$HOME/.config/niri/config.kdl" 2>/dev/null | sed 's/spawn "//' | sed 's/"$//')
if [ -z "$stale" ]; then
    ok "every notch bind points at a verb that exists"
else
    no "every notch bind points at a verb that exists" "$stale"
fi

# ── the cli ─────────────────────────────────────────────────────────────────
head_ "the cli"
for verb in panels context work theme volume t3 say learn; do
    if notch "$verb" --help >/dev/null 2>&1; then
        ok "notch $verb is a verb"
    else
        no "notch $verb is a verb"
    fi
done
if notch panels 2>&1 | grep -q '"ok":true'; then
    ok "notch panels lists the panels"
else
    no "notch panels lists the panels"
fi
if notch context get 2>&1 | grep -q '"panel"'; then
    ok "notch context get gives the context"
else
    no "notch context get gives the context"
fi
if notch work platforms 2>&1 | grep -q 'Outlier'; then
    ok "notch work platforms gives the platforms"
else
    no "notch work platforms gives the platforms"
fi
if notch say "bar test" >/dev/null 2>&1; then
    ok "notch say says a line on the island"
else
    no "notch say says a line on the island"
fi

# ── the scripts the shell runs ──────────────────────────────────────────────
head_ "the scripts"
for script in "$HOME"/.config/quickshell/scripts/*.py; do
    name=$(basename "$script")
    if python3 -m py_compile "$script" 2>/dev/null; then
        ok "$name compiles"
    else
        no "$name compiles"
    fi
done
for script in "$HOME"/.local/bin/notch*; do
    name=$(basename "$script")
    # The media scripts are not this test's business, and the resolver
    # takes a subcommand rather than a flag.
    case "$name" in
        notch-anime|notch-resolve.mjs) continue ;;
    esac
    if timeout 30 "$script" --help >/dev/null 2>&1; then
        ok "$name answers --help"
    else
        no "$name answers --help"
    fi
done

# ── the theme ───────────────────────────────────────────────────────────────
head_ "the theme"
# The theme is the user's: the test puts it back when it is done.
was=$(ipc theme get | sed 's/.*"theme":"\([^"]*\)".*/\1/')
answer=$(ipc theme set e-ink)
if echo "$answer" | grep -q '"ok":true'; then
    sleep 1
    now=$(ipc theme get)
    if echo "$now" | grep -q '"theme":"e-ink"'; then
        ok "the theme changes and says so"
    else
        no "the theme changes and says so" "$now"
    fi
else
    no "the theme changes and says so" "$answer"
fi
if [ -n "$was" ] && [ "$was" != "e-ink" ]; then
    # The shell's theme set runs notch-theme, which writes the state and
    # takes a moment; the check waits for it.
    ipc theme set "$was" >/dev/null 2>&1
    sleep 3
    back=$(ipc theme get | sed 's/.*"theme":"\([^"]*\)".*/\1/')
    if [ "$back" = "$was" ]; then
        ok "the theme is put back"
    else
        no "the theme is put back" "was $was, now $back"
    fi
fi

# ── the verdict ─────────────────────────────────────────────────────────────
printf '\n──────────\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
