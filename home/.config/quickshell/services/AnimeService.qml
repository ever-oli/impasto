// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A N I M E   S E R V I C E                                              │
// │   the catalogue behind the panel                                          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the panel shows: a hero and a shelf per row, from AniList (no key).
// The watching is hianime's, through ani-cli in the island terminal.
Singleton {
    id: root

    property var hero: null
    property var rows: []
    property string query: ""
    property bool busy: false

    function load(): void {
        root.busy = true
        rowsProcess.running = false
        rowsProcess.running = true
    }

    function search(text: string): void {
        root.query = text
        if (text.trim() === "") {
            root.load()
            return
        }
        root.busy = true
        searchProcess.running = false
        searchProcess.running = true
    }

    function watch(title: string): void {
        if (!title)
            return
        Quickshell.execDetached(["notch-anime", "watch", title])
    }

    readonly property Process rowsProcess: Process {
        command: ["python3", Quickshell.shellPath("scripts/anime.py"), "rows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const found = JSON.parse(text)
                    root.hero = found.hero
                    root.rows = found.rows
                } catch (error) {}
                root.busy = false
            }
        }
    }

    readonly property Process searchProcess: Process {
        command: ["python3", Quickshell.shellPath("scripts/anime.py"), "search", root.query]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const found = JSON.parse(text)
                    root.rows = found.items.length ? [{ title: "Results", items: found.items }] : []
                } catch (error) {}
                root.busy = false
            }
        }
    }
}
