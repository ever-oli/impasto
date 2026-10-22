#!/bin/sh
# regressions.sh — the bugs that were found, kept from coming back.
#
# Each check here is a bug that actually happened, and each one has a
# cheap local target: no live shell, no network, no engine. A bug that
# only shows on a machine with a compositor running belongs in
# tests/verify, not here.
#
#   sh tests/regressions.sh
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The scripts import their siblings, and python3 can be a mise shim that
# refuses to run in some directories, so the interpreter is absolute and
# the source tree is named.
export NOTCH_SRC="$root"

# ── the watch history shape ─────────────────────────────────────────────────
# The writer wrote a bare array and the shell read {"items": [...]}, so
# the "continue watching" shelf was always empty and nothing said so.
head_ "the watch history"
answer=$(/usr/bin/python3 - "$work" <<'PY' 2>&1
import importlib.machinery, importlib.util, json, os, sys
work = sys.argv[1]
spec = importlib.util.spec_from_file_location(
    "subs", os.path.join(os.environ["NOTCH_SRC"], "packages/media/bin/notch-subs"),
    loader=importlib.machinery.SourceFileLoader(
        "subs", os.path.join(os.environ["NOTCH_SRC"], "packages/media/bin/notch-subs")))
subs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(subs)
path = os.path.join(work, "watching.json")
subs.write_state(path, [{"title": "Cowboy Bebop", "kind": "film"}])
print(json.dumps(json.load(open(path))))
PY
)
if echo "$answer" | grep -q '"items"'; then
    ok "the watch history is written as an object with items"
else
    no "the watch history is written as an object with items" "$answer"
fi

# ── a title with an apostrophe ──────────────────────────────────────────────
# The player command went to tmux through a shell with the title
# interpolated, so "Ocean's Eleven" ended the quoting and the film never
# started. Two titles in the live shelf have apostrophes in them.
head_ "a title with an apostrophe"
answer=$(/usr/bin/python3 - <<'PY' 2>&1
import importlib.machinery, importlib.util, os, shlex
path = os.path.join(os.environ["NOTCH_SRC"], "packages/media/bin/notch-watch")
spec = importlib.util.spec_from_file_location(
    "watch", path, loader=importlib.machinery.SourceFileLoader("watch", path))
watch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watch)
# The command the terminal runs, for a title with an apostrophe in it.
command = watch.player_command("https://example/x", "Ocean's Eleven")
words = shlex.split(command)
if "Ocean's Eleven" in words and "--title" in words:
    print("ok")
else:
    print("got: " + command)
PY
)
if [ "$answer" = "ok" ]; then
    ok "the player command keeps a title with an apostrophe"
else
    no "the player command keeps a title with an apostrophe" "$answer"
fi

# The quoting itself: the shell has to be able to read the title back.
answer=$(/usr/bin/python3 - <<'PY' 2>&1
import shlex
def quoted(value):
    return "'" + str(value).replace("'", "'\\''") + "'"
title = "Ocean's Eleven"
command = "notch-video " + quoted(title)
# The shell must read back exactly the title.
import subprocess
out = subprocess.run(["sh", "-c", "printf %s " + command.split(" ", 1)[1]],
                     capture_output=True, text=True)
print("ok" if out.stdout == title else "got: " + repr(out.stdout))
PY
)
if [ "$answer" = "ok" ]; then
    ok "a title with an apostrophe survives the shell"
else
    no "a title with an apostrophe survives the shell" "$answer"
fi

# ── the setup's own path ────────────────────────────────────────────────────
# "setup packages" read a path the refactor deleted, so a fresh machine
# installed no dependencies and said they were all present.
head_ "the install"
deps=$(grep -oE 'packages/[a-z]+/notch/deps\.tsv' setup | head -1)
if [ -n "$deps" ] && [ -f "$deps" ]; then
    ok "setup reads a dependency table that exists"
else
    no "setup reads a dependency table that exists" "$deps"
fi

# ── the notch's skill carries the rules the agents read ──────────────────────
head_ "the agent's rules"
skill="$HOME/.config/opencode/skill/notch/SKILL.md"
rules="$HOME/.config/opencode/skill/notch/modes/_rules.md"
if [ -f "$skill" ] && [ -f "$rules" ]; then
    ok "the skill and the ground rules are where the agents look"
else
    no "the skill and the ground rules are where the agents look"
fi
if grep -q "notch context get" "$skill" 2>/dev/null; then
    ok "the skill names the notch's verbs"
else
    no "the skill names the notch's verbs"
fi

printf '\n──────────\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
