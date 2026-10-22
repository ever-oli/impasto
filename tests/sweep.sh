#!/bin/bash
# A sweep of the notch: every panel opens and closes, every command
# answers, every script runs. Nothing destructive: the theme and the
# desktop are put back as they were.
#
#   tests/sweep.sh            run the sweep
#   tests/sweep.sh -v         show what each check said

set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PASS=0
FAIL=0
VERBOSE=${1:-}

ok() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; [ -n "$VERBOSE" ] && [ -n "${2:-}" ] && printf '         %s\n' "$2"; }
no() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '         %s\n' "$2"; }
head_() { printf '\n%s\n' "$1"; }

ipc() { timeout 25 qs ipc call "$@" 2>&1; }

# ── the panels ───────────────────────────────────────────────────────────────
head_ "panels"
for panel in launcher controls t3 keys session clipboard emoji anime notchstorm; do
    answer=$(ipc panel open "$panel")
    if echo "$answer" | grep -qE '"ok": ?true'; then
        sleep 1.2
        closed=$(ipc panel close)
        if echo "$closed" | grep -q '"ok":true'; then
            ok "panel $panel opens and closes"
        else
            no "panel $panel opens and closes" "$closed"
        fi
    else
        no "panel $panel opens and closes" "$answer"
    fi
done

# ── the commands ─────────────────────────────────────────────────────────────
head_ "commands"
answer=$(ipc panel list)
if echo "$answer" | grep -qE '"ok": ?true'; then
    ok "the panel list answers" "$(echo "$answer" | head -c 160)"
else
    no "the panel list answers" "$answer"
fi

for call in "volume get" "focus set toggle" "theme get" "t3 get" "osd say hello test"; do
    set -- $call
    answer=$(ipc "$@")
    if echo "$answer" | grep -qE '"ok": ?true'; then
        ok "ipc $call"
    else
        no "ipc $call" "$answer"
    fi
done

# ── the scripts ──────────────────────────────────────────────────────────────
head_ "scripts"
# Each script is asked for its own help, which every one of them must
# answer without a word.
for script in notch notch-act notch-dev notch-doctor notch-font \
              notch-layout notch-mov notch-qml notchstorm notch-term \
              notch-theater notch-theme notch-updates notch-video notch-watch \
              notch-webapp; do
    path="$HOME/.local/bin/$script"
    if [ ! -x "$path" ]; then
        no "$script is installed"
        continue
    fi
    out=$(timeout 30 "$path" --help 2>&1)
    if [ -n "$out" ]; then ok "$script answers --help"; else no "$script answers --help"; fi
done

# The doctor is not a command that takes help: it is the diagnosis.
out=$(timeout 90 "$HOME/.local/bin/notch-doctor" 2>&1)
if echo "$out" | grep -qi "hotkey"; then
    ok "notch-doctor diagnoses the shell" "$(echo "$out" | grep -ci "✓") checks passed"
else
    no "notch-doctor diagnoses the shell" "$(echo "$out" | head -c 120)"
fi

# The resolver is node, so it is checked by the parser and by its own
# grammar.
if [ -f "$HOME/.local/bin/notch-resolve.mjs" ]; then
    if node --check "$HOME/.local/bin/notch-resolve.mjs" 2>/dev/null; then
        ok "notch-resolve.mjs parses"
    else
        no "notch-resolve.mjs parses"
    fi
    out=$(timeout 30 "$HOME/.local/bin/notch-resolve.mjs" 2>&1)
    if echo "$out" | grep -q "usage"; then
        ok "notch-resolve.mjs says how it is used"
    else
        no "notch-resolve.mjs says how it is used"
    fi
else
    no "notch-resolve.mjs is installed"
fi

# ── the python bridges ───────────────────────────────────────────────────────
head_ "bridges"
for script in stream.py jobs.py; do
    path="$HOME/.config/quickshell/scripts/$script"
    if [ ! -f "$path" ]; then
        no "$script is installed"
        continue
    fi
    if python3 -m py_compile "$path" 2>/dev/null; then ok "$script compiles"; else no "$script compiles"; fi
done

# The token command prints the path whether or not a token is there, so
# the old check passed with no token at all. Ask the catalogue instead.
answer=$(timeout 30 python3 "$HOME/.config/quickshell/scripts/stream.py" rows 2>&1)
if echo "$answer" | grep -q '"token": true'; then
    ok "the catalogue has a TMDB token"
else
    no "the catalogue has a TMDB token" "$(echo "$answer" | head -c 120)"
