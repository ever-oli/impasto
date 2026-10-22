# The handoff

## Sub-features

- `context get` answers with what the shell knows: the panel, the hero, the
  work, the platforms, the profile path, the lessons path.
- `context hand` puts that on the clipboard as a plain-text brief and brings
  T3 Code up.
- `work hand <job|platform> <n>` hands over one posting, by index.
- The seam is the clipboard. There is no API into the agent.

## How to get to it (user POV)

The palette has a "Ask T3" row. The agent (T3 Code, or any opencode agent)
runs `notch context get` or `qs ipc call context get` and reads the JSON. The
shell has no assistant in it: the thinking happens next door.

## Driving it with the helper

```sh
tests/verify/notch/notch-drive.sh context <evidence-dir>
```

It checks that `context get` carries the hero and the work, then that
`context hand` put a brief on the clipboard, read back with `wl-paste`. The
raw calls:

```sh
qs ipc call context get
qs ipc call context hand
wl-paste --no-newline | head -c 400
```

## Gotchas

- `context get` carries `"panel":""` when no panel is open. That is not a
  failure; assert on the hero and the work, not on the panel.
- The brief on the clipboard starts with the marker `notch-context`. Use it
  to tell the handoff from whatever was on the clipboard before: the
  clipboard is shared, and the previous brief is still there.
- The handoff is excluded from the clipboard history watcher, but the
  clipboard itself still keeps it. A second `context hand` produces the
  same text, so "the clipboard changed" is not a proof that the handoff
  happened.
- `work hand` takes an **index**, not a title. The order is the order of
  the shelf in `work get`.
