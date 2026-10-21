# Installing Notch on a fresh Arch machine

Notch is Ever's Arch distro: niri + Quickshell, with Pi as the notch's engine.
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
3. **Packages:** `packages/pacman.txt` (pacman) and `packages/aur.txt` (yay).
4. **Notch:** `./setup fonts` (AnnotationMono + Tinos Nerd Fonts), `./setup files` (copies
   `home/` into `~`, backing up to `~/.config-backups/`), `./setup theme`.
5. **greetd/niri:** `system/etc/greetd/config.toml` from the dotfiles to `/etc/greetd/`,
   `systemctl enable greetd`; it autologins into `niri-session`, which spawns `qs`.
6. **Pi:** `mise use -g node@latest`, `npm i -g @earendil-works/pi-coding-agent
   @mermaid-js/mermaid-cli`, `pi install git:github.com/kevinqz/optchat-durable@v0.5.0`
   (OptChat + pi-durable memory). `~/.config/notch/ask-backend` = `pi`.
   opencode is a hidden fallback: `notch ask backend opencode`.

## Add by hand (never committed)
- `pi` → `/login` (OpenRouter, ChatGPT, Claude or an API key) → `/model`
  (needs ≥40k context; vision preferred).
- `gh auth login` (Build mode pushes and opens PRs with it).
- `~/.config/notch/profile.md`, `~/.config/notch/files/<mode>/` (private).
- RustDesk password, SSH keys, any API keys.

## Build mode: Notch changes itself
Palette → **Ask Notch to change itself**, or `notch evolve "<request>"`. It works in
`~/src/notch` and `~/src/dotfiles` with `notch-dev` (branch, test, PR, deploy, restart-qs,
sync-dots); every write asks first (`a` approves the rest of the run). Pushing straight to
`main` directly only happens with `echo on > ~/.config/notch/auto-merge`. Corrections go to
tests first, then `~/.config/notch/lessons.md`, which Build mode reads every time.

## Check
`notch doctor` — hotkeys, shell, Pi model + answer, text size, dependencies.
