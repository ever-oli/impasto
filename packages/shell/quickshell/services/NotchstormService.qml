// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T C H S T O R M   S E R V I C E                                   │
// │   the radar engine, and what it is showing                                 │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The radar engine (the Rust one from the omastorm project) runs under the
// notch's own runtime directory, and this asks it what it is showing: the
// station, the product, the age of the frame, and where the picture is.
Singleton {
    id: root

    property var facts: null
    property bool busy: false
    property string error: ""

    readonly property string texture: root.facts ? (root.facts.texture || "") : ""
    readonly property string site: root.facts ? (root.facts.site || "") : ""
    readonly property string product: root.facts ? (root.facts.product || "") : ""
    readonly property string status: root.facts ? (root.facts.status || "") : ""
    readonly property int age: root.facts ? (root.facts.ageSeconds || 0) : 0
    readonly property string scanTime: root.facts ? (root.facts.scanTime || "") : ""

    // How the frame reads: ok, stale, unavailable, loading, offline.
    readonly property string freshness: {
        if (status === "ok")
            return "live"
        if (status === "stale")
            return "stale"
        if (status === "loading")
            return "loading"
        if (status === "unavailable")
            return "silent"
        return status === "" ? "quiet" : "offline"
    }

    function refresh(): void {
        root.busy = true
        stateProcess.running = false
        stateProcess.running = true
    }

    function center(lat: real, lon: real): void {
        root.busy = true
        centerProcess.arguments = ["notchstorm", "center", String(lat), String(lon)]
        centerProcess.running = false
        centerProcess.running = true
    }

    readonly property Process stateProcess: Process {
        command: ["notchstorm", "state"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.facts = JSON.parse(text)
                    root.error = ""
                } catch (error) {
                    root.error = "the engine did not answer"
                }
                root.busy = false
            }
        }
    }

    readonly property Process centerProcess: Process {
        command: ["notchstorm", "center", "0", "0"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.facts = JSON.parse(text)
                } catch (error) {}
                root.busy = false
                refreshTimer.restart()
            }
        }
    }

    // The engine keeps sweeping; ask it now and then.
    Timer {
        id: refreshTimer
        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
