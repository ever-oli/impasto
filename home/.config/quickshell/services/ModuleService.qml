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

    //   bar      whether it can go on the bar (the desktop pieces are gone;
    //            a bar module is all this shell has, which is the point)
    //   width    detail size; none for the clock, which opens no detail
    //   height
    //
    // The chip look is global (`SettingsService.chipShape`, `chipFigure`).
    readonly property var catalogue: [
        { id: "media",         name: "Media",         bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(1, Theme.cardRowGap + 34) },
        { id: "timer",         name: "Timer",         bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(2, 0) },
        { id: "t3",            name: "T3 Code",       bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(2, 0) },
        { id: "battery",       name: "Battery",       bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(3, 0) },
        { id: "volume",        name: "Volume",        bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(2, 0) },
        { id: "brightness",    name: "Brightness",    bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(1, 0) },
        { id: "network",       name: "Network",       bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(2, 0) },
        { id: "bluetooth",     name: "Bluetooth",     bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(3, 0) },
        { id: "notifications", name: "Notifications", bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(7, 0) },
        { id: "stats",         name: "System",        bar: true,  width: Theme.cardWidth, height: Theme.cardHeight(2, Theme.cardRowGap + 36) },
        { id: "clock",         name: "Clock",         bar: false,
          width: SettingsService.clockShowsDate ? 240 : 150, height: Theme.capsuleHeight }
    ]

    function entry(id: string): var {
        return root.catalogue.find(item => item.id === id) ?? root.catalogue[0]
    }

    // ── BUTTONS ─────────────────────────────────────────────────────────────
    //
    // Every door of the control centre can go on the bar, under its name and
    // glyph, and so can the control centre itself. Not the statistics: on the
    // bar those are modules, and a button beside them would be the same piece
    // without its figure. Alone in a capsule, a button is drawn as a circle.
    readonly property var buttonIds: ["launcher", "overview", "controls",
        "appearance", "settings", "session"]

    readonly property var buttons: {
        const out = {}
        for (const id of root.buttonIds) {
            if (id === "controls") {
                out[id] = { name: "Control centre", glyph: "󰨚", panel: "controls" }
                continue
            }
            const door = ControlsService.door(id)
            if (door === null)
                continue
            // The one door with no panel is the settings window.
            out[id] = door.panel !== ""
                ? { name: door.label, glyph: door.icon, panel: door.panel }
                : { name: door.label, glyph: door.icon, action: () => root.settingsRequested() }
        }
        return out
    }

    function isButton(id: string): bool {
        return root.buttons[id] !== undefined
    }

    // Whether an id from a saved layout is still a piece: one taken out of
    // the catalogue is dropped rather than drawn as something else.
    function placeable(id: string): bool {
        return id === "workspaces" || id === "tray" || id === "split" || root.isButton(id)
            || root.catalogue.some(item => item.id === id && item.bar)
    }

    // A reading that polls keeps polling while a piece on the bar shows it.
    function watch(id: string, on: bool): void {
        if (id === "t3") {
            if (on)
                T3Service.subscribe()
            else
                T3Service.release()
        }
    }

    // Buttons cannot see the island, so they ask here and the bar listens.
    // The bar writes the open panel back to `shownPanel` so a button can stay
    // lit.
    signal panelToggled(string panel)

    function togglePanel(panel: string): void {
        root.panelToggled(panel)
    }

    property string shownPanel: ""

    // The settings window is not an island panel; shell.qml opens it.
    signal settingsRequested()

    // ── CHIP SHAPE ──────────────────────────────────────────────────────────
    //
    // Modules with a ring face: those whose reading fills from empty to full.
    // A state or a count (the network, the bell, the date) has nothing to
    // fill, so it keeps its symbol in either shape.
    readonly property var ringed: ["media", "timer", "t3", "battery", "volume",
        "brightness", "stats"]

    // A piece's own shape when it has one, the bar's when it does not.
    function shapeOf(id: string, own: var): string {
        const chosen = own ? own : SettingsService.chipShape
        return chosen === "ring" && root.ringed.indexOf(id) >= 0 ? "ring" : "icon"
    }

    function figureOf(own: var): string {
        return own ? own : SettingsService.chipFigure
    }

    // ── GLYPH AND FIGURE ────────────────────────────────────────────────────
    //
    // One table for every place a module's symbol and figure appear (bar,
    // glance, settings), in either chip shape.
    function glyphOf(id: string): string {
        switch (id) {
        case "network":
            return NetworkService.icon
        case "bluetooth":
            return BluetoothService.icon
        case "volume":
            return AudioService.icon
        case "brightness":
            return BrightnessService.icon
        case "battery":
            return BatteryService.icon
        case "notifications":
            return NotificationService.doNotDisturb ? "󰂛" : "󰂚"
        case "media":
            return "󰎇"
        case "timer":
            return "󰔛"
        case "stats":
            return "󰍛"
        case "t3":
            return "\uf0d0"
        }
        return ""
    }

    // Never empty, so "always show the figure" applies to every module: a
    // connection shows its name, an empty bell "0", an idle countdown "0:00".
    function valueOf(id: string): string {
        switch (id) {
        case "volume":
            return AudioService.muted ? "Muted" : `${AudioService.volume}%`
        case "brightness":
            return `${BrightnessService.percent}%`
        case "battery":
            return `${BatteryService.percent}%`
        case "notifications":
            return `${NotificationService.history.length}`
        case "media":
            return MediaService.available
                ? (MediaService.title || MediaService.identity || "Playing") : "Nothing playing"
        case "timer":
            return TimerService.running ? TimerService.display : "0:00"
        case "t3":
            return T3Service.measured ? `${Math.round(T3Service.gauge * 100)}%` : "—"
        case "stats":
            return `${StatsService.cpu.toFixed(0)}%`
        case "network":
            return NetworkService.connectionName
        case "bluetooth":
            return BluetoothService.summary
        }
        return ""
    }

    // For the calendar's figure, which only changes at midnight.
    readonly property SystemClock today: SystemClock {
        precision: SystemClock.Minutes
    }

    // Maximum width for text figures (track title, network or device name)
    // before they are elided.
    function figureLimit(id: string): int {
        switch (id) {
        case "media":
            return 150
        case "network":
        case "bluetooth":
            return 110
        }
        return 0
    }

    // Warnings (low battery, hot CPU) use the fixed indicator
    // hues; everything else is plain text colour.
    function tintOf(id: string): color {
        switch (id) {
        case "battery":
            if (BatteryService.available && !BatteryService.charging && !BatteryService.full) {
                if (BatteryService.percent <= 10)
                    return Theme.indicatorBad
                if (BatteryService.percent <= 20)
                    return Theme.indicatorWarn
            }
            break
        case "stats":
            if (StatsService.cpu >= 90)
                return Theme.indicatorBad
            if (StatsService.cpu >= 70)
                return Theme.indicatorWarn
            break
        case "timer":
            return TimerService.running ? TimerService.tint : Theme.text
        }
        return Theme.text
    }

    // ── VISIBILITY ──────────────────────────────────────────────────────────
    //
    // A placed piece always shows; the player says "Nothing playing" rather
    // than disappearing. The timer and the player can instead be set to show
    // only while running (`when: "running"`).
    readonly property var runners: ["timer", "media"]

    function runs(id: string): bool {
        switch (id) {
        case "timer":
            return TimerService.running
        case "media":
            return MediaService.playing
        }
        return false
    }

    function shows(id: string, when: var): bool {
        if (when === "running" && root.runners.indexOf(id) >= 0)
            return root.runs(id)
        return id === "media" || root.has(id)
    }

    // ── ACTIVITIES ──────────────────────────────────────────────────────────
    //
    // Up to two running activities shown beside the time, most urgent first:
    // recording, the microphone, camera or screen in use, countdown, music,
    // and the workspace, for a bar without the strip. A
    // countdown or music can be kept off the island (`SettingsService.beside`)
    // without affecting its module; so can the privacy mark, which has no
    // module, and the service behind it is not built while it is off. A
    // recording cannot, since nothing else on screen shows or stops it.
    readonly property var running: {
        const list = []
        if (TimerService.running && SettingsService.beside("timer"))
            list.push("timer")
        if (MediaService.playing && SettingsService.beside("media"))
            list.push("media")
        return list
    }

    // The workspace is always there when kept, so it is last: the others
    // come and go.
    readonly property var activities: (SettingsService.beside("workspace")
        ? root.running.concat(["workspace"]) : root.running).slice(0, 2)

    // What is running but did not fit, counted at the island's trailing end.
    // The workspace never counts: it is not something that started.
    readonly property int overflow: Math.max(0, root.running.length - 2)
    readonly property int overflowWidth: 30

    // Resting width. Alone, the time keeps the catalogue width; with
    // activities it shrinks to fit and each side gets a slot. One activity
    // splits across both sides (mark left, figure right); two take one each.
    readonly property int clockCore: SettingsService.clockShowsDate
        ? 150 : (SettingsService.clockShowsSeconds ? 88 : 72)
    readonly property int activitySide: {
        if (root.activities.length > 1)
            return 92
        return 64
    }

    readonly property int activityInset: 14

    readonly property FontMetrics nameMetrics: FontMetrics {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeRegular
        font.weight: Font.DemiBold
    }
    readonly property int restWidth: root.activities.length === 0
        ? root.entry("clock").width
        : root.clockCore + 2 * root.activitySide
            + (root.overflow > 0 ? root.overflowWidth : 0)

    // The glance the island opens under a resting pointer: one face — a
    // square, the text beside it, the time large at the far end — and a
    // strip of chips under it for whatever else is running. With nothing
    // running the time alone.

    // The widths fit a 24-hour time; a longer format (seconds, AM/PM) widens
    // the glance by what it adds, measured at the glance's type. The music
    // is wider, for a line of lyrics beside the time; the rest leave their
    // reading 170 px, which a weather line or a machine's state needs.
    readonly property int summaryWidth: root.glanceFace === "clock"
        ? root.glanceTime + 2 * (root.glanceMargin + 4)
        : (root.glanceFace === "media" ? 620 : 560) + root.glanceTime - root.glanceTimeBase
    // Measured again when the type changes: a call is not a dependency.
    readonly property int glanceTimeBase: root.timeMetrics.font.family !== ""
        ? Math.ceil(root.timeMetrics.advanceWidth("20:48")) : 0
    readonly property int glanceTime: root.timeMetrics.font.family !== ""
        ? Math.max(root.glanceTimeBase, Math.ceil(root.timeMetrics.advanceWidth(
            Qt.formatTime(new Date(2000, 0, 1, 20, 48, 58), SettingsService.clockFormat))))
        : 0
    readonly property FontMetrics timeMetrics: FontMetrics {
        font.family: Theme.fontFamily
        font.pixelSize: 62
        font.weight: Font.Black
    }
    readonly property int summaryHeight: root.glanceFaceHeight
        + (root.glanceStrip.length > 0 ? root.glanceStripHeight : 0)

    // Everything running, in the island's order. Its own count, not the
    // island's: a countdown kept off the island still shows here.
    readonly property var glanceRows: {
        const list = []
        if (TimerService.running)
            list.push("timer")
        if (MediaService.available)
            list.push("media")
        return list
    }
    // The face is what has the most to press: the music, then the countdown.
    readonly property var glanceRank: ["media", "timer"]
    readonly property string glanceFace: root.glanceRank.find(id => root.glanceRows.includes(id))
        ?? "clock"
    readonly property var glanceStrip: root.glanceRows.filter(id => id !== root.glanceFace)
    readonly property int glanceMargin: 19
    readonly property int glanceFaceHeight: 150
    readonly property int glanceStripHeight: 38

    // ── OPEN DETAIL ─────────────────────────────────────────────────────────
    //
    // One detail at a time, always shown by the island (`Bar.qml` writes
    // "island" to `openHost`).
    property string openId: ""
    property string openHost: ""

    function close(): void {
        root.openId = ""
        root.openHost = ""
    }

    // The catalogue size, except network and Bluetooth, which open the
    // control centre's lists, an empty notification list, which is short,
    // and the cards whose rows come and go, sized from their count.
    function openSize(id: string): var {
        if (id === "network" || id === "bluetooth")
            return { width: 420, height: 500 }
        const item = root.entry(id)
        if (id === "notifications")
            return { width: item.width,
                     height: Theme.cardHeight(Math.min(6, NotificationService.history.length) + 1, 0) }
        if (id === "t3")
            return { width: item.width, height: Theme.cardHeight(T3Service.rows, 0) }
        if (id === "battery")
            return { width: item.width, height: Theme.cardHeight(BatteryService.healthKnown ? 3 : 2, 0) }
        if (id === "volume")
            return { width: item.width, height: Theme.cardHeight(AudioService.cardRows, 0) }
        if (id === "brightness")
            return { width: item.width,
                     height: Theme.cardHeight(Math.max(1, BrightnessService.dimmable.length), 0) }
        if (id === "media")
            return { width: item.width, height: MediaService.seekable
                ? Theme.cardHeight(1, Theme.cardRowGap + 34) : Theme.cardHeight(0, 34) }
        return { width: item.width, height: item.height }
    }

    // A module that becomes unavailable closes its open detail.
    readonly property bool openGone: root.openId !== "" && !root.has(root.openId)

    onOpenGoneChanged: {
        if (root.openGone)
            root.close()
    }

    // Chips cannot see their bar, so they ask here and every bar listens. The
    // live one answers, since the detail opens in its island.
    signal activationRequested(string id)

    function activate(id: string): void {
        root.activationRequested(id)
    }

    // A module asking for a panel, e.g. the games detail opening the arcade.
    signal panelRequested(string panel)

    function requestPanel(panel: string): void {
        root.panelRequested(panel)
    }

    // ── AVAILABILITY ────────────────────────────────────────────────────────
    //
    // Whether this machine can show the module at all (a backlight, a player
    // on the bus, pacman-contrib installed). Not a preference; placement is
    // the layout's job.
    function has(id: string): bool {
        if (root.isButton(id))
            return true
        switch (id) {
        case "clock":
        case "timer":
        case "workspaces":
        case "tray":
        case "notifications":
            return true
        case "media":
            return MediaService.available
        case "t3":
            // False until the usage file exists; reading it constructs the
            // lazy singleton, which keeps the file watched.
            return T3Service.available
        case "battery":
            return BatteryService.available
        case "volume":
            return AudioService.ready
        case "brightness":
            // A desktop has no backlight, the way it has no battery.
            return BrightnessService.available
        case "network":
            // Disconnected is still a reading.
            return true
        case "bluetooth":
            return BluetoothService.available
        case "stats":
            // The sampler runs from boot (shell.qml touches it).
            return true
        }
        return false
    }
}
