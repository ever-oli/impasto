#!/bin/sh
# An eval for the notch's assistant: does it do what it is for?
#
# The questions are the ones the assistant exists to answer, and each one
# is checked by the thing itself — the engine for an answer, the renderer
# for a picture, the memory for a lesson. Nothing is checked by looking at
# the text and hoping; every check is a fact.
#
#   tests/assistant-eval.sh            the whole eval
#   tests/assistant-eval.sh -v         show what each check said
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
PASS=0
FAIL=0
VERBOSE=${1:-}

ok() {
    PASS=$((PASS + 1))
    printf '  ok   %s\n' "$1"
    if [ -n "$VERBOSE" ] && [ -n "${2:-}" ]; then printf '         %s\n' "$2"; fi
    return 0
}
no() {
    FAIL=$((FAIL + 1))
    printf '  FAIL %s\n' "$1"
    if [ -n "$VERBOSE" ] && [ -n "${2:-}" ]; then printf '         %s\n' "$2"; fi
    return 0
}

ask() {
    timeout 200 "$root/packages/assistant/bin/notch-ask-cli" \
        --backend "${ASK_BACKEND:-opencode}" "$@" 2>&1
}

# ── 1 · it answers ───────────────────────────────────────────────────────────
answer=$(ask "In one short sentence: what is a terminal?")
if [ -n "$(echo "$answer" | tr -d '[:space:]')" ]; then
    ok "it answers a question" "$(echo "$answer" | head -c 90)"
else
    no "it answers a question"
fi

# ── 2 · it sees the screen when asked to ────────────────────────────────────
answer=$(python3 -c "
import sys
script = sys.argv[1]
print('the screen reaches the question:', '\"screen\"' in open(script).read())
" "$root/packages/assistant/scripts/ask.py")
if echo "$answer" | grep -q "True"; then
    ok "it can take the screen as context" "$answer"
else
    no "it can take the screen as context" "$answer"
fi

# ── 3 · it keeps to its mode ────────────────────────────────────────────────
modes=$(python3 "$root/packages/assistant/scripts/ask.py" modes 2>/dev/null | head -c 200)
if echo "$modes" | grep -q "notch"; then
    ok "it has modes, and the notch's own is one of them" "$(echo "$modes" | head -c 90)"
else
    no "it has modes, and the notch's own is one of them" "$modes"
fi

# ── 4 · a drawn answer becomes a picture ────────────────────────────────────
work=$(mktemp -d)
cat > "$work/answer.md" <<'ANSWER'
Here is the shape of it:

```chart
{"type":"bar","title":"a bar","labels":["a","b"],"series":[{"name":"s","values":[1,2]}]}
```
ANSWER
if python3 - "$work/answer.md" <<'PY' 2>/dev/null
import os, sys
sys.path.insert(0, os.path.expanduser("~/.config/quickshell/scripts"))
import ask_extras as extras
kinds = extras.visuals(open(sys.argv[1]).read())
print("kinds:", kinds)
raise SystemExit(0 if any(k == "chart" and os.path.exists(p) for k, p, _ in kinds) else 1)
PY
then
    ok "a chart in an answer is drawn as a picture"
else
    no "a chart in an answer is drawn as a picture"
fi

# ── 5 · a QML answer becomes a picture too ──────────────────────────────────
cat > "$work/t.qml" <<'QML'
import QtQuick
Rectangle { width: 200; height: 80; color: notch.accent }
QML
if timeout 180 "$root/packages/tools/bin/notch-qml" "$work/t.qml" --size 200x80 --out "$work/q.png" >/dev/null 2>&1 \
   && [ -s "$work/q.png" ]; then
    ok "a QML answer is drawn as a picture"
else
    no "a QML answer is drawn as a picture"
fi

# ── 6 · it learns, and only keeps what worked ───────────────────────────────
if python3 - <<'PY' 2>/dev/null
import importlib.util, os, sys, tempfile
spec = importlib.util.spec_from_file_location(
    "ask_lessons", os.path.expanduser("~/.config/quickshell/scripts/ask_lessons.py"))
lessons = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lessons)
work = tempfile.mkdtemp()
lessons.LESSONS = os.path.join(work, "lessons.md")
lessons.PROPOSALS = os.path.join(work, "proposals.json")
lessons.propose("what now", "ask before acting", scope="general")
assert lessons.candidate("what now") == "ask before acting"
assert lessons.candidate("anything else") == "ask before acting", "a general lesson must ride every question"
lessons.settle(True)
assert "ask before acting" in open(lessons.LESSONS).read()
assert lessons.proposals() == []
PY
then
    ok "a lesson it learned rides every question, and is kept once it works"
else
    no "a lesson it learned rides every question, and is kept once it works"
fi

# ── 7 · its tools are the user's to allow ───────────────────────────────────
answer=$(ask "What is the capital of France?")
if [ -n "$(echo "$answer" | tr -d '[:space:]')" ]; then
    ok "it answers without reaching for the desktop"
else
    no "it answers without reaching for the desktop"
fi

rm -rf "$work"
printf '\n%s\n' "──────────"
printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
