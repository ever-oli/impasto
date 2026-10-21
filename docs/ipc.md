# The notch's IPC

Everything the shell can do is an IPC call. One command, one target, one
verb:

```
qs ipc call <target> <verb> [args…]
```

Every answer is JSON. Success carries `{"ok":true, …}`; failure carries
`{"error":"…"}`. The `notch` CLI is a thin wrapper over these — `notch
context get` is `qs ipc call context get` — and the panels, the palette
and the niri binds all go through the same calls.

This is the notch's public surface: an agent drives the shell through
this, and nothing else.

## The targets

| target | verbs | what it does |
|---|---|---|
| `panel` | `open <name>`, `toggle <name>`, `close`, `list` | the island's panels: `launcher`, `controls`, `t3`, `keys`, `session`, `clipboard`, `emoji`, `anime`, `notchstorm` |
| `context` | `get`, `hand` | what the notch knows, and handing it over |
| `work` | `get`, `platforms`, `platform <name>`, `hand <job\|platform> <n>` | the remote postings and the AI training platforms |
| `modules` | `list`, `failed`, `reload <name>` | the bar's modules; `failed` names the ones that did not load |
| `capture` | `open [region\|window\|screen]`, `text`, `record` | the screenshot and the recorder |
| `theme` | `set <id>`, `get` | the four ink themes |
| `picker` | `open <theme\|wallpaper>`, `step <n>`, `keep` | the carousel in the notch |
| `palette` | `open <path>`, `search <text>`, `rows`, `actions <n>`, `pick <n>`, `type <text>` | the launcher and the menu tree |
| `volume` | `set <n>`, `mute [on\|off\|toggle]`, `get` | the sound |
| `focus` | `set [on\|off\|toggle]` | do not disturb |
| `osd` | `say <text> [icon]` | a line on the island |
| `t3` | `get`, `refresh`, `update`, `open` | the agent's own app: its service, its version, and raising it |
| `shell` | `reload` | reload the shell from disk |

## The handoff

The notch has no assistant in it. It says what it knows and gets out of
the way:

```
qs ipc call context get     # {"panel":…,"hero":…,"work":[…],"platforms":[…],
                            #  "profile":"~/.config/notch/profile.md", …}
qs ipc call context hand    # that, on the clipboard, with T3 in front
qs ipc call work hand job 0 # one posting, on the clipboard, with T3 in front
```

`context hand` and `work hand` put a plain-text brief on the clipboard
and open T3 Code. From there the agent drives the notch back — the
panels, the theme, the capture — and the desktop, with `notch-act`
(grim, wtype, wlrctl, niri) or the Cua driver's MCP tools.

## What a caller should know

- **The shell must be running.** Every call needs `qs` up; the answer
  says so if it is not.
- **`panel open` is idempotent** in effect: opening the panel that is
  already open leaves it open, and `panel close` closes whatever is up.
- **`work hand` takes an index**, not a title: the list is in
  `work get` and `work platforms`, and the order is the order of the
  shelf.
- **`theme set` applies to everything** — the shell, the terminals, the
  borders, the wallpaper.
- **The shell's own errors are not answers.** A QML error shows in the
  shell's log, not in the reply; the reply is empty or the target is
  missing entirely.

## Checking it

`tests/bar.sh` opens every panel, calls every target, and checks that
each answer carries data. `tests/sweep.sh` does the same and adds the
media. Both run against the live shell.
