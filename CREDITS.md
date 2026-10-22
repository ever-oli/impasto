# Credits

- **Orb** (`packages/shell/quickshell/orb/`) is ported from
  [tcballard/omarchy-plugin-orb](https://github.com/tcballard/omarchy-plugin-orb),
  MIT, © 2026 Tom Ballard. Its licence is kept at `packages/shell/quickshell/orb/LICENSE`.
  The wheel's look, motion, keyboard handling and geometry come from its `Wheel.qml`,
  `Model.js` and `LineIcon.qml`; Hyprland, install and settings code were dropped.

- **k4 ideas** from [k4ditano/k4](https://github.com/k4ditano/k4), MIT, © k4ditano.
  No k4 code was copied; these were rebuilt for niri + Quickshell after its features:
  the agent skill file (`~/.config/opencode/skill/notch/SKILL.md`), one dependency table
  (`packages/data/notch/deps.tsv`), searchable keybinds in the palette, per-module
  isolated loading with hot reload (`bar/modules/Module.qml`), the AI usage meter
  (`services/UsageService.qml`, `scripts/openrouter.py`), SSH quick-connect, and the
  terminal under the island (`notch-term`). k4's licence: MIT License, Copyright (c) k4ditano.
