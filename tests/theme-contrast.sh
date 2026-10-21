#!/bin/sh
# Every themed fg/bg pair must meet WCAG AA (4.5:1 text, 3:1 marks).
# Runs against the repo's themes, not the installed ones.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
# Moving HOME can put a shimmed interpreter's config out of its trust
# list, so say which config to trust when there is one.
if [ -f "$HOME/.config/mise/config.toml" ]; then
    MISE_TRUSTED_CONFIG_PATHS="$HOME/.config/mise/config.toml"
    export MISE_TRUSTED_CONFIG_PATHS
fi
HOME="$root/home" python3 "$root/home/.local/bin/notch-theme" audit
