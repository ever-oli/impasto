#!/bin/bash
# Run in the desktop session: checks root search, breadcrumbs, ✓, web fallback, Ctrl+K rows.
set -u; q() { qs ipc call palette "$@" 2>/dev/null; }; fail=0
check() { q search "$1" >/dev/null; sleep 0.6; q rows | grep -q "$2" && echo "ok   $1" || { echo "FAIL $1 (want $2)"; fail=1; }; }
check "theme" "Style › Theme"
check "zzqqxy" "web: Search DuckDuckGo"
q search theme >/dev/null; sleep 0.6; q actions 0 >/dev/null; sleep 0.3
q rows | grep -q "act: Pin" && echo "ok   ctrl+k" || { echo "FAIL ctrl+k"; fail=1; }
qs ipc call panel close >/dev/null 2>&1; exit $fail
