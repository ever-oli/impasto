// ╭──────────────────────────────────────────────────────────────────────────╮
// │   C O M M A N D S                                                        │
// │   everything `notch` and `qs ipc call` can reach                       │
// ╰──────────────────────────────────────────────────────────────────────────╯
//
// niri binds keys to `notch open launcher` and friends, so these handlers
// are the shell's only shortcuts. Each answers JSON.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

import "./services"

Scope {
    id: root

    property var island: null

    function ok(extra: var): string {
        return JSON.stringify(Object.assign({ ok: true }, extra ?? ({})))
    }

    function fail(message: string): string {
        return JSON.stringify({ error: message })
    }

    function switched(word: string, now: bool): var {
        const said = (word || "toggle").toLowerCase()
        if (["on", "true", "yes", "1"].indexOf(said) >= 0)
            return true
        if (["off", "false", "no", "0"].indexOf(said) >= 0)
            return false
        return said === "toggle" ? !now : null
    }

    // The handoff. The notch has no brain of its own: what it knows goes
    // on the clipboard, and the agent in front of it takes it from there.
    function hand(brief: string): string {
        Quickshell.execDetached(["wl-copy", "--", brief])
        T3Service.open()
        return root.ok({ handed: true })
    }

    // The clipboard and the emoji are launcher modes: asked for again on the
    // same mode it closes.
    function openLauncherOn(mode: string): void {
        const sigil = SettingsService.launcherPrefix(mode)
        if (root.island?.state.openPanel === "launcher" && LauncherService.query.startsWith(sigil)) {
            root.island?.close()
            return
        }
        LauncherService.query = sigil
        root.island?.open("launcher")
    }

    // Panels that are really the launcher opened on a sigil.
    readonly property var launcherModes: ["clipboard", "emoji", "windows", "files"]
    readonly property var panels: ["windows", "files", "launcher", "controls", "session", "keys", "t3",
        "bluetooth", "sound", "microphone", "clipboard", "emoji", "anime", "notchstorm"]

    // Bar and island modules, each loaded on its own (ModuleService).
    IpcHandler {
        target: "modules"

        function list(): string {
            return root.ok({ modules: ModuleService.catalogue.map(m => m.id), failed: Object.keys(ModuleService.failed) })
        }
        function failed(): string {
            return root.ok({ failed: ModuleService.failed })
        }
        function reload(name: string): string {
            if (!ModuleService.catalogue.some(m => m.id === name))
                return root.fail(`not a module: "${name}"`)
            ModuleService.reload(name)
            return root.ok({ reloaded: name })
        }
    }

    IpcHandler {
        target: "panel"


        function open(name: string): string {
            if (root.panels.indexOf(name) < 0)
                return root.fail(`not a panel: "${name}" (${root.panels.join(", ")})`)
            if (root.launcherModes.indexOf(name) >= 0)
                root.openLauncherOn(name)
            else
                root.island?.open(name)
            return root.ok({ panel: name })
        }

        // What a key does: open, or close when that panel is already up.
        function toggle(name: string): string {
            if (root.panels.indexOf(name) < 0)
                return root.fail(`not a panel: "${name}" (${root.panels.join(", ")})`)
            if (root.launcherModes.indexOf(name) >= 0)
                root.openLauncherOn(name)
            else
                root.island?.toggle(name)
            return root.ok({ panel: name })
        }

        function close(): string {
            root.island?.close()
            return root.ok()
        }

        function list(): string {
            return root.ok({ panels: root.panels })
        }
    }

    IpcHandler {
        target: "capture"

        function open(shape: string): string {
            if (!shape) {
                CaptureService.open("", "", "", 0)
                return root.ok()
            }
            if (CaptureService.shapes.indexOf(shape) < 0)
                return root.fail(`not a shape: "${shape}" (${CaptureService.shapes.join(", ")})`)
            CaptureService.open(shape, "photo", "file", CaptureService.settle)
            return root.ok({ shape: shape })
        }

        function text(): string {
            CaptureService.open("region", "photo", "text", CaptureService.settle)
            return root.ok()
        }

        function record(): string {
            root.island?.close()
            RecorderService.toggle()
            return root.ok({ recording: !RecorderService.recording })
        }
    }

    IpcHandler {
        target: "focus"

        function set(word: string): string {
            const on = root.switched(word, NotificationService.doNotDisturb)
            if (on === null)
                return root.fail("on, off or toggle")
            if (on !== NotificationService.doNotDisturb)
                NotificationService.toggleDoNotDisturb()
            return root.ok({ focus: on })
        }
    }

    IpcHandler {
        target: "volume"

        function set(percent: string): string {
            const value = parseInt(percent)
            if (isNaN(value) || value < 0 || value > 100)
                return root.fail("a volume from 0 to 100")
            AudioService.setVolume(value)
            return root.ok({ volume: value })
        }

        function mute(word: string): string {
            const on = root.switched(word, AudioService.muted)
            if (on === null)
                return root.fail("on, off or toggle")
            if (on !== AudioService.muted)
                AudioService.toggleMute()
            return root.ok({ muted: on })
        }

        function get(): string {
            return root.ok({ volume: AudioService.volume, muted: AudioService.muted })
        }
    }

    IpcHandler {
        target: "t3"

        function get(): string {
            return root.ok({ service: T3Service.service, installed: T3Service.installed,
                             latest: T3Service.latest, update: T3Service.updateAvailable })
        }

        function refresh(): string {
            T3Service.refresh(true)
            return root.ok()
        }

        function update(): string {
            T3Service.update()
            return root.ok({ updating: true })
        }

        function open(): string {
            T3Service.open()
            return root.ok()
        }
    }

    IpcHandler {
        target: "theme"

        function set(id: string): string {
            if (ThemeService.themes.indexOf(id) < 0)
                return root.fail(`not a theme: "${id}" (${ThemeService.themes.join(", ")})`)
            ThemeService.setTheme(id)
            return root.ok({ theme: id })
        }

        function get(): string {
            return root.ok({ theme: ThemeService.activeId, themes: ThemeService.themes })
        }
    }

    IpcHandler {
        target: "osd"

        // Not `show`: `qs ipc show` is a command of its own.
        function say(text: string, icon: string): string {
            if (!text)
                return root.fail("say something")
            OsdService.requested(icon || "󰍡", text, -1)
            return root.ok()
        }
    }

    // What the work is right now, for anyone who asks.
    IpcHandler {
        target: "work"

        function get(): string {
            return JSON.stringify({ jobs: AnimeService.jobs.length,
                                   first: AnimeService.jobs[0] || null })
        }

        // The platforms: what they are, and what they want.
        function platforms(): string {
            return JSON.stringify(AnimeService.platforms)
        }

        // One of them, by name: `qs ipc call work platform Outlier`.
        function platform(name: string): string {
            const wanted = (name || "").toLowerCase()
            const found = AnimeService.platforms.find(
                (one) => one.name.toLowerCase() === wanted)
            if (!found)
                return root.fail(`no platform: "${name}"`)
            return JSON.stringify(found)
        }

        // Hand a piece of the work over: the posting or the platform, on
        // the clipboard, with T3 in front. The notch does not think about
        // it — it says what it knows and lets the agent on the other side
        // do the thinking.
        function hand(kind: string, index: string): string {
            const what = kind === "platform" ? AnimeService.platforms
                                             : AnimeService.jobs
            const one = what[parseInt(index)]
            if (!one)
                return root.fail(`no ${kind} at ${index}`)
            const brief = kind === "platform"
                ? "an ai training platform:\n" + JSON.stringify(one, null, 1) +
                  "\n\nwhat does it want before I can sign up, and what am I missing?"
                : "a remote job posting:\n" + JSON.stringify(one, null, 1) +
                  "\n\nwhat does it want, how well do I fit, and what would you write for me?"
            return root.hand(brief)
        }
    }

    // What the notch knows, for whoever is asking. No model on this side
    // of it: the notch is a device — a catalogue, a screen, a set of
    // postings — and the agent in front of it is the one that thinks.
    IpcHandler {
        target: "context"

        function get(): string {
            const hero = AnimeService.hero
            return JSON.stringify({
                panel: root.island?.state.openPanel || "",
                hero: hero ? { title: hero.title || "", year: hero.year || "" } : null,
                work: AnimeService.jobs.slice(0, 5),
                platforms: AnimeService.platforms.map((one) => ({ name: one.name, rate: one.rate })),
                profile: "~/.config/notch/profile.md",
                lessons: "~/.config/notch/lessons.md"
            })
        }

        // The whole context, handed over: on the clipboard and in front.
        function hand(): string {
            return root.hand("the notch right now:\n" + get() +
                             "\n\nwhat should I do about this?")
        }
    }

    // `notch picker theme|wallpaper`: the carousel in the notch.
    IpcHandler {
        target: "picker"

        function open(kind: string): string {
            PickerService.open(kind === "wallpaper" ? "wallpaper" : "theme")
            root.island?.open("picker")
            return root.ok({ kind: PickerService.kind })
        }

        // Scripted arrows and Enter, for testing without a keyboard.
        function step(delta: int): string {
            PickerService.step(delta)
            return root.ok({ index: PickerService.index })
        }

        function keep(): string {
            PickerService.keep()
            root.island?.close()
            return root.ok()
        }
    }

    // `notch palette Style/Theme` opens the palette at that folder.
    IpcHandler {
        target: "palette"

        function open(path: string): string {
            MenuService.reset()
            let nodes = MenuService.tree
            for (const name of (path || "").split("/").filter(n => n !== "")) {
                const node = nodes.find(n => n.name.toLowerCase() === name.toLowerCase())
                if (!node)
                    return root.fail(`no folder "${name}"`)
                MenuService.push(node)
                nodes = node.items ?? []
            }
            LauncherService.query = ""
            root.island?.open("launcher")
            return root.ok({ path: path })
        }

        // Open at the root with `text` typed, e.g. `palette search "5 ft to cm"`.
        function search(text: string): string {
            MenuService.reset()
            LauncherService.actionTarget = null
            LauncherService.aliasTarget = null
            LauncherService.query = text
            root.island?.open("launcher")
            return root.ok({ query: text })
        }

        // Ctrl+K on row `index`, and picking a row, without a keyboard.
        function actions(index: int): string {
            const e = LauncherService.results[index]
            if (!e || e.kind === "act") return root.fail("no such row")
            LauncherService.actionTarget = e
            return root.ok({ target: e.name })
        }
        // Text into the field as it stands (keeps an alias prompt open).
        function type(text: string): string {
            LauncherService.query = text
            return root.ok({ query: text })
        }
        function pick(index: int): string {
            LauncherService.pickRequested(index)
            return root.ok()
        }

        // The rows the palette shows right now, for tests.
        function rows(): string {
            return root.ok({ rows: LauncherService.results.slice(0, 8).map(r => `${r.kind}: ${r.name} | ${r.subtitle ?? ""}`) })
        }
    }

    IpcHandler {
        target: "shell"

        function reload(): void {
            Quickshell.reload(false)
        }
    }
}
