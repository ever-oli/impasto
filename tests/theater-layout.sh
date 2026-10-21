#!/bin/bash
# notch-theater stages an 82x26 tmux window: marquee on row 1, the stream in a
# heavy-bordered popup whose inside is exactly 80x23. Headless: no window opens.
set -u
export LANG=C.UTF-8
BIN=$(dirname "$0")/../packages/tools/bin/notch-theater
S=notch-theater-test-$$ P=notch-theater-proof-$$
trap 'tmux -L $S kill-server 2>/dev/null; tmux -L $P kill-server 2>/dev/null' EXIT
NOTCH_THEATER_DRY=1 NOTCH_THEATER_SOCK=$S NIRI_SOCKET=/nonexistent \
  NOTCH_THEATER_STREAM="python3 -c \"print('S'*80, end=''); [print('s'*80, end='') for _ in range(22)]\"; exec sleep infinity" \
  "$BIN" toggle || { echo "FAIL stage"; exit 1; }
win=$(tmux -L $S display -p -t theater '#{window_width}x#{window_height}')
[ "$win" = 82x26 ] || { echo "FAIL theater window $win"; exit 1; }
# Attach a real client inside a throwaway 82x26 tmux and capture what it draws.
tmux -L $P new-session -d -x 82 -y 26 "tmux -L $S attach -t theater"
sleep 2
shot=$(tmux -L $P capture-pane -p -t 0)
[ "${VERBOSE:-}" ] && printf '%s\n' "$shot"
row() { sed -n "$1p" <<<"$shot"; }
c() { row "$1" | cut -c"$2"; }
[[ $(row 1) == *"ASCII THEATER"* ]] \
  && [ "$(c 2 1)$(c 2 82)$(c 26 1)$(c 26 82)$(c 14 1)$(c 14 82)" = "┏┓┗┛┃┃" ] \
  && [ "$(row 3 | cut -c2-81)" = "$(printf 'S%.0s' {1..80})" ] \
  && [ "$(row 25 | cut -c2-81)" = "$(printf 's%.0s' {1..80})" ] \
  || { echo "FAIL frame does not hug the 80x23 stream"; printf '%s\n' "$shot"; exit 1; }
echo "ok theater: 82x26, marquee + frame hugging 80x23"
