# notch — a lean, niri-native shell

A cut-down, **niri-native** fork of [andreumassanet/impasto](https://github.com/andreumassanet/impasto).
It started as a Quickshell shell for Hyprland and is now a small one for niri,
built for a cloud VM that you reach over RustDesk from an iPad.

## What is kept

| Part | Where |
|---|---|
| Bar: launcher button, niri workspaces, tray, T3 chip, notifications, network, volume, control centre | `bar/` |
| The island: launcher (apps, `=` calculator, `>` desk and themes, windows, clipboard, emoji) | `bar/island/LauncherPanel.qml`, `services/LauncherService.qml` |
| Notifications (the shell is the server) and the OSD | `NotificationLayer`, `OsdLayer`, `NotificationService` |
| Control centre: toggles, volume, clock, session, shortcuts, notification list | `bar/island/ControlsPanel.qml`, `controls/` |
| Capture: region, window and screen, annotate (satty), OCR (tesseract), recording (wf-recorder) | `capture/`, `CaptureService`, `RecorderService` |
| Clipboard history | `ClipboardService`, `scripts/clipboard.py` |
| Session menu (log out, restart, shut down) and polkit prompt | `SessionPanel`, `AuthPanel` |
| **T3 Code card**: t3code-web state, the installed nightly against the latest release, Open / Start / Update | `T3Module`, `T3Service`, `scripts/t3.py` |
| **Ink themes**: e-ink, e-ink-dark, red-ink, red-ink-dark | `home/.local/share/notch/themes`, `notch-theme` |
| niri config with Alt as the main key | `home/.config/niri/config.kdl` |

Everything else was cut: Hyprland, the desktop widgets, dock, deck, settings window, lock, games, pets,
weather, markets, GitHub, Claude/Codex meters, VMs, servers, camera effects, the palette engine,
SDDM/Plymouth/GRUB/mkinitcpio, and the dotfiles for kitty, nvim, yazi, zsh and the rest.

## niri

`NiriService` keeps one `niri msg --json event-stream` open (workspaces, windows, focus, overview)
and sends `niri msg action …`. It uses no hyprctl and no shim. The key sheet reads binds from the
niri config (`scripts/niri_binds.py`).

## Install

```sh
./setup            # packages, files (backs up what it replaces), theme e-ink
niri msg action spawn -- qs -n     # or log in again; the niri config spawns it
```

`./setup` only touches `$HOME` and packages. It never changes the boot loader, the initramfs or /etc.

## Commands

```
notch open|toggle launcher|controls|t3|keys|session|clipboard|emoji
notch capture [region|window|screen] | capture text | record
notch t3 [get|refresh|update|open]
notch volume <n> | volume mute     notch focus toggle
notch-theme set e-ink|e-ink-dark|red-ink|red-ink-dark · next · next-wallpaper
```

`notch-theme` writes the colours for the shell (`~/.local/state/notch/theme.json`), ghostty,
helix, niri's focus ring and border, mako and fuzzel, and runs swaybg as the `notch-wallpaper` user unit.

## Keys (Alt is the main key; Super still works)

| Key | Does |
|---|---|
| Alt+Space | Launcher |
| Alt+Return / Alt+Shift+Return | Ghostty / Helium |
| Alt+Q, Alt+F, Alt+Shift+F | Close, maximise, fullscreen |
| Alt+arrows, Alt+Shift+arrows | Focus, move |
| Alt+1…5, Alt+Shift+1…5 | Workspace, move to workspace |
| Alt+Tab | Overview |
| Alt+Shift+C / T / K / V / . / E | Control centre / T3 / keys / clipboard / emoji / session |
| Alt+Shift+S / A / R | Capture region / capture surface / record |
| Alt+Shift+N | Do not disturb |
| Alt+Shift+Y / W | Next theme / next wallpaper |

GPL-3.0, like upstream.
- [INSTALL.md](INSTALL.md): fresh Arch setup. Build mode: `notch evolve`.
