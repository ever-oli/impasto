// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O M M A N D S                                                        │
// │   the shell over ipc · what the impasto command calls                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// │   EVER LEAN: the note/task/machine/capture/layout/game/nightlight        │
// │   targets went with their panels; the rest is untouched.                 │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

import "./services"

// One IPC target per noun, reached as `qs ipc call <target> <verb> <args>`
// and, more kindly, as `impasto <target> <verb> <args>`. Every answer is a
// line of JSON: `{"ok": true, ...}` or `{"error": "..."}`, so a script or an
// assistant can read what happened and go on. Arguments arrive as strings;
// an optional one arrives empty.
Scope {
    id: root

    // The live bar's island, for the panels.
    property var island: null

    function ok(extra: var): string {
        return JSON.stringify(Object.assign({ ok: true }, extra ?? ({})))
    }

    function fail(message: string): string {
        return JSON.stringify({ error: message })
    }

    // "on", "off" or "toggle" against the current state; null if none.
    function switched(word: string, now: bool): var {
        const said = (word || "toggle").toLowerCase()
        if (["on", "true", "yes", "1"].indexOf(said) >= 0)
            return true
        if (["off", "false", "no", "0"].indexOf(said) >= 0)
            return false
        return said === "toggle" ? !now : null
    }

    // ── STATUS ──────────────────────────────────────────────────────────────

    IpcHandler {
        target: "status"

        function get(): string {
            return root.ok({
                timer: TimerService.running
                    ? { label: TimerService.label, left: TimerService.display, paused: TimerService.paused }
                    : null,
                media: MediaService.available
                    ? { title: MediaService.title, artist: MediaService.artist, playing: MediaService.playing }
                    : null,
                palette: ThemeService.activeId,
                wallpaper: WallpaperService.chosen,
                focus: SettingsService.doNotDisturb,
                volume: AudioService.volume,
                muted: AudioService.muted,
                brightness: BrightnessService.percent
            })
        }
    }

    // ── TIMER ───────────────────────────────────────────────────────────────

    IpcHandler {
        target: "timer"

        function start(duration: string, label: string): string {
            const milliseconds = TimerService.parse(duration)
            if (!(milliseconds > 0))
                return root.fail(`not a duration: "${duration}" (try 25m, 1h30m, 90s or 10:00)`)
            TimerService.start(milliseconds, label)
            return root.ok({ left: TimerService.display, label: TimerService.label })
        }

        function pause(): string {
            if (!TimerService.running)
                return root.fail("no timer is running")
            TimerService.pause()
            return root.ok({ left: TimerService.display })
        }

        function resume(): string {
            if (!TimerService.running)
                return root.fail("no timer is running")
            TimerService.resume()
            return root.ok({ left: TimerService.display })
        }

        function cancel(): string {
            if (!TimerService.running)
                return root.fail("no timer is running")
            TimerService.cancel()
            return root.ok()
        }

        function get(): string {
            return root.ok({ running: TimerService.running, paused: TimerService.paused,
                             label: TimerService.label, left: TimerService.display })
        }
    }

    // ── PANELS ──────────────────────────────────────────────────────────────

    IpcHandler {
        target: "panel"

        readonly property var names: ["launcher", "controls", "overview", "appearance", "palette",
            "stats", "session",
            "wifi", "bluetooth", "sound", "microphone", "brightness"]

        function open(name: string): string {
            if (names.indexOf(name) < 0)
                return root.fail(`not a panel: "${name}" (${names.join(", ")})`)
            root.island?.open(name)
            return root.ok({ panel: name })
        }

        function close(): string {
            root.island?.close()
            return root.ok()
        }

        function list(): string {
            return root.ok({ panels: names })
        }
    }

    // ── MUSIC ───────────────────────────────────────────────────────────────

    IpcHandler {
        target: "media"

        function get(): string {
            return root.ok({ media: MediaService.available
                ? { title: MediaService.title, artist: MediaService.artist,
                    player: MediaService.identity, playing: MediaService.playing }
                : null })
        }

        function play(): string {
            if (!MediaService.available)
                return root.fail("nothing to play")
            if (!MediaService.playing)
                MediaService.toggle()
            return root.ok({ playing: true })
        }

        function pause(): string {
            if (!MediaService.available)
                return root.fail("nothing is playing")
            if (MediaService.playing)
                MediaService.toggle()
            return root.ok({ playing: false })
        }

        function toggle(): string {
            if (!MediaService.available)
                return root.fail("nothing to play")
            const playing = !MediaService.playing
            MediaService.toggle()
            return root.ok({ playing: playing })
        }

        function next(): string {
            if (!MediaService.canNext)
                return root.fail("no next track")
            MediaService.next()
            return root.ok()
        }

        function prev(): string {
            if (!MediaService.canPrevious)
                return root.fail("no previous track")
            MediaService.previous()
            return root.ok()
        }
    }

    IpcHandler {
        target: "focus"

        function set(word: string): string {
            const on = root.switched(word, SettingsService.doNotDisturb)
            if (on === null)
                return root.fail("on, off or toggle")
            if (on !== SettingsService.doNotDisturb)
                NotificationService.toggleDoNotDisturb()
            return root.ok({ focus: on })
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            SettingsService.set("barHidden", !SettingsService.barHidden)
        }
    }

    // ── SOUND AND LIGHT ─────────────────────────────────────────────────────

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
        target: "brightness"

        function set(percent: string): string {
            const value = parseInt(percent)
            if (isNaN(value) || value < 0 || value > 100)
                return root.fail("a brightness from 0 to 100")
            BrightnessService.setPercent(value)
            return root.ok({ brightness: value })
        }

        function get(): string {
            return root.ok({ brightness: BrightnessService.percent })
        }
    }

    // ── LOOKS ───────────────────────────────────────────────────────────────

    IpcHandler {
        target: "theme"

        function list(): string {
            return root.ok({ current: ThemeService.activeId,
                             palettes: ThemeService.availableThemes.map(entry => ({ id: entry.id, name: entry.name })) })
        }

        function set(id: string): string {
            if (!ThemeService.availableThemes.some(entry => entry.id === id))
                return root.fail(`not a palette: "${id}" (impasto theme list)`)
            ThemeService.setTheme(id)
            return root.ok({ palette: id })
        }
    }

    IpcHandler {
        target: "wallpaper"

        // Kept as it was: Thunar's "Set as Wallpaper" calls it.
        function set(path: string): string {
            if (!path)
                return "usage: qs ipc call wallpaper set <path>"
            WallpaperService.apply(path)
            return path
        }

        function list(): string {
            return root.ok({ current: WallpaperService.chosen,
                             wallpapers: WallpaperService.wallpapers })
        }

        function random(): string {
            const all = WallpaperService.wallpapers.filter(path => path !== WallpaperService.chosen)
            if (all.length === 0)
                return root.fail("no other wallpaper")
            const path = all[Math.floor(Math.random() * all.length)]
            WallpaperService.apply(path)
            return root.ok({ wallpaper: path })
        }
    }

    // ── THE ISLAND SAYS SOMETHING ───────────────────────────────────────────

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
