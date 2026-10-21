---
name: notch
description: How Notch (Ever's niri + Quickshell Arch distro) is laid out, tested and changed. Load before editing ~/src/notch, ~/.config/quickshell, ~/.config/niri or Ever's dotfiles, and for every `notch evolve` / Build mode task.
---
# Notch

Notch is Ever's own Arch distro: niri (compositor) + Quickshell (bar, notch island,
palette, orb, assistant). Pi is its engine. MIT; never copy GPL code (caelestia,
end-4, vicinae). Ported MIT code keeps its notice and gets a line in CREDITS.md.

## Layout (repo ~/src/notch = github ever-oli/notch, branch main)
- `home/` mirrors `~`; `./setup files` copies it in (backs up to `~/.config-backups/notch-<stamp>`).
- `home/.config/quickshell/`: `shell.qml` (entry), `Commands.qml` (every IPC target),
  `services/*.qml` (singletons, listed in `qmldir`), `bar/` (Bar.qml, `island/`, `modules/`),
  `components/`, `orb/`, `fontsize/`, `scripts/*.py` (helpers the services run), `theme/`.
- Bar/island modules: a file in `bar/modules/`, a row in `ModuleService.catalogue`, a line in
  `bar/modules/Module.qml` (`files`). Each loads on its own Loader; a failure is skipped and
  logged (`qs ipc call modules failed`), reload one with `qs ipc call modules reload <id>`.
- Palette rows: `services/LauncherService.qml` (`search`, `activate`), menus in `MenuService.qml`.
- `home/.local/bin/`: `notch` (CLI), `notch-doctor`, `notch-theme`, `notch-font`, `notch-dev`,
  `notch-term`, `notch-act`. `home/.config/niri/config.kdl`: one bind per line.
- `home/.local/share/notch/deps.tsv`: the only dependency list (package, source, need,
  command, purpose). `install`, `./setup packages` and `notch doctor` read it. Add deps there.
- Themes: `home/.local/share/notch/themes/<name>/colors.toml`; `themed/*.tpl` render apps.
- Docs: README.md, INSTALL.md, MAINTAINING.md, CREDITS.md. Tests: `tests/*.sh`.

## Testing without restarting the bar
- Quickshell live-reloads QML when files under ~/.config/quickshell change. After
  `notch-dev deploy`, check with IPC, not by looking: `qs ipc show` lists targets;
  `qs ipc call palette search <term>` then `qs ipc call palette rows`;
  `qs ipc call modules list|failed|reload <id>`; `qs ipc call orb status`.
- Watch errors: `journalctl --user -t qs` or the qs log in `/run/user/$UID/quickshell/`.
- Restart only if live reload is not enough: `notch-dev restart-qs` (exact PID, respawn via niri).

## Checks (all must pass: `notch-dev test`)
- `notch doctor`: binds, `niri validate`, IPC, failed modules, text size, Pi, deps.tsv.
- `notch-theme audit` (= tests/theme-contrast.sh): 4.5:1 text, 3:1 icons, every theme.
- `tests/*.sh`; tests whose line 2 says "Run in the desktop session" drive the live palette
  and only run with NOTCH_DEV_LIVE=1.

## Rules
- Back up a config before editing it. Edit the repo, then deploy; never edit live config first.
- Never pkill/killall by name: exact PID or niri window id only. Never restart niri.
- Never open overlays or type on Ever's screen; test through IPC.
- One niri bind per line, then `niri validate`.
- No secrets in any repo (Pi auth, API keys, profile.md, ~/.config/notch/files).
  Scripts may read a key at run time (scripts/openrouter.py) but never print or store it.
- Keep commits small and focused; `git pull --rebase` often (other agents work here too).
- Follow ~/.config/notch/lessons.md; record new corrections with `notch-dev lesson`.
