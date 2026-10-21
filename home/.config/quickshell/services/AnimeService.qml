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
    // A TMDB token turns the film and series shelves on; without one the
    // panel is anime only.
    property bool films: false

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

    // Play one title. The picture goes in the island terminal, where
    // mpv's truecolor output draws it: no window, no GPU. Anime comes
    // through hianime, a film or a series through the box, whose
    // address those sources accept.
    function watch(item: var): void {
        if (!item)
            return
        if (item.kind === "anime") {
            Quickshell.execDetached(["notch-watch", "anime", item.romaji || item.title])
            return
        }
        const kind = item.kind === "tv" ? "tv" : "movie"
        Quickshell.execDetached(["notch-watch", "film", kind, String(item.id),
                                item.title || "", String(item.year || "")])
    }

    // A trailer for one title, from TMDB's videos, opened in the browser.
    function trailer(item: var): void {
        if (!item || item.kind === "anime")
            return
        Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/stream.py"),
                                "trailer", item.kind === "tv" ? "tv" : "movie",
                                String(item.id)])
    }

    readonly property Process rowsProcess: Process {
        command: ["python3", Quickshell.shellPath("scripts/stream.py"), "rows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const found = JSON.parse(text)
                    root.hero = found.hero
                    root.rows = found.rows
                    root.films = found.token
                } catch (error) {}
                root.busy = false
            }
        }
    }

    readonly property Process searchProcess: Process {
        command: ["python3", Quickshell.shellPath("scripts/stream.py"), "search", root.query]
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
