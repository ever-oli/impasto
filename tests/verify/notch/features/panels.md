# The island's panels

## Sub-features

- `launcher`, `controls`, `t3`, `keys`, `session`, `clipboard`, `emoji`,
  `anime`, `notchstorm` open and close from the island.
- `windows`, `files`, `bluetooth`, `sound`, `microphone` are launcher modes:
  they open the launcher on a sigil, not a separate panel.
- `panel close` closes whatever is up.
- A panel that is not in the list must be refused with an error, not a
  silent no-op.

## How to get to it (user POV)

The notch's key binds (in `~/.config/niri/config.kdl`) call `notch toggle
<panel>`, or the palette calls the panel. The user never types an IPC call;
the user presses a key and the island opens.

## Driving it with the helper

```sh
tests/verify/notch/notch-drive.sh panels <evidence-dir>
```

It opens every panel, closes it, and checks the shell is still answering
after the cycle. The raw calls:

```sh
qs ipc call panel open launcher
qs ipc call panel close
qs ipc call panel list
```

## Gotchas

- `panel list` lists the panels the shell knows, not the one that is open.
  There is no IPC call that says which panel is up: the only observable
  proof that a panel opened is that the call answered `ok` and the screen
  changed. A proof that needs "the panel is open" has to look at the screen
  (the Cua driver), not at the IPC.
- The shell's own errors do not come back in the answer. A QML error shows
  in the shell's log; the reply is empty, or the target is missing. When a
  target answers "Target not found", the config failed to load, not the
  handler: check `qs ipc call modules failed` and the shell's stderr.
- `tests/bar.sh` opens the same panels, but it does not close the island
  and it leaves the theme changed. Prefer this map's scenario.
