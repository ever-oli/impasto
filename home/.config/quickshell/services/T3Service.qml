// ╭──────────────────────────────────────────────────────────────────────────╮
// │   T 3   S E R V I C E                                                    │
// │   t3code-web state, the installed nightly and the latest release         │
// ╰──────────────────────────────────────────────────────────────────────────╯
//
// scripts/t3.py does the work: it reads the version out of app.asar (no
// Electron start) and caches the GitHub release for half an hour, so the poll
// below is cheap. Polls only while something on screen shows it.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/t3.py")

    property string service: "unknown"
    property string installed: ""
    property string latest: ""
    property string published: ""
    property string error: ""
    property real checked: 0
    property bool updateAvailable: false
    property bool updating: false
    property string updateLog: ""

    readonly property bool running: root.service === "active"
    readonly property int panelWidth: 420
    readonly property int panelHeight: 300

    property int watchers: 0
    function subscribe(): void { root.watchers++; root.refresh(false) }
    function release(): void { root.watchers = Math.max(0, root.watchers - 1) }

    function refresh(force: bool): void {
        if (statusProcess.running)
            return
        statusProcess.command = [root.script, "status"].concat(force ? ["--refresh"] : [])
        statusProcess.running = true
    }

    function open(): void {
        Quickshell.execDetached(["sh", "-c", "exec \"$HOME/.local/bin/t3code-launch\" || exec t3code-nightly"])
    }

    function openWeb(): void {
        Quickshell.execDetached(["xdg-open", "http://127.0.0.1:3773"])
    }

    function startService(): void {
        Quickshell.execDetached(["systemctl", "--user", "restart", "t3code-web"])
        settle.restart()
    }

    function update(): void {
        if (root.updating)
            return
        root.updating = true
        root.updateLog = "Downloading…"
        updateProcess.running = true
    }

    readonly property Timer poll: Timer {
        interval: 15000
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh(false)
    }

    readonly property Timer settle: Timer {
        interval: 2500
        onTriggered: root.refresh(false)
    }

    Component.onCompleted: root.refresh(false)

    readonly property Process statusProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text)
                    root.service = s.service
                    root.installed = s.installed
                    root.latest = s.latest
                    root.published = s.published
                    root.error = s.error
                    root.checked = s.checked
                    root.updateAvailable = s.update
                } catch (e) {
                    console.warn("t3.py status:", e)
                }
            }
        }
    }

    readonly property Process updateProcess: Process {
        command: [root.script, "update"]
        stdout: SplitParser { onRead: line => root.updateLog = line }
        stderr: SplitParser { onRead: line => root.updateLog = line }
        onExited: (code) => {
            root.updating = false
            if (code !== 0)
                root.updateLog = `Update failed (${code})`
            root.refresh(true)
        }
    }
}
