# Quickshell, for the notch

What the shell is made of, what it can do, and where it bites. Written
against the version the notch runs and the documentation as it stands.

**The version in use: Quickshell 0.3.2** (revision blank, distributed by
Arch Linux) — `qs --version` on this machine.

**The documentation is behind the version.** The docs site now serves
`https://quickshell.org/docs/v0.1.0/…` (the old `quickshell.outfoxxed.me`
paths answer 301 to it), so the published docs describe **0.1.0** while the
shell here is **0.3.2**. Treat every page as "0.1.0, probably still true",
and check the source when it matters. The upstream repository is
`quickshell-mirror/quickshell` (`outfoxxed/quickshell` redirects to it).

## The modules

From the `Quickshell.Io` page's own navigation, the type inventory of the
documentation is:

| module | what is in it |
|---|---|
| `Quickshell` | the singleton every shell reaches for: paths, `execDetached`, data directories |
| `Quickshell.Io` | `Process` and the stdio types |
| `Quickshell.Wayland` | screencasting, layers, the layer shell |
| `Quickshell.Widgets` | the widget set (bars, menus, sliders) |
| `Quickshell.DBusMenu` | exporting menus over DBus |
| `Quickshell.Hyprland` | the Hyprland-specific bits |
| `Quickshell.Services.*` | Greetd, Mpris, Notifications, Pam, Pipewire, SystemTray, UPower |

The notch uses `Quickshell` (paths and `execDetached`) and `Quickshell.Io`
(`Process`), and nothing else.

## Process and I/O

`Quickshell.Io` provides `Process` and the stdio types. The documentation
names **one** stdio type in the current build: **`StdioCollector`**
(<https://quickshell.org/docs/v0.1.0/types/Quickshell.Io/>).

There is **no `StdioDiscard`**. The notch used one, and it was not a type:
the service failed to load, and the *next* reload of the whole shell
failed with it, because a QML file that does not parse takes the config
down with it. `StdioCollector` with an empty body is the way to throw
output away.

## Singletons, and where they must be registered

A service in the shell is a `pragma Singleton` QML file under
`packages/shell/quickshell/services/`. **Every one of them must be listed
in `packages/shell/quickshell/qmldir`.** Miss that line and the shell
does not start, and the error names the *type* it could not find rather
than the line that caused it — the message is `Type AnimeService
unavailable`, which sends you looking for a QML file that is sitting
right there.

This is the notch's own experience, in the repository's history: the
service was added, the file was there, and the shell still would not
load until the `qmldir` gained a line.

## IPC handlers live in the config root

`IpcHandler` registers an IPC target. **Put it in the config root**
(`Commands.qml`), not inside a service singleton. A handler inside a
singleton does not register: the target does not exist, and
`qs ipc call` answers `Target not found.` with no hint that the handler
was written but never wired.

The notch's `Commands.qml` holds every target for this reason, and the
whole surface is written down in [ipc.md](ipc.md).

The IPC documentation is not a type page — it is not in the module
navigation above — which is itself a small sharp edge: the thing the
whole shell is driven through is documented somewhere other than the
types.

## Reloading

A QML file that changes is reloaded. What survives a reload is not
obvious from the documentation, and in this shell the singletons keep
their state, so a panel that was open stays open with the data it had.
When a change needs the whole config, `qs ipc call shell reload` asks
for it.

**The shell's own errors are not answers.** A QML error goes to the
shell's stderr. When the compositor started the shell there was nowhere
to read it, so the spawn now writes to a file:

```
spawn-at-startup "sh" "-c" "exec /usr/bin/qs -n >> ~/.local/state/notch/qs.log 2>&1"
```

That is what made the missing `StdioDiscard` findable at all.

## The install, which is not Quickshell's business but bit us

`./setup files` copies the packages into `$HOME` per their `install`
manifests. A directory that lands inside an existing directory is silent:
the shell ended up in `~/.config/quickshell/quickshell/` and refused to
start. `tests/setup.sh` now installs into a home of its own and asks
where everything landed.

## What the notch relies on

| thing | where it is used |
|---|---|
| `Quickshell.shellPath` | every service that runs a script |
| `Quickshell.execDetached` | launching things that outlive the call |
| `Process` + `StdioCollector` | the catalogue, the T3 status, the captures |
| `IpcHandler` in the config root | every IPC target (`Commands.qml`) |
| `qmldir` | the singleton registry |
| the reload | editing a QML file and saving it |

## Sharp edges, collected

1. **A missing `qmldir` line takes the whole shell down**, and the error
   points at the type, not the list.
2. **A QML file that does not parse takes the whole shell down.** There
   is no partial load.
3. **No `StdioDiscard`.** `StdioCollector` with an empty body does it.
4. **An `IpcHandler` in a singleton never registers.** The config root
   only.
5. **The docs are a version behind** (v0.1.0 against 0.3.2 here), and the
   site moved.
6. **Errors live in the shell's stderr**, which is nowhere unless the
   spawn redirects it.
7. **The IPC documentation is not in the type reference**, where you
   would look for it.

## What this does not cover

This was written with a nearly spent context, and the gaps are named
rather than hidden: the `Process` property list and the `Quickshell`
singleton's members were not read page by page; the reload semantics
are described from what this shell does, not from the documentation;
the Wayland, Widgets, DBusMenu, Hyprland and Services modules were
listed from the navigation and not read. The version gap above is the
reason to check the source before trusting any of it. A full pass over
`Process`, `Quickshell` and the reload behaviour is the work that would
finish this document.

## Sources

- <https://quickshell.org/docs/v0.1.0/types/Quickshell.Io/> — the
  `Process` and stdio types; `StdioCollector` is the only stdio type
  named
- <https://quickshell.org/docs/v0.1.0/types/Quickshell/> — the
  `Quickshell` singleton
- <https://quickshell.org/docs/v0.1.0/> — the documentation root, and
  the version it serves
- <https://github.com/quickshell-mirror/quickshell> — the source
- `qs --version` on this machine — 0.3.2
- the notch's own history, in the repository: the `StdioDiscard` failure
  and the missing `qmldir` line are both in this repo's commits, and
  `tests/setup.sh` is the check that came out of the third
