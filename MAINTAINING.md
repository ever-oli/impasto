# Maintaining Notch

Ever's desktop: plain Arch (no Omarchy) + niri + Quickshell, with Notch as the
shell. MIT; keep GPL code (caelestia, end-4, vicinae) out.

## What's installed
- **Compositor:** niri (`~/.config/niri/config.kdl`, one bind per line; `niri validate`). greetd autologins `ever` into `niri-session`.
- **Shell:** Quickshell (`home/.config/quickshell`): bar, notch island, palette, assistant (`scripts/ask.py` → `opencode acp`).
- **CLIs** (`home/.local/bin`): `notch` (palette, picker), `notch-theme`, `notch-font`, `notch-act`, `notch-doctor`; `impasto` is a compat symlink.
- **Themes:** `home/.local/share/notch/themes/<name>/colors.toml` is the source of truth; `themed/*.tpl` render Ghostty, Helix, niri, fuzzel, btop, fastfetch, fzf, GTK, qt6ct, T3, Helium policy.
- **Text size:** `notch-font size <n>` (default 11) → `~/.config/notch/font-size`; notch-theme renders it everywhere (shell `Theme.fs()`, Ghostty n+2, fuzzel n+1, GTK, qt6ct, mako).
- **Packages:** `packages/pacman.txt`, `packages/aur.txt`. Machine-specific bits (bash, mako, mise, greetd, package snapshot) live in ever-oli/dotfiles.

## Layout
`home/` mirrors `~`; `setup` installs it; `tests/` holds the checks; `packages/` the lists.

## Update
1. `git pull` here (or `chezmoi update`, which re-runs `./setup files`).
2. `./setup files` (backs up to `~/.config-backups/notch-<stamp>`), then `notch-theme restore`.
3. Restart the shell only by exact PID, then `niri msg action spawn -- qs -n`. Never restart niri while Ever is connected.
4. `sudo pacman -Syu`; AUR via `yay`. Check `notch doctor` after.

## Backups
- Before editing a config: copy it to `<file>.bak-<what>-<stamp>` or tar into `~/.config-backups/`.
- EBS snapshots of the old Omarchy VM: snap-06611535b7cbe4b97, snap-01c4d1c4bfe2db918 (us-east-2).

## Tests
- `notch doctor`: hotkeys, niri validate, quickshell + palette IPC, text size, dependencies.
- `notch-theme audit` / `tests/theme-contrast.sh`: 4.5:1 text, 3:1 icons, every theme.
- `tests/palette-ipc.sh`: drives the palette through `qs ipc call palette …` (never type into the live session).

## Rules
Never `pkill`/`killall` by name; close windows by niri id or exact PID. No secrets in the repo (profile.md, notch/files, keys stay on the VM).
