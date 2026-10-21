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
    // The episodes of the series on show, and the one Ever picked.
    property var episodes: []
    property int episode: 1

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
        const command = ["notch-watch", "film", kind, String(item.id),
                         item.title || "", String(item.year || "")]
        if (kind === "tv")
            command.push("--season", "1", "--episode", String(root.episode))
        Quickshell.execDetached(command)
    }

    // The title on show. When it changes, its episodes change with it.
    function setHero(item: var): void {
        root.hero = item
        root.loadEpisodes(item)
    }

    // The episodes of the series on show, so Ever can pick one.
    function loadEpisodes(item: var): void {
        root.episodes = []
        root.episode = 1
        if (!item || item.kind !== "tv")
            return
        episodesProcess.command = ["python3", Quickshell.shellPath("scripts/stream.py"),
                                    "episodes", String(item.id), "--season", "1"]
        episodesProcess.running = false
        episodesProcess.running = true
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
                    root.setHero(found.hero)
                    root.rows = found.rows
                    root.films = found.token
                } catch (error) {}
                root.busy = false
            }
        }
    }

    readonly property Process episodesProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.episodes = JSON.parse(text)
                } catch (error) {
                    root.episodes = []
                }
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
