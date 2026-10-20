pragma Singleton

// ┌──────────────────────────────────────────────────────────────────────────┐
// │ FinderService — the palette's lookups that need a program behind them   │
// │   qalc for the calculator, fd for `/` file search, and the snippets and │
// │   quicklinks in ~/.config/impasto/snippets.toml. Inspired by vicinae's  │
// │   root search; our own code.                                            │
// └──────────────────────────────────────────────────────────────────────────┘

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    // ── CALCULATOR ──────────────────────────────────────────────────────────
    // Anything with a digit and something to do with it goes to qalc, which
    // knows units and currencies ("5 ft to cm", "20 usd in eur", "2^10").
    property string calcQuery: ""
    property string calcResult: ""
    readonly property var mathy: /\d/
    readonly property var verb: /[-+*/^%×÷()!=]|\b(to|in|as)\b|\d\s*[a-zA-Z$€£°]/

    function calcFor(text: string): string {
        return text === root.calcQuery ? root.calcResult : ""
    }

    function calculate(text: string): void {
        if (text === root.calcQuery)
            return
        root.calcQuery = text
        root.calcResult = ""
        if (text.length < 2 || !root.mathy.test(text) || !root.verb.test(text))
            return
        qalc.pending = text
        calcDelay.restart()
    }

    Timer {
        id: calcDelay
        interval: 90
        onTriggered: {
            qalc.running = false
            qalc.asked = qalc.pending
            qalc.command = ["timeout", "2", "qalc", "-t", "--", qalc.asked]
            qalc.running = true
        }
    }

    Process {
        id: qalc
        property string pending: ""
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim().split("\n").pop() ?? ""
                const plain = qalc.asked.replace(/\s+/g, "")
                if (qalc.asked !== root.calcQuery || out === "" || /error|warning/i.test(text)
                        || out.replace(/\s+/g, "") === plain)
                    return
                root.calcResult = out
            }
        }
    }

    // ── FILES ───────────────────────────────────────────────────────────────
    // Fuzzy-ish: "inv pdf" matches anything with "inv" then "pdf" in its path.
    property string fileQuery: ""
    property var files: []

    function findFiles(text: string): void {
        if (text === root.fileQuery)
            return
        root.fileQuery = text
        root.files = []
        if (text.length < 2)
            return
        fileDelay.restart()
    }

    Timer {
        id: fileDelay
        interval: 140
        onTriggered: {
            const pattern = root.fileQuery.trim().split(/\s+/)
                .map(w => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join(".*")
            fd.running = false
            fd.asked = root.fileQuery
            fd.command = ["timeout", "3", "fd", "--hidden", "--ignore-case", "--full-path", "--max-results", "40",
                "--exclude", ".cache", "--exclude", "node_modules", "--exclude", ".git",
                "--", pattern, root.home]
            fd.running = true
        }
    }

    Process {
        id: fd
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (fd.asked !== root.fileQuery)
                    return
                root.files = text.split("\n").filter(l => l !== "")
                    .sort((a, b) => a.length - b.length).slice(0, 30)
            }
        }
    }

    // ── SNIPPETS AND QUICKLINKS ─────────────────────────────────────────────
    property var snippets: []
    property var quicklinks: []

    FileView {
        path: `${root.home}/.config/impasto/snippets.toml`
        watchChanges: true
        onFileChanged: reader.running = true
        onLoaded: reader.running = true
    }

    Process {
        id: reader
        command: ["python3", "-c",
            "import json,os,tomllib;d=tomllib.load(open(os.path.expanduser('~/.config/impasto/snippets.toml'),'rb'));"
            + "print(json.dumps({'s':d.get('snippet',[]),'q':d.get('quicklink',[])}))"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    root.snippets = data.s
                    root.quicklinks = data.q
                } catch (error) {}
            }
        }
    }

    // "g arch linux" → the Google quicklink with "arch linux".
    function quicklinkFor(text: string): var {
        const match = /^(\S+)\s+(.+)$/.exec(text)
        if (!match)
            return null
        const link = root.quicklinks.find(l => l.key === match[1])
        return link ? { link: link, term: match[2] } : null
    }

    // Letters of `term` in order inside `hay`; lower is better, -1 is no match.
    function fuzzy(hay: string, term: string): int {
        hay = (hay ?? "").toLowerCase()
        if (term === "")
            return 0
        const at = hay.indexOf(term)
        if (at >= 0)
            return at === 0 ? 0 : 1
        let i = 0, gaps = 0, last = -1
        for (const ch of term) {
            const found = hay.indexOf(ch, i)
            if (found < 0)
                return -1
            if (last >= 0 && found > last + 1)
                gaps++
            last = found
            i = found + 1
        }
        return 2 + gaps
    }

    // ── ACTIONS ─────────────────────────────────────────────────────────────
    function paste(text: string): void {
        // After the island lets go of the keyboard, into the focused window.
        Quickshell.execDetached(["sh", "-c", "sleep 0.35; wtype -- \"$1\"", "_", text])
    }

    function openLink(link: var, term: string): void {
        Quickshell.execDetached(["helium-browser",
            link.url.replace("{q}", encodeURIComponent(term))])
    }

    function open(path: string): void {
        Quickshell.execDetached(["xdg-open", path])
    }

    function reveal(path: string): void {
        Quickshell.execDetached(["sh", "-c", "d=\"$1\"; [ -d \"$d\" ] || d=$(dirname \"$d\"); exec ghostty --working-directory=\"$d\"", "_", path])
    }
}
