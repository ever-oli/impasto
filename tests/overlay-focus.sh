#!/usr/bin/env bash
# Flags any quickshell layer surface using Exclusive keyboard focus unless the
# line just above it carries a `focus-exclusive-ok: <reason>` comment.
set -euo pipefail
root="${1:-$(dirname "$0")/../packages/shell/quickshell}"
bad=0
while IFS=: read -r file line _; do
  prev=$(sed -n "$((line-1))p;$((line-2))p" "$file")
  if ! grep -q 'focus-exclusive-ok:' <<<"$prev"; then
    echo "FAIL $file:$line Exclusive keyboard focus without a focus-exclusive-ok reason"; bad=1
  fi
done < <(grep -rn --include='*.qml' 'keyboardFocus:.*WlrKeyboardFocus.Exclusive' "$root" || true)
# The ternary may sit on the next line (Bar.qml); catch continuation lines too.
while IFS=: read -r file line _; do
  prev=$(sed -n "$((line-1))p;$((line-2))p;$((line-3))p" "$file")
  grep -q 'focus-exclusive-ok:' <<<"$prev" || { echo "FAIL $file:$line Exclusive keyboard focus without a reason"; bad=1; }
done < <(grep -rn --include='*.qml' -E '^\s*\?\s*WlrKeyboardFocus.Exclusive' "$root" || true)
[ $bad = 0 ] && echo "ok overlay focus: no unexplained Exclusive grabs"
exit $bad
