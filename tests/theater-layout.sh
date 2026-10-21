#!/bin/bash
# notch-theater stages an 84x27 tmux window (+1 marquee) whose stream pane is
# exactly 80x23 at (2,2), framed on all four sides. Headless: no window opens.
set -u
BIN=$(dirname "$0")/../home/.local/bin/notch-theater
S=notch-theater-test-$$ P=notch-theater-proof-$$
trap 'tmux -L $S kill-server 2>/dev/null; tmux -L $P kill-server 2>/dev/null' EXIT
NOTCH_THEATER_DRY=1 NOTCH_THEATER_SOCK=$S NIRI_SOCKET=/nonexistent \
  NOTCH_THEATER_STREAM="python3 -c \"print('S'*80, end=''); [print('s'*80, end='') for _ in range(22)]\"; exec sleep infinity" \
  "$BIN" toggle || { echo "FAIL stage"; exit 1; }
win=$(tmux -L $S display -p -t theater '#{window_width}x#{window_height}')
pane=$(tmux -L $S display -p -t theater '#{pane_width}x#{pane_height}@#{pane_left},#{pane_top}')
[ "$win" = 84x27 ] && [ "$pane" = 80x23@2,2 ] || { echo "FAIL theater: window $win, stream $pane"; exit 1; }
# Attach a real client inside a throwaway 84x28 tmux and capture what it draws.
tmux -L $P new-session -d -x 84 -y 28 "tmux -L $S attach -t theater"
sleep 1
shot=$(tmux -L $P capture-pane -p -t 0)
[ "${VERBOSE:-}" ] && printf '%s\n' "$shot"
row() { sed -n "$1p" <<<"$shot"; }
[[ $(row 3) == ' ┏'*'┓ ' ]] && [[ $(row 27) == ' ┗'*'┛ ' ]] && [[ $(row 4) == ' ┃'S*'┃ ' ]] \
  && [ "$(row 4 | cut -c3-82)" = "$(printf 'S%.0s' {1..80})" ] \
  || { echo "FAIL frame does not hug the 80x23 stream"; printf '%s\n' "$shot"; exit 1; }
echo "ok theater: window 84x27+marquee, stream 80x23 framed"
