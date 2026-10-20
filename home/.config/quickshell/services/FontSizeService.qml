// Text size: live preview in quickshell, one debounced `notch-font size`
// for every other app. Shared by the slider overlay and the control centre.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

Singleton {
    id: root

    readonly property int from: 8
    readonly property int to: 20
    // What the other apps were last told; Theme.fontBase is the preview.
    // Starts unbound (-1 = whatever theme.json says) so a preview is never
    // mistaken for already applied.
    property int sent: -1
    readonly property int applied: sent < 0 ? Theme.fontBase : sent
    readonly property int value: Theme.fontBase
    readonly property bool pending: commit.running || applier.running

    function preview(n) {
        n = Math.max(from, Math.min(to, Math.round(n)));
        if (n === Theme.fontBase) return;
        Theme.fontBase = n;
        commit.restart();
    }
    function step(d) { preview(Theme.fontBase + d) }
    function applyNow() { if (commit.running) { commit.stop(); run() } }
    function run() {
        if (applier.running) return;   // onExited picks up the latest
        applier.command = [Quickshell.env("HOME") + "/.local/bin/notch-font", "size", String(Theme.fontBase)];
        applier.running = true;
        sent = Theme.fontBase;
    }

    Timer { id: commit; interval: 450; onTriggered: root.run() }
    Process {
        id: applier
        environment: ({ NOTCH_FONT_QUIET: "1" })
        onExited: if (root.sent !== Theme.fontBase) commit.restart()
    }
}
