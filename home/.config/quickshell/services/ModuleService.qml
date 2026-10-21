// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O D U L E   S E R V I C E                                            │
// │   module catalogue · activity and open panel state                       │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQml
import QtQuick
import Quickshell

import "../theme"

// The bar's catalogue: what each module is, its glyph and figure, whether this
// machine can show it, and which detail is open.
//
// A piece on the bar is a module or a button. A module tells you something:
// it always has a figure, and a click opens its detail in the island. A
// button does something: a symbol with no figure that opens a panel or runs
// an action. Detail sizes are declared here because the island has to reach
// that size before the detail exists.
//
// Adding a module: a file in bar/modules, a row in `catalogue` and a line in
// Module.qml. Adding a button: a door in ControlsService, or a row here.
Singleton {
    id: root

    //   bar      whether it can go on the bar (board, deck and arcade live on
    //            the desktop and behind their panels instead)
    //   desk     false for the one module with no desktop face
    //   width    detail size; none for the spectrum, which has no detail and
    //   height   lives only on the desktop, on the grid or along an edge, nor
    //            for the lyrics, whose detail is the player's
    //
    // The chip look is global (`SettingsService.chipShape`, `chipFigure`);
    // desktop faces are listed per theme in `DesktopService.faces`.
    readonly property var catalogue: [
        { id: "t3",            name: "T3 Code",       bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(3, Theme.cardRowGap + 40) },
        { id: "volume",        name: "Volume",        bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(2, 0) },
        { id: "machine",       name: "CPU · RAM",     bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(3, 0) },
        { id: "battery",       name: "Battery",       bar: true,  desk: false, width: Theme.cardWidth, height: Theme.cardHeight(2, 0) },
        { id: "idle",          name: "Auto-stop",     bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(3, 0) },
        { id: "network",       name: "Network",       bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(2, 0) },
        { id: "bluetooth",     name: "Bluetooth",     bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(3, 0) },
        { id: "notifications", name: "Notifications", bar: true,  desk: false, width: Theme.cardWidth, height: Theme.cardHeight(7, 0) },
        { id: "clock",         name: "Clock",         bar: false,
          width: (SettingsService.clockShowsDate ? 240 : 150) + root.clock12hExtra, height: Theme.capsuleHeight }
    ]

    function entry(id: string): var {
        return root.catalogue.find(item => item.id === id) ?? root.catalogue[0]
    }

    readonly property var buttonIds: ["launcher", "controls", "capture", "keys", "session"]

    readonly property var buttons: {
        const out = {}
        for (const id of root.buttonIds) {
            if (id === "controls") {
                out[id] = { name: "Control centre", glyph: "󰨚", panel: "controls" }
                continue
            }
            if (id === "capture") {
                out[id] = { name: "Capture", glyph: "󰹑",
                            action: () => CaptureService.open("", "", "", 0) }
                continue
            }
            const door = ControlsService.door(id)
            if (door === null || door.panel === "")
                continue
            out[id] = { name: door.label, glyph: door.icon, panel: door.panel }
        }
        return out
    }

    function isButton(id: string): bool {
        return root.buttons[id] !== undefined
    }

    function placeable(id: string): bool {
        return id === "workspaces" || id === "tray" || id === "split" || root.isButton(id)
            || root.catalogue.some(item => item.id === id && item.bar)
    }

    function watch(id: string, on: bool): void {
        if (id === "t3") {
            if (on)
                T3Service.subscribe()
            else
                T3Service.release()
        }
    }

    signal panelToggled(string panel)

    function togglePanel(panel: string): void {
        root.panelToggled(panel)
    }

    property string shownPanel: ""

    // Kept so older callers still link; there is no settings window.
    signal settingsRequested()

    readonly property var ringed: ["volume"]

    function shapeOf(id: string, own: var): string {
        const chosen = own ? own : SettingsService.chipShape
        return chosen === "ring" && root.ringed.indexOf(id) >= 0 ? "ring" : "icon"
    }

    function figureOf(own: var): string {
        return own ? own : SettingsService.chipFigure
    }

    function glyphOf(id: string): string {
        switch (id) {
        case "network":
            return NetworkService.icon
        case "bluetooth":
            return BluetoothService.icon
        case "volume":
            return AudioService.icon
        case "notifications":
            return NotificationService.doNotDisturb ? "󰂛" : "󰂚"
        case "t3":
            return "󰚩"
        case "battery":
            return BatteryService.glyph
        case "machine":
            return "󰍛"
        case "idle":
            return "󰁹"
        }
        return ""
    }

    function valueOf(id: string): string {
        switch (id) {
        case "volume":
            return AudioService.muted ? "Muted" : `${AudioService.volume}%`
        case "notifications":
            return `${NotificationService.history.length}`
        case "network":
            return NetworkService.online ? CloudService.netText : "Offline"
        case "machine":
            return `CPU ${CloudService.cpu}%  RAM ${CloudService.mem}%`
        case "idle":
            return CloudService.idleText
        case "bluetooth":
            return BluetoothService.summary
        case "t3":
            return T3Service.updateAvailable ? "Update" : (T3Service.running ? "T3" : "T3 off")
        case "battery":
            return BatteryService.has ? `${BatteryService.percent}%` : ""
        }
        return ""
    }

    function figureLimit(id: string): int {
        switch (id) {
        case "network":
        case "bluetooth":
            return 110
        }
        return 0
    }

    function tintOf(id: string): color {
        if (id === "t3") {
            if (!T3Service.running)
                return Theme.indicatorBad
            if (T3Service.updateAvailable)
                return Theme.indicatorWarn
        }
        if (id === "battery" && BatteryService.bad)
            return Theme.indicatorWarn
        if (id === "idle" && CloudService.idleLeft < 900)
            return Theme.indicatorWarn
        return Theme.text
    }

    readonly property var runners: []

    function runs(id: string): bool {
        return false
    }

    function shows(id: string, when: var): bool {
        return root.has(id)
    }

    // Beside the time: only a recording, which nothing else shows or stops,
    // and the workspace when kept.
    readonly property var running: RecorderService.recording ? ["recorder"] : []

    readonly property var activities: (SettingsService.beside("workspace")
        ? root.running.concat(["workspace"]) : root.running).slice(0, 2)

    readonly property int overflow: Math.max(0, root.running.length - 2)
    readonly property int overflowWidth: 30

    // The conversion beside the clock is the island's small size; measure
    // the widest it can be ("08:48:59 PM") at a fixed time, as the glance
    // measures its own time, and let the band plan for it.
    readonly property FontMetrics clockOtherMetrics: FontMetrics {
        font.family: Theme.fontBar
        font.pixelSize: Theme.fontSizeSmall
    }
    readonly property int clock12hExtra: !SettingsService.clockShows12h ? 0
        : Math.ceil(root.clockOtherMetrics.advanceWidth(
            Qt.formatTime(new Date(2000, 0, 1, 20, 48, 58), SettingsService.clockOtherFormat))) + 8

    readonly property int clockCore: (SettingsService.clockShowsDate
        ? 150 : (SettingsService.clockShowsSeconds ? 88 : 72)) + root.clock12hExtra
    readonly property int activitySide: root.activities.length > 1 ? 92 : 64
    readonly property int activityInset: 14

    readonly property int restWidth: root.activities.length === 0
        ? root.entry("clock").width
        : root.clockCore + 2 * root.activitySide
            + (root.overflow > 0 ? root.overflowWidth : 0)

    readonly property int summaryWidth: (root.glanceFace === "clock" ? 420 : 560)
        + root.glanceTime - root.glanceTimeBase
    readonly property int glanceTimeBase: root.timeMetrics.font.family !== ""
        ? Math.ceil(root.timeMetrics.advanceWidth("20:48")) : 0
    readonly property int glanceTime: root.timeMetrics.font.family !== ""
        ? Math.max(root.glanceTimeBase, Math.ceil(root.timeMetrics.advanceWidth(
            Qt.formatTime(new Date(2000, 0, 1, 20, 48, 58), SettingsService.clockFormat))))
        : 0
    readonly property FontMetrics timeMetrics: FontMetrics {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(62)
        font.weight: Font.Black
    }
    readonly property int summaryHeight: root.glanceFaceHeight
        + (root.glanceStrip.length > 0 ? root.glanceStripHeight : 0)

    readonly property var glanceRows: RecorderService.recording ? ["recorder"] : []
    readonly property string glanceFace: root.glanceRows.length > 0 ? root.glanceRows[0] : "clock"
    readonly property var glanceStrip: root.glanceRows.filter(id => id !== root.glanceFace)
    readonly property int glanceMargin: 19
    readonly property int glanceFaceHeight: 150
    readonly property int glanceStripHeight: 38

    property string openId: ""
    property string openHost: ""

    function close(): void {
        root.openId = ""
        root.openHost = ""
    }

    function openSize(id: string): var {
        if (id === "bluetooth")
            return { width: 420, height: 500 }
        const item = root.entry(id)
        if (id === "notifications")
            return { width: item.width,
                     height: Theme.cardHeight(Math.min(6, NotificationService.history.length) + 1, 0) }
        if (id === "volume")
            return { width: item.width, height: Theme.cardHeight(AudioService.cardRows, 0) }
        return { width: item.width, height: item.height }
    }

    readonly property bool openGone: root.openId !== "" && !root.has(root.openId)

    onOpenGoneChanged: {
        if (root.openGone)
            root.close()
    }

    signal activationRequested(string id)

    function activate(id: string): void {
        root.activationRequested(id)
    }

    signal panelRequested(string panel)

    function requestPanel(panel: string): void {
        root.panelRequested(panel)
    }

    function has(id: string): bool {
        if (id === "capture")
            return CaptureService.can("grim")
        if (root.isButton(id))
            return true
        switch (id) {
        case "clock":
        case "workspaces":
        case "tray":
        case "notifications":
        case "network":
        case "t3":
        case "machine":
        case "idle":
            return true
        case "battery":
            return BatteryService.has
        case "volume":
            return AudioService.ready
        case "bluetooth":
            return BluetoothService.available
        }
        return false
    }
}
