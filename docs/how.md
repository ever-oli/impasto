# How the notch works

For whoever has to change it. Read this before the code, so the code is
the second thing you read.

## The shape

The notch is one Quickshell config: a bar across the top of the screen
and an island that drops out of it. The island holds the panels. The bar
holds the modules. Both live in `packages/shell/quickshell/`.

```
shell.qml            the entry: the bar, the island, the panels
Commands.qml         every ipc target, in one file
qmldir               every singleton and component the shell can load
theme/               the colours, the motion, the translations
bar/Bar.qml         the bar
bar/widgets/        the island, the modules, the panels
bar/island/          one file per panel
services/            one singleton per thing with state
scripts/             the python the services run
```

## The panel flow

A panel opens, does its thing, and closes. The island arbitrates: the
panel is the highest layer that wants the screen, and it holds the screen
until the pointer leaves or the panel says it is done.

- `bar/widgets/DynamicIsland.qml` decides which panel is up. The sizes
  it gives each one are in one table at the top of the file.
- `bar/island/IslandState.qml` is the arbitration: the layers, and which
  one wins.
- Each panel is one file in `bar/island/`, and it says `onClosed` when it
  is done.

## The services

A service is a singleton with state. It lives in `services/` and **must
be listed in `qmldir`**. Miss that line and the shell will not start,
and the error names the type rather than the list.

The services that matter:

| service | what it holds |
|---|---|
| `SettingsService` | the user's settings, and the state file they live in |
| `NiriService` | the compositor: windows, workspaces, output |
| `AudioService` | the sound, and its devices |
| `LauncherService` | the app index, and the launcher's query |
| `MenuService` | the menu tree the palette shows |
| `AnimeService` | the catalogue: the shelves, the hero, the work |
| `CaptureService` | screenshots and the recorder |
| `T3Service` | the agent's own app: its version, its service |

## The ipc

Every target is in `Commands.qml`, and every target answers JSON. The
whole surface is in [ipc.md](ipc.md).

A handler inside a service singleton registers fine: `playing` is one,
and it answers. What does not work is a service with a broken file,
because the config root imports `./services` and the whole config fails
to load. When a target answers "Target not found", suspect the config,
not the handler. The shell's errors are in `~/.local/state/notch/qs.log`.

## The state

| what | where |
|---|---|
| the settings | `~/.local/state/notch/` |
| what is playing | `~/.local/state/notch/watching.json` |
| the watch history | `~/.local/state/notch/history.json` |
| the profile | `~/.config/notch/profile.md` |
| the lessons | `~/.config/notch/lessons.md` |
| the shell's log | `~/.local/state/notch/qs.log` |

## Changing it

1. `./setup files` copies the packages into `~` per their `install`
   manifests. It is the install, and it backs up what it replaces.
2. The machine is the install. `tests/mirror.sh` compares it with this
   repository, and it is the check that the machine and the repo agree.
3. The tests: `tests/bar.sh` for the shell, `tests/sweep.sh` for
   everything including the media, `tests/setup.sh` for the install,
   `tests/correct.sh` for the mistakes that keep happening.
4. The QML reloads when it changes. The services keep their state
   across a reload, so a panel that was open stays open.

## The rules

- The commit message is lowercase prose with a `feat(quickshell):` or
  `fix(quickshell):` prefix, and it says why.
- No file grows past the cap. `tests/size-ratchet.sh` holds it, and the
  ones already over are recorded in `.size-ratchet` with the size they
  may not exceed.
- The notch has no assistant in it. The thinking happens next door, and
  the notch hands over what it knows.
