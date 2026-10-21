#!/bin/sh
# setup.sh — the install, checked into a throwaway home.
#
# `./setup files` copies the packages into $HOME. A directory that lands
# inside an existing directory is silent, and the shell then refuses to
# start, so the install gets checked here: into a home of its own.
#
#   sh tests/setup.sh
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

HOME="$work" XDG_STATE_HOME="$work/.local/state" XDG_DATA_HOME="$work/.local/share" \
    sh "$root/setup" files >"$work/setup.log" 2>&1
if [ $? -eq 0 ]; then
    ok "the install runs"
else
    no "the install runs" "$(tail -3 "$work/setup.log")"
fi

# The shell's own directory, and not a copy of it inside itself.
if [ -f "$work/.config/quickshell/shell.qml" ]; then
    ok "the shell lands at ~/.config/quickshell"
else
    no "the shell lands at ~/.config/quickshell" "$(ls "$work/.config/quickshell" 2>&1 | head -3)"
fi
if [ -d "$work/.config/quickshell/quickshell" ]; then
    no "the shell is not copied inside itself"
else
    ok "the shell is not copied inside itself"
fi

# The singletons the shell needs, and the ones it must not have.
if [ -f "$work/.config/quickshell/qmldir" ] && grep -q "AnimeService" "$work/.config/quickshell/qmldir"; then
    ok "the qmldir lists the services"
else
    no "the qmldir lists the services"
fi
if grep -q "AskService" "$work/.config/quickshell/qmldir" 2>/dev/null; then
    no "no assistant is left in the shell"
else
    ok "no assistant is left in the shell"
fi

# The scripts the shell runs.
for script in stream.py jobs.py t3.py; do
    if [ -f "$work/.config/quickshell/scripts/$script" ]; then
        ok "$script is installed"
    else
        no "$script is installed"
    fi
done
for script in ask.py ask_extras.py ask_lessons.py ask_pi.py ask_box.py; do
    if [ -f "$work/.config/quickshell/scripts/$script" ]; then
        no "$script is not installed"
    else
        ok "$script is not installed"
    fi
done

# The user's own files, and the cli.
for file in .config/notch/profile.md .config/notch/snippets.toml; do
    if [ -f "$work/$file" ]; then
        ok "$file is installed"
    else
        no "$file is installed"
    fi
done
for bin in notch notch-act notch-theme notch-doctor; do
    if [ -x "$work/.local/bin/$bin" ]; then
        ok "$bin is installed"
    else
        no "$bin is installed"
    fi
done

printf '\n──────────\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
