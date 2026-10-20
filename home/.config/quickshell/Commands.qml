// ╭──────────────────────────────────────────────────────────────────────────╮
// │   C O M M A N D S                                                        │
// │   everything `impasto` and `qs ipc call` can reach                       │
// ╰──────────────────────────────────────────────────────────────────────────╯
//
// niri binds keys to `impasto open launcher` and friends, so these handlers
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

    readonly property var panels: ["launcher", "controls", "session", "keys", "t3",
        "bluetooth", "sound", "microphone", "clipboard", "emoji"]

    IpcHandler {
        target: "panel"


        function open(name: string): string {
            if (root.panels.indexOf(name) < 0)
                return root.fail(`not a panel: "${name}" (${root.panels.join(", ")})`)
            if (name === "clipboard" || name === "emoji")
                root.openLauncherOn(name)
            else
                root.island?.open(name)
            return root.ok({ panel: name })
        }

        // What a key does: open, or close when that panel is already up.
        function toggle(name: string): string {
            if (root.panels.indexOf(name) < 0)
                return root.fail(`not a panel: "${name}" (${root.panels.join(", ")})`)
            if (name === "clipboard" || name === "emoji")
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

    IpcHandler {
        target: "shell"

        function reload(): void {
            Quickshell.reload(false)
        }
    }
}
