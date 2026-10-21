// ╭──────────────────────────────────────────────────────────────────────────╮
// │   T H E M E   S E R V I C E   (lean)                                     │
// │   follows ~/.local/state/notch/theme.json, written by `notch-theme`  │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

Singleton {
    id: root

    readonly property var themes: ["e-ink", "e-ink-dark", "red-ink", "red-ink-dark"]
    property string activeId: "e-ink"

    readonly property string statePath:
        `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/notch/theme.json`

    // The script writes the file and the shell repaints: one owner of the
    // palette, nothing to keep in sync.
    function setTheme(themeId: string): void {
        if (root.themes.indexOf(themeId) < 0) {
            console.warn("Unknown theme:", themeId)
            return
        }
        setter.command = [Quickshell.env("HOME") + "/.local/bin/notch-theme", "set", themeId]
        setter.running = true
    }

    readonly property Process setter: Process {}

    readonly property FileView state: FileView {
        path: root.statePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text())
                root.activeId = data.id ?? root.activeId
                Theme.activeId = root.activeId
                Theme.fontBase = data.fontSize ?? 11
                Theme.apply(data.shell, data.name ?? root.activeId)
            } catch (error) {
                console.warn("theme.json:", error)
            }
        }
    }
}
