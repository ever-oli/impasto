# The ink themes

## Sub-features

- Four themes: `e-ink`, `e-ink-dark`, `red-ink`, `red-ink-dark`.
- `theme get` answers with the active id and the list.
- The shell, the terminals, the borders and the wallpaper follow.
- `notch-theme audit` checks every themed pair meets its contrast.

## How to get to it (user POV)

The palette has "Style › Theme › Carousel". The user picks a theme; the
whole machine follows.

## Driving it with the helper

```sh
tests/verify/notch/notch-drive.sh theme <evidence-dir>
```

It changes the theme with the CLI, checks `theme get` says so, checks the
shell's own state file (`~/.local/state/notch/theme.json`) carries the new
id, checks the terminal's file (`~/.config/ghostty/notch-theme`) changed,
and puts the theme back and proves it.

## Gotchas

- **The IPC `theme set` and the CLI `notch-theme set` are not the same
  thing.** The IPC call changes the shell. The CLI also re-renders the
  terminals, the borders and the wallpaper. `docs/ipc.md` says "theme set
  applies to everything"; that is true of the CLI, not of the IPC call.
  A verification that only checks `theme get` cannot tell the two apart.
- `notch-theme set` **exits 0 when the theme does not exist**
  (`no theme 'x' (have: ...)`). A script that restores a theme with it will
  not notice that it failed.
- The theme id is in `~/.local/state/notch/theme.json` as `"id"`. That file
  is the shell's own state; it is the observable that the shell took the
  change, not just that the call was accepted.
- `tests/bar.sh` sets the theme to `e-ink` and never puts it back. If you
  ran it, the machine is on `e-ink` until someone sets it again.
