# Agents working on Notch

The notch's own skill lives on the machine, not here: the agent reads
`~/.config/opencode/skill/notch/SKILL.md`: layout, IPC testing, the theme
audit, the tests and the rules. This repo has no assistant in it: the
thinking happens next door (T3 Code), and the notch hands its context over
(`notch context get` / `notch context hand`).

## Where things are

- `packages/<name>/install`: where each package's files land. A new file
  needs a line here or `./setup files` will not copy it.
- `packages/shell/quickshell/qmldir`: every singleton the shell has. **A
  new service must be listed here** or the shell will not start, and the
  error names the missing type, not the missing line.
- `packages/shell/quickshell/Commands.qml`: every IPC target lives in the
  config root. A handler inside a service singleton registers fine
  (`playing` is one), but the config root imports `./services`, so a
  broken file in a service takes every target down with it. When a target
  answers "Target not found", suspect the config failed to load, not the
  handler.
- `tests/`: `sweep.sh` (everything, including the media), `bar.sh` (the
  shell itself), `mirror.sh` (the machine against this repo),
  `size-ratchet.sh` (no file grows past the cap). `setup.sh` installs a
  fresh copy into a temporary HOME; it is the check that the install
  actually lands where it says.
- The shell's own errors only show in its log: `qs -n` writes them to
  stderr, so start it with the output redirected when something will not
  load.
