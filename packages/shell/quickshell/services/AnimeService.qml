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
    // The seasons of the series on show, and the one Ever picked.
    property var seasons: []
    property int season: 1
    // The titles that were watched, so the catalogue can offer them again.
    property var continueShelf: []
    // Remote work, from the boards that publish it without a key.
    property var jobs: []
    // Everything the catalogue shows: what was watched, then the shelves.
    readonly property var shelves: continueShelf.concat(rows)

    function load(): void {
        root.busy = true
        rowsProcess.running = false
        rowsProcess.running = true
        // The work, too: it is the other half of what the assistant is for.
        jobsProcess.running = false
        jobsProcess.running = true
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
    // What went wrong the last time a title was asked for, so the panel
    // can say it where the button was pressed.
    property string error: ""

    function watch(item: var): void {
        if (!item)
            return
        root.error = ""
        var command
        if (item.kind === "anime") {
            // The id goes along, so the title can be found again later.
            command = ["notch-watch", "anime", item.romaji || item.title,
                       "--media-id", String(item.id), "--kind", "anime"]
        } else {
            const kind = item.kind === "tv" ? "tv" : "movie"
            command = ["notch-watch", "film", kind, String(item.id),
                       item.title || "", String(item.year || "")]
            if (kind === "tv")
                command.push("--season", String(root.season), "--episode", String(root.episode))
            if (item.resume)
                command.push("--start", String(Math.floor(item.resume)))
        }
        // The watch is run here, not thrown away, so its answer can be
        // read: a title the source does not carry must not look like a
        // button that did nothing.
        watchProcess.command = command
        watchProcess.running = false
        watchProcess.running = true
    }

    // The work worth doing: the job boards, mixed.
    readonly property Process jobsProcess: Process {
        command: ["python3", Quickshell.shellPath("scripts/stream.py"),
                  "jobs", "--limit", "12"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.jobs = JSON.parse(text)
                } catch (error) {
                    root.jobs = []
                }
            }
        }
    }

    // Ask about a posting: the assistant gets the whole thing.
    function askAboutJob(job: var): void {
        if (!job)
            return
        const posting = "A posting:\n" + job.title +
            (job.company ? " at " + job.company : "") +
            (job.location ? " (" + job.location + ")" : "") +
            (job.salary ? " — " + job.salary : "") +
            "\n" + job.url +
            "\n\nWhat does this job want, and could I do it?"
        Quickshell.execDetached(["qs", "ipc", "call", "ask", "open"])
        root.askText = posting
    }

    property string askText: ""

    readonly property Process watchProcess: Process {
        stdout: StdioCollector {
            // The answer is not wanted; the failure is, and it is in stderr.
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const text = (text || "").trim().split("\n").filter(Boolean).pop() || ""
                if (root.watchProcess.exitCode !== 0)
                    root.error = text.replace(/^notch-watch:\s*/, "")
                else
                    root.error = ""
            }
        }
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
        root.seasons = []
        root.season = 1
        if (!item || item.kind !== "tv")
            return
        seasonsProcess.command = ["python3", Quickshell.shellPath("scripts/stream.py"),
                                  "seasons", String(item.id)]
        seasonsProcess.running = false
        seasonsProcess.running = true
        episodesProcess.command = ["python3", Quickshell.shellPath("scripts/stream.py"),
                                    "episodes", String(item.id), "--season", "1"]
        episodesProcess.running = false
        episodesProcess.running = true
    }

    // The episodes of the season Ever picked.
    function pickSeason(season: int): void {
        root.season = season
        root.episode = 1
        if (!root.hero)
            return
        episodesProcess.command = ["python3", Quickshell.shellPath("scripts/stream.py"),
                                    "episodes", String(root.hero.id), "--season", String(season)]
        episodesProcess.running = false
        episodesProcess.running = true
    }

    // A title that was watched can be picked up where it was left.
    function continueShelfItems(): var {
        const out = []
        for (const item of PlayingService.history) {
            if (!item || !item.mediaId)
                continue
            out.push({
                "kind": item.kind || "tv",
                "id": item.mediaId,
                "title": item.title || "—",
                "year": 0,
                "score": 0,
                "genres": [],
                "description": "",
                "cover": "",
                "banner": "",
                "resume": item.position || 0,
                "episode": item.episode || "",
                "season": item.season || "",
            })
        }
        return out
    }

    // A trailer for one title, from TMDB's videos, opened in the browser.
    function trailer(item: var): void {
        if (!item || item.kind === "anime")
            return
        Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/stream.py"),
                                "trailer", item.kind === "tv" ? "tv" : "movie",
                                String(item.id)])
    }

    // The shelf of what was watched follows the playing.
    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: root.continueShelf = root.continueShelfItems()
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

    readonly property Process seasonsProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.seasons = JSON.parse(text)
                } catch (error) {
                    root.seasons = []
                }
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
