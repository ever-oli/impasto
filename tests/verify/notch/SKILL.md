---
name: verify-notch
description: "Drive the live notch shell (Quickshell/Wayland desktop shell) over its IPC surface and prove what a user can see. Use when changing the shell, the panels, the palette, the handoff or the theme, and you need evidence that it works on Ever's machine, not just that a file compiles."
---

# Verify the notch

The notch is a Wayland desktop shell: niri + Quickshell, running inside Ever's
desktop session. It has no test server and no separate dev instance. Its
public surface is IPC, and the CLI is a thin wrapper over it.

**This skill drives the real shell on the real machine.** Read it cold: you are
probably mid-change, and you have never seen this app.

## The feature map

`features/` is the maintained list of what a user can do with the shell
and how each journey is proved: one file per journey
(`features/panels.md`, `features/palette.md`, `features/handoff.md`,
`features/theme.md`, `features/work.md`). A proof that drives one
convenient entry point is incomplete when the map lists others, so the
map is where a new journey goes.

## The surface

- `qs ipc call <target> <verb> [args]` — the whole shell. Every answer is
  JSON: `{"ok":true, …}` or `{"error":"…"}`. The targets and verbs are
  written down in `docs/ipc.md` in the repo (`/home/ever/src/notch`).
- `~/.local/bin/notch <verb>` — the CLI a key bind runs. It is the same IPC,
  plus `learn`, `reload`, `doctor`, `install`.
- The observables: the JSON answers, `niri msg -j windows`,
  `wl-paste` (the clipboard), `~/.local/state/notch/theme.json` (the shell's
  own state), `~/.config/ghostty/notch-theme` (what the terminals follow).

There is **one** shell. You cannot start a second one and drive it: a second
`qs` would fight the first over the same sockets and the same config
directory. Drive the one that is running. If it is not running, start it
(the next section), and if you cannot, say so and stop: do not fake a proof.

## Launch

The shell is spawned by niri at login (`niri msg action spawn -- qs -n`). To
make it ready:

```sh
# is it up?
pgrep -u "$(id -u)" -x qs
qs ipc call panel list          # {"ok":true,"panels":[...]}
```

If it is not up, start it **through niri**, never by hand:

```sh
notch-dev restart-qs            # kills the exact qs PID, respawns via niri
```

`notch-dev restart-qs` refuses to run if there is more than one `qs` PID.
Do not use `pkill`; the repo's rules ban it (MAINTAINING.md, "Rules").

After a change to the shell's QML, `qs ipc call shell reload` reloads from
disk without losing the session.

To pick up a change to the repo's own files (`packages/**`), install them:

```sh
cd /home/ever/src/notch && ./setup files   # backs up what it replaces
notch-dev restart-qs
```

`./setup files` rewrites `~/.config/quickshell` and the desktop config. It is
safe to re-run, and it backs up to `~/.config-backups/notch-<stamp>`.

## Doctor

One read-only check answers "is this instance worth driving?":

```sh
tests/verify/notch/notch-drive.sh doctor tests/verify/notch/evidence/doctor
```

It checks four things and writes every raw answer next to the verdict: the
`qs` process is up, `panel list` answers with the panel list, `modules failed`
is `{}` (no bar module failed to load), and `notch doctor` runs.

If `modules failed` is not empty, the shell is not worth driving: a module
that failed to load means the bar is broken, and the answers you collect
after that are not the shell Ever sees. `qs ipc call modules reload <name>`
reloads one module.

The doctor also has to answer "is this the shell Ever runs?", not just
"is a shell up":

- **the version.** The shell is the one the install put there. A stale
  `qs` on the PATH answers the ipc and shows an older shell, and the
  proof is then of something Ever does not use. Compare the machine's
  `~/.config/quickshell` with the repository (`tests/mirror.sh`), or the
  proof is of a different shell than the one Ever sees.
- **the ownership of the screen.** The shell has to be the one on this
  display: `niri msg -j windows` names the island's window, and the
  proof is a screenshot of that window, not of whatever is in front.

## Drive

The helper drives the five journeys the feature map lists. It goes through
the real surface and asserts on what a caller can observe, not on the word
"ok":

```sh
tests/verify/notch/notch-drive.sh <doctor|panels|palette|context|theme|work> <evidence-dir>
```

- `panels` — every panel opens and closes, and the shell still answers after
  the cycle.
- `palette` — the palette opens, searches, answers rows, and falls back to
  the web when nothing matches.
- `context` — `context get` carries the hero and the work, and `context hand`
  puts a brief on the clipboard (read back with `wl-paste`).
- `theme` — the theme changes, the shell's state file and the terminal's file
  follow, and the theme is put back.

The raw commands, if you need one the helper does not have:

```sh
qs ipc call panel open launcher
qs ipc call palette search theme
qs ipc call palette rows
qs ipc call context get
qs ipc call osd say "hello"
niri msg -j windows | python3 -m json.tool
```

Prefer `notch` over raw IPC when a bind uses `notch`: that is the path a key
press actually takes.

## Evidence

The helper writes to the evidence directory you pass it (default:
`tests/verify/notch/evidence/<timestamp>`):

- `<ipc call>.json` — the raw answer of every call, exactly as it came back.
- `verdict.txt` — one line per check, `ok` or `FAIL`.
- `handoff-clipboard.txt` — what the clipboard carried after `context hand`.
- `palette-rows.txt` — the rows the palette answered with.

Proof standards for this repo:

- Exercise the user path. `notch open launcher` and `qs ipc call panel open
  launcher` are the same call; use the one a bind uses.
- Capture the action *and* the result. The JSON answer alone is the shell
  saying it accepted the call. The state after it (the clipboard, the theme
  file, the window list) is the proof.
- Verify the side effect, not the acknowledgement. `capture text` answers
  `{"ok":true}` and nothing else; it has opened an overlay, not read the
  screen. `theme set` over IPC changes the shell, not the terminals; the
  CLI `notch-theme set` changes both.
- Never weaken a journey to make it pass. If a journey fails, the failure and
  the reason go in that feature's `Gotchas`.

## Cleanup

- Close what you opened: `qs ipc call panel close`.
- Put the theme back: `notch-theme set <the id you found>`. The `theme`
  scenario does this for you and proves it with `theme get`.
- Leave the evidence where it is. It is the proof; cleanup never eats it.
- Do not kill the shell to "clean up". If you started it, leave it running:
  Ever's session is the thing under test.

## Gotchas

- `notch learn --help` **writes "--help" into `~/.config/notch/lessons.md`**.
  The verb has no `--help` case. Never run it to check the CLI.
- `notch doctor` has no `--help` case either: it runs the whole diagnosis
  and exits 1 when something is wrong.
- `qs ipc call capture text` opens a capture overlay on Ever's screen and
  returns immediately. The overlay stays up. Cancel it (Escape) before you
  drive anything else.
- `notch-qml` renders in a bubblewrap jail and gives itself 8 seconds. The
  first render after a boot copies the QtQuick modules and takes longer than
  that, so it fails cold. Run it twice, or warm it first.
- `qs ipc call` always exits 0, even for an error answer. Check the answer
  (`"error"` in it), not the exit code. The `notch` CLI does this for you and
  exits 1 on an error.