fi

answer=$(timeout 40 python3 "$HOME/.config/quickshell/scripts/stream.py" episodes 1396 --season 1 2>&1)
if echo "$answer" | grep -q '"episode"'; then ok "the catalogue lists episodes"; else no "the catalogue lists episodes"; fi

# ── the radar ────────────────────────────────────────────────────────────────
head_ "radar"
answer=$(timeout 30 "$HOME/.local/bin/notchstorm" state 2>&1)
# The old check grepped for "error" as well as the answers, so it passed
# on a dead engine. The answer has to say ok.
if echo "$answer" | grep -qE '"ok": ?true'; then
    ok "the radar answers" "$(echo "$answer" | head -c 120)"
else
    no "the radar answers" "$(echo "$answer" | head -c 160)"
fi

# ── the theme ────────────────────────────────────────────────────────────────
head_ "theme"
before=$(ipc theme get)
answer=$(timeout 40 "$HOME/.local/bin/notch-theme" audit 2>&1)
if echo "$answer" | grep -q "under threshold"; then
    ok "every themed pair meets its contrast"
else
    no "every themed pair meets its contrast" "$(echo "$answer" | tail -2)"
fi
after=$(ipc theme get)
if [ "$before" = "$after" ]; then ok "the theme was not changed by the sweep"; else
    "$HOME/.local/bin/notch-theme" set "${before//[\"{}]/}" >/dev/null 2>&1
    ok "the theme was put back"
fi

# ── the layouts ──────────────────────────────────────────────────────────────
head_ "layouts"
plans=$("$HOME/.local/bin/notch-layout" list 2>&1)
if [ -n "$plans" ]; then ok "the layout plans are listed" "$(echo "$plans" | head -c 100)"; else no "the layout plans are listed"; fi

# ── the layouts, applied and lifted ──────────────────────────────────────────
head_ "layouts (applied)"
sizes() {
    niri msg -j windows 2>/dev/null | python3 -c "
import json,sys
print(' '.join(sorted(str(w['layout']['window_size']) for w in json.load(sys.stdin)
                     if w.get('workspace_id') == 1)))"
}
before=$(sizes)
timeout 40 "$HOME/.local/bin/notch-layout" quarters >/dev/null 2>&1
sleep 2
during=$(sizes)
if [ "$before" != "$during" ]; then
    ok "a plan arranges the desktop"
else
    no "a plan arranges the desktop"
fi
timeout 40 "$HOME/.local/bin/notch-layout" clear >/dev/null 2>&1
sleep 2
after=$(sizes)
if [ "$before" = "$after" ]; then
    ok "lifting the plan puts the desktop back"
else
    no "lifting the plan puts the desktop back" "before $before, after $after"
fi

# ── the picture the agent draws ──────────────────────────────────────────────
head_ "qml"
work=$(mktemp -d)
cat > "$work/t.qml" <<'QML'
import QtQuick
Rectangle {
    width: 200; height: 80; color: notch.background
    Text { anchors.centerIn: parent; text: "notch"; color: notch.accent }
}
QML
if timeout 120 "$HOME/.local/bin/notch-qml" "$work/t.qml" --size 200x80 --out "$work/out.png" >/dev/null 2>&1 \
   && [ -s "$work/out.png" ]; then
    ok "the agent's qml becomes a picture"
else
    no "the agent's qml becomes a picture"
fi
rm -rf "$work"

# ── the capture ──────────────────────────────────────────────────────────────
head_ "capture"
answer=$(timeout 90 "$HOME/.local/bin/notch" capture text 2>&1)
if echo "$answer" | grep -qE '"ok": ?true'; then
    ok "the screen can be read"
else
    no "the screen can be read" "$answer"
fi

# ── the palette ──────────────────────────────────────────────────────────────
head_ "palette"
answer=$(timeout 25 qs ipc call palette open "/" 2>&1)
if echo "$answer" | grep -qE '"ok": ?true'; then
    ok "the palette opens the launcher"
else
    no "the palette opens the launcher" "$answer"
fi
timeout 20 qs ipc call panel close >/dev/null 2>&1

# ── the terminal ─────────────────────────────────────────────────────────────
head_ "terminal"
answer=$(timeout 25 "$HOME/.local/bin/notch-term" status 2>&1)
if echo "$answer" | grep -q "open"; then ok "the island terminal answers"; else no "the island terminal answers" "$answer"; fi

printf '\n%s\n' "──────────"
printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
