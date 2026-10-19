// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T 3   S E R V I C E                                                    │
// │   T3 Code usage · read from the omarchy collector's record               │
// │                                                                          │
// │   EVER LEAN: replaced ClaudeService and CodexService. No network and no   │
// │   helpers — it watches ~/.local/state/omarchy/agents/usage/t3.json        │
// │   (written by the omarchy T3 collector) and turns it into a model.       │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Sessions, prompts and tokens for T3 Code on this machine.
Singleton {
    id: root

    // Whether a record has been read.
    property bool available: false
    // Whether the gauge has anything real to fill (the week had activity).
    property bool measured: false
    // 0..1 for the ring face, from the week's pulse.
    property real gauge: 0
    // Detail rows the card shows.
    property var rows: []

    readonly property string name: data.name ?? "T3 Code"
    readonly property string tierLabel: data.tierLabel ?? ""
    readonly property int todaySessions: data.todaySessions ?? 0
    readonly property int todayPrompts: data.todayPrompts ?? 0
    readonly property int todayTokens: data.todayTotalTokens ?? 0
    readonly property int totalSessions: data.totalSessions ?? 0
    readonly property var recentDays: data.recentDays ?? []

    property var data: ({})

    readonly property FileView store: FileView {
        path: `${Quickshell.env("HOME")}/.local/state/omarchy/agents/usage/t3.json`
        watchChanges: true

        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(text())
                root.refresh()
            } catch (error) {
                root.available = false
                root.measured = false
            }
        }
        onLoadFailed: error => {
            // Nothing written yet: an empty gauge, not an error.
            if (error === FileViewError.FileNotFound) {
                root.available = true
                root.measured = false
                root.rows = [{ key: "none", label: Tr.t("No prompts yet"), value: Tr.t("waiting for the collector") }]
            }
        }
    }

    // Built on first use by `ModuleService.has` / `watch`, so the watcher is
    // running from the first bar that carries the t3 module.
    Component.onCompleted: {
        root.store.reload()
    }

    function refresh(): void {
        if (!root.data || !root.data.name) {
            root.available = false
            root.measured = false
            return
        }
        root.available = true

        // A week of messages gives the pulse; the today share of it fills the
        // ring, a quiet day reads near empty rather than wrong.
        let week = 0
        let best = 0
        for (const day of root.recentDays) {
            const messages = day.messageCount ?? 0
            week += messages
            if (messages > best)
                best = messages
        }
        root.gauge = week > 0
            ? 0.15 + 0.85 * Math.min(1, (root.todayPrompts + root.todaySessions) / week)
            : 0
        root.measured = best > 0

        const rows = []
        if (root.todaySessions > 0 || root.todayTokens > 0)
            rows.push({ key: "today", label: Tr.t("Today"),
                        value: `${root.todaySessions} ${Tr.t("sessions")}${root.todayTokens > 0
                            ? ` · ${root.compactTokens(root.todayTokens)} ${Tr.t("tokens")}` : ""}` })
        else
            rows.push({ key: "today", label: Tr.t("Today"),
                        value: Tr.t("no sessions yet") })
        if (root.totalSessions > 0)
            rows.push({ key: "all", label: Tr.t("All time"),
                        value: `${root.totalSessions} ${Tr.t("sessions")}` })
        for (const day of root.recentDays.slice(0, 5)) {
            if ((day.messageCount ?? 0) === 0)
                continue
            rows.push({ key: day.date, label: day.date.slice(5),
                        value: `${day.messageCount} ${Tr.t("messages")}` })
        }
        if (root.tierLabel !== "")
            rows.push({ key: "tier", label: Tr.t("Behind"), value: root.tierLabel })
        root.rows = rows
    }

    function compactTokens(tokens: int): string {
        if (tokens >= 1000000)
            return `${(tokens / 1000000).toFixed(1)}M`
        if (tokens >= 1000)
            return `${(tokens / 1000).toFixed(0)}k`
        return `${tokens}`
    }
}
