// ╭──────────────────────────────────────────────────────────────────────────╮
// │   U S A G E   S E R V I C E                                              │
// │   OpenRouter credit left and spend today, every 10 minutes               │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Polls scripts/openrouter.py, which reads Pi's key at run time. The key never
// reaches QML. Warns once (notification) when credit drops under `low`.
// Idea from k4ditano/k4 (MIT).
Singleton {
    id: root

    property bool ok: false
    property string error: ""
    property real remaining: -1
    property real credits: 0
    property real today: 0
    property real month: 0
    readonly property real low: 1.0
    readonly property bool isLow: root.ok && root.remaining >= 0 && root.remaining < root.low
    property bool warned: false

    function money(v: real): string { return v < 0 ? "?" : "$" + v.toFixed(2) }
    readonly property string text: root.ok ? root.money(root.remaining) : "—"

    function refresh(): void { probe.running = true }

    readonly property Process probe: Process {
        command: [Quickshell.shellPath("scripts/openrouter.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = null
                try { d = JSON.parse(text) } catch (e) { d = null }
                if (!d) return
                root.ok = !!d.ok
                root.error = d.error ?? ""
                if (!d.ok) return
                root.remaining = d.remaining ?? -1
                root.credits = d.credits ?? 0
                root.today = d.today ?? 0
                root.month = d.month ?? 0
                if (root.isLow && !root.warned) {
                    root.warned = true
                    Quickshell.execDetached(["notify-send", "-a", "Notch", "OpenRouter credit low",
                        `${root.money(root.remaining)} left · ${root.money(root.today)} spent today`])
                }
                if (!root.isLow)
                    root.warned = false
            }
        }
    }
    readonly property Timer poll: Timer {
        interval: 10 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
