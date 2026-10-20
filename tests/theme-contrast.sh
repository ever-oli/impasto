#!/bin/sh
# Every themed fg/bg pair must meet WCAG AA (4.5:1 text, 3:1 marks).
# Runs against the repo's themes, not the installed ones.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
HOME="$root/home" python3 "$root/home/.local/bin/notch-theme" audit
