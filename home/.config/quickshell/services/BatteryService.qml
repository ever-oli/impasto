// ╭──────────────────────────────────────────────────────────────────────────╮
// │   B A T T E R Y   S E R V I C E                                          │
// │   the machine's power cells, read from sysfs                             │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The battery, read from sysfs once a minute. A machine with no cells (the
// cloud desktop, a tower) reports `has === false`, and then the bar chip and
// its detail are not drawn — nothing else needs to care. The first cell wins:
// laptops with two share their charge nearly evenly, and /sys has no
// aggregate.
Singleton {
    id: root

    property bool has: false
    property int percent: 0                         // 0..100 of the first cell
    property bool charging: false                   // plugged in or holding at full
    property bool bad: false                        // discharging low — the chip warns

    readonly property string glyph: {
        if (!root.has)
            return ""
        if (root.charging)
            return "󰂄"
        const icons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂂", "󰂂", "󰁹"]
        return icons[Math.min(9, Math.floor(root.percent / 10))]
    }

    // Poll each minute: sysfs is cheap and power is slow.
    readonly property Timer poll: Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!reader.running) reader.running = true
    }

    readonly property Process reader: Process {
        command: ["sh", "-c", "for d in /sys/class/power_supply/BAT*; do "
                                + "[ -r \"$d/capacity\" ] || continue; "
                                + "echo %=$(cat \"$d/capacity\") s=$(cat \"$d/status\"); done"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    function parse(text: string): void {
        let pct = -1, state = ""
        for (const line of text.split("\n")) {
            const m = line.trim().match(/^%=(\d+) s=([A-Za-z ]+)$/)
            if (m) {
                pct = Math.max(0, Math.min(100, Math.round(Number(m[1]))))
                state = m[2]
                break
            }
        }
        root.has = pct >= 0
        if (!root.has)
            return
        root.percent = pct
        root.charging = state !== "Discharging"
        root.bad = !root.charging && pct <= 15
    }
}
