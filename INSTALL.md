# Installing Notch on a fresh Arch machine

Notch is Ever's Arch distro: niri + Quickshell, with T3 Code as the engine next door.
Two repos: **ever-oli/dotfiles** (chezmoi, branch `notch-desktop`, machine bits) and
**ever-oli/notch** (branch `main`, the shell). One script does it all:

```sh
sudo pacman -S --needed git chezmoi
chezmoi init --apply --branch notch-desktop ever-oli/dotfiles   # clones Notch to ~/.local/src/notch
~/.local/src/notch/install --dry-run    # see what it would do
~/.local/src/notch/install              # idempotent; re-run any time
```

## What `install` does (and how to do it by hand)
1. **Base tools:** `git chezmoi base-devel github-cli mise`, then `yay` from the AUR.
2. **Dotfiles:** `chezmoi init --apply ever-oli/dotfiles`. Its `.chezmoiexternal.toml` clones
   Notch and `run_onchange_after-notch.sh` runs `./setup files` on every new commit.
3. **Packages:** `home/.local/share/notch/deps.tsv`, one table for pacman, AUR (yay), npm and mise.
4. **Notch:** `./setup fonts` (AnnotationMono + Tinos Nerd Fonts), `./setup files` (copies
   `home/` into `~`, backing up to `~/.config-backups/`), `./setup theme`.
5. **greetd/niri:** `system/etc/greetd/config.toml` from the dotfiles to `/etc/greetd/`,
   `systemctl enable greetd`; it autologins into `niri-session`, which spawns `qs`.
6. **The agent:** T3 Code (or any opencode-based agent) does the thinking.
   The notch has no brain of its own: it says what it knows and hands it
   over. `notch context hand` puts the context on the clipboard and T3 in
   front of it. The notch's own skill, modes and rules live in
   `~/.config/opencode/skill/notch/`.

## Add by hand (never committed)
- `gh auth login` (the agent pushes and opens PRs with it).
- `~/.config/notch/profile.md`, `~/.config/notch/files/<mode>/` (private).
- RustDesk password, SSH keys, any API keys.

## The agent: the thinking happens next door
The notch is a device — a catalogue, a screen, a set of postings, and an
island terminal. T3 Code (or any opencode agent) does the thinking, and
the seam is small: `notch context get` says what the notch knows, and
`notch context hand` puts it on the clipboard and brings T3 up. From
there the agent drives the notch back (`qs ipc call panel open anime`,
`notch work …`) and the desktop (`notch-act`).
Corrections go to `~/.config/notch/lessons.md`, which the agent reads.

## Check
`notch doctor` — hotkeys, shell, the agent, text size, dependencies.
