# Keybinds are load-bearing
<!-- Ever: 2026-10-20 — after Super+Up/Down stopped moving desktops -->

The niri binds in `~/.config/niri/config.kdl` (repo copy: `home/.config/niri/config.kdl`)
are a contract with Ever's hands. **Never remove, rebind or reword one** without an
explicit lesson saying so, and always edit BOTH copies (live + repo) — they must stay
byte-identical. The keys sheet in the notch reads the live config through
`scripts/niri_binds.py`, so new binds appear in the sheet automatically; there is no
separate list to update, and none to forget.

Contract (the actions behind each bind as of 2026-10-20):

- Desktops: `Mod+Up/Down` = focus-workspace-up/down (a deliberate fix — these used to
  be focus-window-up/down, which never moved a desktop; do not "restore" them).
  `Alt+1..5` and `Mod+1..5` jump to a numbered desktop; `Mod+Shift+Up/Down`,
  `Alt+Shift+Up/Down` carry a window between desktops.
- Columns/windows: focus `Mod+Left/Right`, `Mod+H/L`; move `Mod+Shift+Left/Right`;
  maximize `Mod+F`; fullscreen `Mod+Shift+F`; close `Mod+Q/Mod+W`; swallow/restore
  `Mod+Comma/Mod+Period`; width `Mod+Minus/Equal`. Same set on pure Alt mirrors niri
  for when Super is busy (e.g. remote-desktop).
- Overview: `Mod+D`, `Mod+O`, `Alt+O`, `Alt+Tab`.
- The notch: `Mod+Space`/`Alt+Space` launcher, `Mod+A`/`Alt+A` ask, `Mod+Y`/`Alt+Y`
  hold the browser page for ask, `Mod+Ctrl+T` theme picker, `Mod+Ctrl+B` wallpaper,
  `Mod+Ctrl+V` clipboard, `Mod+Ctrl+E` emoji, `Mod+Ctrl+S` screenshot region,
  `Mod+Ctrl+A` full capture, `Mod+Ctrl+R` screen recording, `Mod+Ctrl+K` this keys
  sheet, `Mod+Ctrl+C` controls, `Mod+Ctrl+3` the T3 panel, `Mod+Ctrl+N` focus mode,
  `Mod+Ctrl+Esc/Q` the session panel.
- Fixed hardware shortcuts: `Mod+Return`/`Alt+Return` ghostty, `Mod+Shift+Return`/
  `Alt+Shift+Return` Helium, `Ctrl+Shift+Z` T3 snapshot capture, `Mod+Alt+O` Orb.
- `Super=` Cmd-first. The full current truth is `niri msg action --help` + the live
  config; when Ever asks "does X have a key", read `scripts/niri_binds.py` output.

New binds must end up in both config copies in one step, and `niri validate` must pass.

## A lesson from a failed turn
<!-- Ever: 2026-10-21 — after a question that failed -->

When a screenshot or screen-capture tool call is denied, prompt the user to grant screen permission (or approve the tool) and retry once instead of returning an empty answer.

## A lesson from a failed turn
<!-- Ever: 2026-10-21 — kept because it worked, for every question -->

Add a rule to the answer policy: for general-knowledge questions that require no tools or files, answer directly from the model's own knowledge, and reserve "I cannot answer that right now" for cases where a required tool call fails or the needed data is genuinely unavailable.
