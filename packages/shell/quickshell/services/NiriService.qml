// ╭──────────────────────────────────────────────────────────────────────────╮
// │   N I R I   S E R V I C E                                                │
// │   workspaces, windows and outputs from niri's IPC                        │
// ╰──────────────────────────────────────────────────────────────────────────╯
//
// One long-lived `niri msg --json event-stream` keeps everything current:
// niri sends the full workspace and window lists first, then deltas. Actions
// go out as `niri msg action …`, fire and forget.
//
// Workspace numbers are niri's per-output `idx` (what Mod+1…9 focus), so the
// bar on each screen counts that screen's workspaces.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // niri keeps one empty workspace at the end of each output; the bar shows
    // this many slots at least, and grows for any that are in use.
    readonly property int slots: Math.min(SettingsService.workspaceCount, root.maximum)
    readonly property int maximum: Math.max(10, SettingsService.workspaceMax)
    readonly property bool perScreen: false

    // Raw IPC state.
    property var workspaces: []      // niri Workspace objects
    property var windows: []         // niri Window objects
    property bool overviewOpen: false

    readonly property var focusedWorkspace: root.workspaces.find(w => w.is_focused) ?? null
    readonly property string focusedMonitor: root.focusedWorkspace?.output ?? ""
    readonly property int activeId: root.focusedWorkspace?.idx ?? 1

    // Workspaces on the focused output, the shape the bar reads.
    readonly property var named: root.workspaces
        .filter(w => w.output === root.focusedMonitor)
        .map(w => ({ id: w.idx, name: w.name ?? "", monitor: w.output, niriId: w.id }))

    readonly property var occupiedIds: {
        const used = new Set(root.windows.map(win => win.workspace_id))
        return root.workspaces
            .filter(w => w.output === root.focusedMonitor && used.has(w.id))
            .map(w => w.idx)
    }

    readonly property int span: Math.max(root.slots, ...root.occupiedIds, root.activeId)

    function activeOn(monitor: string): int {
        const found = root.workspaces.find(w => w.output === monitor && w.is_active)
        return found ? found.idx : 0
    }
    function baseOn(monitor: string): int { return 0 }
    function numberOn(workspaceId: int, monitor: string): int { return workspaceId }
    function isOccupied(workspaceId: int): bool { return root.occupiedIds.indexOf(workspaceId) >= 0 }
    function isVisible(workspaceId: int): bool {
        return workspaceId <= root.slots || root.isOccupied(workspaceId) || workspaceId === root.activeId
    }
    function isVisibleOn(workspaceId: int, monitor: string): bool { return root.isVisible(workspaceId) }
    function monitorOf(workspaceId: int): string { return root.focusedMonitor }

    // ── WINDOWS ─────────────────────────────────────────────────────────────
    //
    // `clients` keeps the field names the launcher and capture read:
    // address (niri window id as a string), class, title, workspace.id (idx).
    readonly property var clients: root.windows.map(win => {
        const ws = root.workspaces.find(w => w.id === win.workspace_id)
        return {
            address: String(win.id), title: win.title ?? "", class: win.app_id ?? "",
            floating: win.is_floating ?? false,
            workspace: { id: ws ? ws.idx : 0 }, monitor: ws ? ws.output : ""
        }
    })
    readonly property var focusedWindow: root.windows.find(win => win.is_focused) ?? null
    readonly property string focusedAddress: root.focusedWindow ? String(root.focusedWindow.id) : ""
    readonly property string focusedClass: root.focusedWindow?.app_id ?? ""

    function clientsOn(workspaceId: int): var {
        return root.clients.filter(c => c.workspace.id === workspaceId && c.monitor === root.focusedMonitor)
    }
    function loadClients(): void {}   // the event stream keeps them current
    function loadMonitors(): void { outputsProcess.running = true }
    function refresh(): void {}

    // ── ACTIONS ─────────────────────────────────────────────────────────────

    function action(...args): void {
        Quickshell.execDetached(["niri", "msg", "action"].concat(args.map(String)))
    }
    function focus(workspaceId: int): void { root.action("focus-workspace", workspaceId) }
    function focusWindow(address: string): void { root.action("focus-window", "--id", address) }
    function closeWindow(address: string): void { root.action("close-window", "--id", address) }
    function toggleFloating(address: string): void { root.action("toggle-window-floating", "--id", address) }
    function moveClient(address: string, workspaceId: int): void {
        root.action("move-window-to-workspace", "--window-id", address, "--focus", "false", workspaceId)
    }
    function toggleOverview(): void { root.action("toggle-overview") }
    function quit(): void { root.action("quit", "--skip-confirmation") }
    function powerOffMonitors(): void { root.action("power-off-monitors") }

    // ── OUTPUTS ─────────────────────────────────────────────────────────────

    property var monitors: []
    readonly property Process outputsProcess: Process {
        command: ["niri", "msg", "--json", "outputs"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const outputs = root.parseJson(text)
                if (outputs)
                    root.monitors = Object.values(outputs).map(o => ({
                        name: o.name, make: o.make, model: o.model,
                        width: o.logical?.width ?? 0, height: o.logical?.height ?? 0,
                        x: o.logical?.x ?? 0, y: o.logical?.y ?? 0, scale: o.logical?.scale ?? 1
                    }))
            }
        }
    }

    // ── BINDS ───────────────────────────────────────────────────────────────

    readonly property var modifierNames: [
        { bit: 64, name: "SUPER" }, { bit: 4, name: "CTRL" },
        { bit: 8, name: "ALT" }, { bit: 1, name: "SHIFT" }
    ]
    property var binds: []
    function spell(bind: var): string {
        const parts = root.modifierNames.filter(m => bind.modmask & m.bit).map(m => m.name)
        parts.push(bind.key)
        return parts.join(" + ")
    }
    function loadBinds(): void { bindsProcess.running = true }
    readonly property Process bindsProcess: Process {
        command: [Quickshell.shellPath("scripts/niri_binds.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.parseJson(text)
                if (Array.isArray(list))
                    root.binds = list
            }
        }
    }

    // ── EVENT STREAM ────────────────────────────────────────────────────────

    readonly property Process stream: Process {
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser { onRead: line => root.handle(line) }
        // niri restarting (or a config error at start-up) ends the stream.
        onExited: restart.start()
    }
    readonly property Timer restart: Timer {
        interval: 1000
        onTriggered: root.stream.running = true
    }

    function handle(line: string): void {
        const event = root.parseJson(line)
        if (!event)
            return
        const [kind, data] = Object.entries(event)[0] ?? []
        switch (kind) {
        case "WorkspacesChanged":
            root.workspaces = data.workspaces
            break
        case "WorkspaceActivated": {
            const target = root.workspaces.find(w => w.id === data.id)
            if (!target)
                break
            root.workspaces = root.workspaces.map(w => {
                const next = Object.assign({}, w)
                if (w.output === target.output)
                    next.is_active = w.id === data.id
                if (data.focused)
                    next.is_focused = w.id === data.id
                return next
            })
            break
        }
        case "WorkspaceActiveWindowChanged":
            root.workspaces = root.workspaces.map(w => w.id === data.workspace_id
                ? Object.assign({}, w, { active_window_id: data.active_window_id }) : w)
            break
        case "WindowsChanged":
            root.windows = data.windows
            break
        case "WindowOpenedOrChanged": {
            const win = data.window
            let list = root.windows.filter(w => w.id !== win.id)
            if (win.is_focused)
                list = list.map(w => w.is_focused ? Object.assign({}, w, { is_focused: false }) : w)
            list.push(win)
            root.windows = list
            break
        }
        case "WindowClosed":
            root.windows = root.windows.filter(w => w.id !== data.id)
            break
        case "WindowFocusChanged":
            root.windows = root.windows.map(w => (w.is_focused !== (w.id === data.id))
                ? Object.assign({}, w, { is_focused: w.id === data.id }) : w)
            break
        case "OverviewOpenedOrClosed":
            root.overviewOpen = data.is_open
            break
        case "ConfigLoaded":
            root.loadBinds()
            root.loadMonitors()
            break
        }
    }

    function parseJson(text: string): var {
        if (!text || text.trim() === "")
            return null
        try {
            return JSON.parse(text)
        } catch (error) {
            console.warn("niri IPC:", error)
            return null
        }
    }
}
