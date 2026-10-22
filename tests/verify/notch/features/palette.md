# The palette

## Sub-features

- `palette open <path>` opens the menu tree at a path (`/` is the root).
- `palette search <text>` filters; `palette rows` answers with the rows the
  user would see.
- A query that matches nothing falls back to a web row, so there is always
  something to press.
- `palette actions <n>` lists what Enter would do on row n.
- `palette pick <n>` runs the row.

## How to get to it (user POV)

The user presses the notch's launcher key (in `~/.config/niri/config.kdl`,
`notch palette` or the palette sigil). The palette is a fuzzy menu over the
apps, the theme, the capture, the work and the agent.

## Driving it with the helper

```sh
tests/verify/notch/notch-drive.sh palette <evidence-dir>
```

It opens the palette, searches for `theme`, checks the rows answer, then
searches for `zzqqxy` (nothing matches) and checks the web fallback appears.
The raw calls:

```sh
qs ipc call palette open "/"
qs ipc call palette search theme
sleep 0.6
qs ipc call palette rows
```

`palette rows` needs a moment after a search: the answer follows the search,
so sleep before you read it.

## Gotchas

- `palette rows` answers `{"ok":true,"rows":[…]}` with the rows as one
  string. There is no per-row structure to assert on; assert on the text a
  user would read.
- `palette pick` **runs** the row. It can start an app or a command. Never
  pick a row in a verification run unless the feature map says it is safe.
- The palette is a launcher mode: `panel open launcher` and `palette open`
  are not the same surface, and closing one does not close the other.
- `qs ipc call palette open "/"` in a shell whose `HOME` is not Ever's
  answers `Could not find "default" config directory or shell.qml in any
  valid config path.` That is the *client* failing to find the config, not
  the palette failing. Check `echo $HOME` before believing it.
