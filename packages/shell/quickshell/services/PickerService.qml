// ╭──────────────────────────────────────────────────────────────────────────╮
// │   P I C K E R   S E R V I C E                                            │
// │   what the theme / wallpaper carousel lists, previews and keeps          │
// ╰──────────────────────────────────────────────────────────────────────────╯
//
// Arrows preview live (debounced); Enter keeps; anything else (Esc, a click
// away) puts back what was there when the picker opened.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string kind: "theme"          // theme · wallpaper
    property var items: []                 // { label, value, image }
    property int index: 0
    property string filter: ""
    property bool kept: false
    property string startTheme: ""
    property string startWallpaper: ""

    readonly property string themes: `${Quickshell.env("HOME")}/.local/share/notch/themes`
    readonly property var matching: root.items.map((it, i) => i)
        .filter(i => root.filter === "" || root.items[i].label.toLowerCase().includes(root.filter.toLowerCase()))

    function open(kind: string): void {
        root.kind = kind
        root.kept = false
        root.filter = ""
        root.items = []
        lister.running = false
        lister.running = true
    }

    function step(delta: int): void {
        const m = root.matching
        if (!m.length)
            return
        const at = Math.max(0, m.indexOf(root.index))
        root.index = m[(at + delta + m.length) % m.length]
        previewTimer.restart()
    }

    function refilter(text: string): void {
        root.filter = text
        if (root.matching.length && root.matching.indexOf(root.index) < 0) {
            root.index = root.matching[0]
            previewTimer.restart()
        }
    }

    function set(theme: string, wallpaper: string): void {
        Quickshell.execDetached(["sh", "-c", 'PATH="$HOME/.local/bin:$PATH" notch-theme set "$1" ${2:+"$2"}', "-",
                                 theme, wallpaper])
    }

    function apply(): void {
        const it = root.items[root.index]
        if (!it)
            return
        if (root.kind === "theme")
            root.set(it.value, "")
        else
            root.set(root.startTheme, it.value)
    }

    function keep(): void {
        previewTimer.stop()
        root.apply()
        root.kept = true
    }

    function revert(): void {
        previewTimer.stop()
        if (!root.kept && root.startTheme !== "")
            root.set(root.startTheme, root.startWallpaper)
    }

    readonly property Timer previewTimer: Timer { interval: 350; onTriggered: root.apply() }

    // One line per item: label<TAB>value<TAB>image, then a last line with the
    // current theme and wallpaper.
    readonly property Process lister: Process {
        command: ["python3", "-c", `
import json, os, sys
home = os.path.expanduser("~")
base = f"{home}/.local/share/notch/themes"
cur = json.load(open(f"{home}/.local/state/notch/theme.json"))
if sys.argv[1] == "theme":
    for t in sorted(os.listdir(base)):
        if os.path.isfile(f"{base}/{t}/colors.toml"):
            print(f"{t.replace('-', ' ').title()}\\t{t}\\t{base}/{t}/preview.png")
else:
    folder = f"{base}/{cur['id']}/backgrounds"
    for f in sorted(os.listdir(folder)):
        print(f"{os.path.splitext(f)[0].replace('-', ' ').title()}\\t{folder}/{f}\\t{folder}/{f}")
print(f"@\\t{cur['id']}\\t{cur.get('wallpaper', '')}")
`, root.kind]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").filter(l => l !== "").map(l => l.split("\t"))
                const now = rows.pop() ?? ["@", "", ""]
                root.startTheme = now[1]
                root.startWallpaper = now[2]
                root.items = rows.map(r => ({ label: r[0], value: r[1], image: `file://${r[2]}` }))
                const at = root.items.findIndex(it => it.value === (root.kind === "theme" ? now[1] : now[2]))
                root.index = Math.max(0, at)
            }
        }
    }
}
