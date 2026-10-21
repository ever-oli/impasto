// ╭──────────────────────────────────────────────────────────────────────────╮
// │   C L O U D   S E R V I C E                                              │
// │   cpu · memory · network rate · idle auto-stop countdown                 │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What matters on a cloud desktop with no sound or battery. Read from /proc
// every few seconds.
//
// The auto-stop is the CloudWatch alarm `omarchy-idle-stop`: it stops the
// instance once CPU has stayed under 10% for 2 h. It is not visible from
// inside the VM, so this mirrors it: a 5-minute CPU average at or over the
// threshold resets the clock. Before 5 minutes of samples, and right after a
// restart of the shell, it counts from that moment, so it errs long, never
// short.
Singleton {
    id: root

    readonly property int idleLimit: 2 * 3600       // seconds
    readonly property real idleThreshold: 10         // percent
    readonly property int windowSecs: 300

    property int cpu: 0
    property int mem: 0
    property real rxRate: 0                          // bytes/s
    property real txRate: 0
    property real lastBusy: Date.now() / 1000
    property real now: Date.now() / 1000

    readonly property int idleLeft: Math.max(0, Math.round(root.idleLimit - (root.now - root.lastBusy)))

    // "1h42" / "38m".
    readonly property string idleText: {
        const m = Math.floor(root.idleLeft / 60)
        return m >= 60 ? `${Math.floor(m / 60)}h${String(m % 60).padStart(2, "0")}` : `${m}m`
    }

    function rate(b: real): string {
        if (b >= 1048576) return `${(b / 1048576).toFixed(1)}M`
        if (b >= 1024) return `${Math.round(b / 1024)}K`
        return `${Math.round(b)}B`
    }
    readonly property string netText: `↓${root.rate(root.rxRate)} ↑${root.rate(root.txRate)}`

    property var prevCpu: null
    property var prevNet: null
    property var samples: []                         // [t, busy, total]

    readonly property Timer poll: Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!reader.running) reader.running = true
    }

    readonly property Process reader: Process {
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; cat /proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    function parse(text: string): void {
        const t = Date.now() / 1000
        const lines = text.split("\n")
        const c = lines[0].trim().split(/\s+/).slice(1).map(Number)
        const idle = c[3] + (c[4] || 0)
        const total = c.reduce((a, b) => a + b, 0)
        if (root.prevCpu) {
            const dt = total - root.prevCpu[1]
            if (dt > 0)
                root.cpu = Math.round(100 * (1 - (idle - root.prevCpu[0]) / dt))
        }
        root.prevCpu = [idle, total]

        // 5-minute average, as CloudWatch sees it.
        const s = root.samples.concat([[t, total - idle, total]]).filter(x => t - x[0] <= root.windowSecs + 5)
        root.samples = s
        if (s.length > 1 && t - s[0][0] >= root.windowSecs - 10) {
            const avg = 100 * (s[s.length - 1][1] - s[0][1]) / Math.max(1, s[s.length - 1][2] - s[0][2])
            if (avg >= root.idleThreshold)
                root.lastBusy = t
        }

        let memTotal = 0, memAvail = 0, rx = 0, tx = 0
        for (const line of lines) {
            const m = line.match(/^(MemTotal|MemAvailable):\s+(\d+)/)
            if (m) {
                if (m[1] === "MemTotal") memTotal = Number(m[2]); else memAvail = Number(m[2])
                continue
            }
            const n = line.match(/^\s*([^:\s]+):\s*(.*)$/)
            if (n && n[1] !== "lo" && !n[1].startsWith("Inter") && n[1] !== "face") {
                const f = n[2].trim().split(/\s+/).map(Number)
                if (n[1] === NetworkService.interfaceName || NetworkService.interfaceName === "") {
                    rx += f[0]; tx += f[8]
                }
            }
        }
        if (memTotal > 0)
            root.mem = Math.round(100 * (1 - memAvail / memTotal))
        if (root.prevNet && t > root.prevNet[2]) {
            root.rxRate = Math.max(0, (rx - root.prevNet[0]) / (t - root.prevNet[2]))
            root.txRate = Math.max(0, (tx - root.prevNet[1]) / (t - root.prevNet[2]))
        }
        root.prevNet = [rx, tx, t]
        root.now = t
    }
}
