#!/bin/bash
# notch-drive.sh — drive the live notch the way Ever does, and keep the proof.
#
#   notch-drive.sh <scenario> [evidence-dir]
#
# Scenarios:
#   doctor    is the shell up, is every module loaded, is the palette alive
#   panels    every panel opens and closes, and the shell is still answering
#   palette   the palette searches, answers rows, and takes an action
#   context   the handoff carries the brief, and puts it on the clipboard
#   theme     the theme changes, reaches the terminals, and is put back
#
# Everything here goes through the real surface: the `notch` cli, or
# `qs ipc call` the way the binds do. Nothing reaches into the shell's
# files. Every answer is written to the evidence directory, which survives
# the cleanup.
set -u
SCENARIO=${1:?scenario}
EVIDENCE=${2:-"$(dirname "$0")/evidence/$(date +%Y%m%d-%H%M%S)"}
mkdir -p "$EVIDENCE"

pass=0
fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; printf '%s\n' "$1" >> "$EVIDENCE/verdict.txt"; }
no()  { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; printf 'FAIL %s\n' "$1" >> "$EVIDENCE/verdict.txt"; [ -n "${2:-}" ] && printf '       %s\n' "$2" | tee -a "$EVIDENCE/verdict.txt"; }

# The raw answer, kept.
ipc() { local out; out=$(timeout 25 qs ipc call "$@" 2>&1); printf '%s' "$out" > "$EVIDENCE/$(echo "$*" | tr ' /' '__').json"; printf '%s' "$out"; }
# The same, through the cli a key bind runs.
cli() { local out; out=$(timeout 25 "$HOME/.local/bin/notch" "$@" 2>&1); printf '%s' "$out" > "$EVIDENCE/notch_$(echo "$*" | tr ' /' '__').json"; printf '%s' "$out"; }
# The value at a dotted path, as json: a string comes out bare, a
# boolean as true, a list as a list.
field() { printf '%s' "$1" | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    print(''); raise SystemExit
for k in '$2'.split('.'):
    if isinstance(d, dict):
        d = d.get(k, '')
    else:
        d = ''; break
if isinstance(d, str):
    print(d)
else:
    print(json.dumps(d))
" 2>/dev/null; }

case $SCENARIO in

doctor)
    if pgrep -u "$(id -u)" -x qs >/dev/null || pgrep -u "$(id -u)" -x quickshell >/dev/null; then
        ok "the shell is running"
    else
        no "the shell is running" "no qs process"
    fi
    answer=$(ipc panel list)
    if [ "$(field "$answer" ok)" = "true" ] && [ -n "$(field "$answer" panels)" ]; then
        ok "the shell answers panel list with the panels"
    else
        no "the shell answers panel list with the panels" "$answer"
    fi
    answer=$(ipc modules failed)
    if [ "$(field "$answer" failed)" = "{}" ]; then
        ok "every bar module loaded"
    else
        no "every bar module loaded" "$answer"
    fi
    answer=$(cli doctor)
    if printf '%s' "$answer" | grep -q "Hotkeys"; then
        ok "notch doctor runs"
    else
        no "notch doctor runs" "$answer"
    fi
    # Is this the shell Ever runs, or a stale one that answers the ipc?
    # The shell's own files, not the ones other packages put beside
    # them: the media scripts live in the same directory.
    repo="${NOTCH_REPO:-$HOME/src/notch}"
    stale=""
    for f in "$repo"/packages/shell/quickshell/*.qml "$repo"/packages/shell/quickshell/qmldir; do
        [ -f "$f" ] || continue
        live="$HOME/.config/quickshell/$(basename "$f")"
        if [ ! -f "$live" ]; then
            stale="$stale $(basename "$f")"
        elif ! cmp -s "$f" "$live"; then
            stale="$stale $(basename "$f")"
        fi
    done
    if [ -z "$stale" ]; then
        ok "the shell on this machine is the one in the repository"
    else
        no "the shell on this machine is the one in the repository" \
           "stale:$stale; run ./setup files"
    fi
    ;;

panels)
    for panel in launcher controls t3 keys session clipboard emoji anime notchstorm; do
        opened=$(ipc panel open "$panel")
        if [ "$(field "$opened" ok)" != "true" ]; then
            no "panel $panel opens" "$opened"; continue
        fi
        sleep 0.8
        closed=$(ipc panel close)
        if [ "$(field "$closed" ok)" = "true" ]; then
            ok "panel $panel opens and closes"
        else
            no "panel $panel opens and closes" "$closed"
        fi
    done
    # The shell must still be alive after all of that.
    answer=$(ipc panel list)
    if [ "$(field "$answer" ok)" = "true" ]; then
        ok "the shell is still answering after the panel cycle"
    else
        no "the shell is still answering after the panel cycle" "$answer"
    fi
    ;;

palette)
    opened=$(ipc palette open "/")
    if [ "$(field "$opened" ok)" != "true" ]; then no "the palette opens" "$opened"; fi
    search=$(ipc palette search theme)
    sleep 0.6
    rows=$(ipc palette rows)
    printf '%s\n' "$rows" > "$EVIDENCE/palette-rows.txt"
    if printf '%s' "$rows" | grep -q "Style"; then
        ok "the palette searches and answers rows"
    else
        no "the palette searches and answers rows" "$rows"
    fi
    # A web row proves the fallback path: a query nothing matches must
    # still give the caller something to press.
    ipc palette search zzqqxy >/dev/null
    sleep 0.6
    rows=$(ipc palette rows)
    if printf '%s' "$rows" | grep -q "web:"; then
        ok "a query nothing matches falls back to the web"
    else
        no "a query nothing matches falls back to the web" "$rows"
    fi
    ipc panel close >/dev/null
    ;;

context)
    answer=$(ipc context get)
    if [ "$(field "$answer" ok)" = "true" ] && [ -n "$(field "$answer" hero.title)" ]; then
        ok "context get answers with the hero"
    else
        no "context get answers with the hero" "$answer"
    fi
    if printf '%s' "$answer" | grep -q '"work"'; then
        ok "context get carries the work"
    else
        no "context get carries the work" "$answer"
    fi
    before=$(wl-paste --no-newline 2>/dev/null | head -c 200)
    handed=$(ipc context hand)
    sleep 1
    after=$(wl-paste --no-newline 2>/dev/null | head -c 400)
    # The brief is the notch's own words: its marker, and the hero it names.
    if printf '%s' "$after" | grep -q "notch-context" && \
       printf '%s' "$after" | grep -q "\"hero\""; then
        ok "context hand puts a brief on the clipboard"
        printf '%s\n' "$after" > "$EVIDENCE/handoff-clipboard.txt"
    else
        no "context hand puts a brief on the clipboard" "clipboard: ${after:0:120}"
    fi
    ;;

theme)
    before=$(field "$(ipc theme get)" theme)
    ghostty_before=$(md5sum "$HOME/.config/ghostty/notch-theme" 2>/dev/null | cut -d' ' -f1)
    # The way Ever changes the theme: the cli, which renders the terminals too.
    changed=$("$HOME/.local/bin/notch-theme" set e-ink 2>&1)
    sleep 1
    now=$(field "$(ipc theme get)" theme)
    if [ "$now" = "e-ink" ]; then
        ok "the theme changes and says so"
    else
        no "the theme changes and says so" "$changed"
    fi
    # The side effect: the shell's own state, and the terminal's file.
    if [ "$(python3 -c "import json;print(json.load(open('$HOME/.local/state/notch/theme.json'))['id'])" 2>/dev/null)" = "e-ink" ]; then
        ok "the shell's state file carries the new theme"
    else
        no "the shell's state file carries the new theme" "$HOME/.local/state/notch/theme.json"
    fi
    ghostty_after=$(md5sum "$HOME/.config/ghostty/notch-theme" 2>/dev/null | cut -d' ' -f1)
    if [ -n "$ghostty_after" ] && [ "$ghostty_after" != "$ghostty_before" ]; then
        ok "the terminal followed the theme"
    else
        no "the terminal followed the theme" "the ghostty theme file did not change"
    fi
    # Put it back, and prove it.
    "$HOME/.local/bin/notch-theme" set "$before" >/dev/null 2>&1
    sleep 1
    back=$(field "$(ipc theme get)" theme)
    if [ "$back" = "$before" ]; then
        ok "the theme is put back"
    else
        no "the theme is put back" "was $before, now $back"
    fi
    ;;

work)
    # The work is not the catalogue's: it loads with the shell, so this
    # scenario must not open a panel first.
    answer=$(ipc work get)
    if [ "$(field "$answer" ok)" = "true" ]; then
        ok "work get answers without the catalogue panel being open"
    else
        no "work get answers without the catalogue panel being open" "$answer"
    fi
    answer=$(ipc work platforms)
    if [ "$(field "$answer" ok)" = "true" ] && [ -n "$(field "$answer" note)" ]; then
        ok "the platforms carry the geo note: the rule that decides who can sign up"
    else
        no "the platforms carry the geo note: the rule that decides who can sign up" "$answer"
    fi
    answer=$(ipc work platform Outlier)
    if [ "$(field "$answer" name)" = "Outlier" ] && [ -n "$(field "$answer" requirements)" ]; then
        ok "a platform answers with its requirements"
    else
        no "a platform answers with its requirements" "$answer"
    fi
    # work platform takes a name; work hand takes an index. Easy to swap.
    answer=$(ipc work hand platform 0)
    if [ "$(field "$answer" handing)" = "true" ]; then
        ok "a platform can be handed over by index"
    else
        no "a platform can be handed over by index" "$answer"
    fi
    ;;

*)
    printf 'unknown scenario: %s\n' "$SCENARIO"; exit 2 ;;
esac

printf '\n%s passed, %s failed (evidence in %s)\n' "$pass" "$fail" "$EVIDENCE"
[ "$fail" -eq 0 ]
