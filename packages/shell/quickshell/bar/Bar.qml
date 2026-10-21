// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B A R                                                                  │
// │   the bar · the island and its two sides, in three styles                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

import "../theme"
import "../services"
import "./widgets"
import "./modules"
import "./island"
import "./island/controls"
import "../components"

// The island in the middle and the two sides (`SettingsService.barZone`), in
// one of three styles:
//
//   grouped   the sides sit against the island and move aside as it grows
//   spread    the sides sit at the screen edges and hold still
//   island    everything in one capsule; the band morphs into whatever the
//             island opens
//
// Every detail opens in the island. The window is full-screen and never
// resizes; the input mask covers the bar and the island, and a focus grab
// closes the island on any click outside it.
//
// ── ONE PER SCREEN, ONE LIVE ────────────────────────────────────────────────
//
// There is one of these on every screen and exactly one of them is `live`:
// the screen being worked on. The live bar opens panels, holds the keyboard
// and shows whatever arrives; the rest are the same bar with the island at
// rest, which is what the other screens were already drawing. So the island
// crossing screens is a flag changing hands — nothing is built, nothing is
// torn down, and what is under the pointer is always the one that answers it.
PanelWindow {
    id: root
    CornerGuard {}

    // Named for the blur behind it (`windowrules.lua`), which shows only
    // through a ground that is not solid.
    WlrLayershell.namespace: "notch-bar"
    // A request for root rises over a full-screen window, which covers the
    // top layer; the bar goes back down once it is answered.
    // Open, the bar rises above the click catcher (on Top) below it.
    WlrLayershell.layer: island.expanded ? WlrLayer.Overlay : WlrLayer.Top
    // What is drawn here takes the island's glass (`Theme.surfaceIn`).
    readonly property bool glassy: true
    readonly property string groundStyle: Theme.surfaceStyle

    readonly property alias island: island

    // Whether this is the screen being worked on (`shell.qml`). Everything
    // below that touches state the whole shell shares is gated on it, because
    // every screen runs a copy of this file.
    required property bool live

    // Whether this one is drawn at all. The surface is on every screen
    // either way and the reserve is `BarReserve`'s, which never moves, so a
    // desk set to one bar costs no window a re-tile when a hand crosses.
    readonly property bool painted: root.live || SettingsService.barEverywhere

    // The compositor's focus follows the pointer, so by the time anything here
    // is clicked this screen is already the live one. Said outright for the
    // case that is not a journey across the screen: a pointer warped onto the
    // bar, or a compositor not set to follow it.
    signal claimed()

    // Distance from the screen edge to the ends. Matches the compositor's
    // outer gap so the bar lines up with tiled windows.
    readonly property int edgeMargin: SettingsService.barSideMargin

    // The lean fork has one layout, notch's "Spread": workspaces and the
    // launcher at the left edge, status and tray at the right edge, and the
    // island hanging from the top edge between them like a notch. The other
    // styles' flags stay as constants so their branches fold away.
    readonly property bool spread: true
    readonly property bool unified: false
    readonly property bool bare: SettingsService.barSides === "bare"
    readonly property bool grouped: false
    readonly property bool edgeToEdge: false

    readonly property bool holding: island.expanded

    // Maximum panel width. Spread, the sides stay put, so a panel gets the room
    // between them, unless it is wider than that: then they hide as grouped
    // sides do and it gets the whole bar, like everywhere else. A narrow
    // screen with a full bar would otherwise cut a panel's columns off.
    readonly property int roomBetween: root.width - 2 * (root.edgeMargin
        + Math.max(leftZone.width, rightZone.width) + Theme.capsuleSpacing)
    readonly property bool crowded: root.spread && island.expanded
        && island.panelSize.width > root.roomBetween
    readonly property int panelRoom: root.spread && !root.crowded
        ? root.roomBetween : root.width - 2 * root.edgeMargin

    // Computed rather than read from `island.x`, which comes from an anchor
    // resolved during layout and would lag a frame behind the width.
    readonly property real islandLeft: (root.width - island.width) / 2
    readonly property real islandRight: root.islandLeft + island.width

    // ── ONE CAPSULE ─────────────────────────────────────────────────────────
    //
    // A band a capsule tall, with the sides at its ends and the island in the
    // middle. When the island shows anything beyond the clock, the band morphs
    // into it and the sides are clipped by its closing ends.

    // Inset of each side from the band's edge, clear of the curve.
    readonly property int hostedInset: 12

    // The same at both ends, so the clock stays centred on the screen.
    readonly property real hostedSlot: root.unified
        ? root.hostedInset + Math.max(leftZone.width, rightZone.width) + Theme.capsuleSpacing * 2
        : 0

    // The island's width inside the band, animated on the island's clock so
    // the band widens with it. An OSD is wider than the clock and pushes the
    // sides out rather than overlapping them.
    property real restWidth: island.state.layer === island.state.layerOsd
        ? Math.max(ModuleService.restWidth, island.size.width)
        : ModuleService.restWidth

    Behavior on restWidth {
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    // The band at rest: the island's rest width plus a slot for each side.
    readonly property real bodyWidth: {
        if (!root.unified)
            return island.width
        if (root.edgeToEdge)
            return root.width - 2 * root.edgeMargin
        return root.restWidth + 2 * root.hostedSlot
    }

    readonly property real bandRow: Theme.capsuleHeight + island.notchPad

    // The island is showing more than the clock: a panel, a detail, the
    // glance or a notification. An OSD fits in the band and does not count.
    // In zen too, where the sides are away and the band is only the island.
    readonly property bool islandTaken: island.expanded
        || island.state.layer === island.state.layerSummary
        || island.state.layer === island.state.layerNotification
        || root.zen
    readonly property real bodyX: root.edgeToEdge
        ? root.edgeMargin : (root.width - root.bodyWidth) / 2

    // 0 at rest, 1 once the island has taken over the band. Animated on the
    // island's clock and curve so the two land together.
    property real bandInto: root.unified && root.islandTaken ? 1 : 0

    Behavior on bandInto {
        enabled: island.animated
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }

    // Interpolates from the rest width to the island's animated width as
    // `bandInto` goes from 0 to 1. Both run on the same curve, so this is one
    // morph with no clock of its own. The max() stops a spring curve's
    // overshoot from making the band narrower than the island.
    readonly property real bandWidth: root.edgeToEdge
        ? root.width
        : root.bandInto === 0 && !root.islandTaken
            ? root.bodyWidth
            : island.width + (root.bodyWidth - root.restWidth) * Math.max(0, 1 - root.bandInto)
    readonly property real bandX: (root.width - root.bandWidth) / 2

    // Attached (notch mode), only the island reaches the screen edge; the
    // sides stay capsules, centred on `laneY`.
    readonly property int islandTopMargin: SettingsService.notched ? 0 : Theme.barTopMargin

    // How far the glass's light from the top reaches down the notch
    // (`GlassSheen`), for the fillets that carry it on.
    readonly property real notchSheen: Theme.glass && !island.paper ? Theme.glassSheenDepth : 0

    // The line everything on the bar is centred on. Attached, the island
    // reaches the screen edge, so its centre is half a margin higher and the
    // sides move up to match.
    readonly property real laneY: SettingsService.notched
        ? Theme.barTopMargin / 2 : Theme.barTopMargin

    readonly property int collapsedHeight: Theme.barBand

    // Grouped, the sides make room for a module detail but hide for a panel.
    // In one capsule they hide whenever the island takes the band, and spread
    // only for a panel too wide to fit between them.
    readonly property bool sidesAway: root.edgeToEdge
        ? root.islandTaken && island.width / 2 > root.width / 2 - root.bodyX - root.hostedSlot
        : root.unified
        ? root.islandTaken
        : root.crowded
            || island.expanded && root.grouped && island.state.openPanel !== "module"

    anchors {
        top: true
        left: true
        right: true
    }

    // ── SURFACE ─────────────────────────────────────────────────────────────
    //
    // The layer surface is full-screen and never resizes: resizing it on every
    // animation frame makes the bar jitter, because the compositor applies the
    // new size a frame before or after the matching buffer. Input is handled by
    // the mask, which is cheap to change per frame.
    implicitHeight: root.screen.height

    // Input region: the bar's band, plus the island's shape (the band's, in
    // one capsule) with 12 px below it so the bottom edge still counts. The
    // whole screen only while the control centre is being arranged, since
    // blocks are dragged out of the tray card, which moves. Outside clicks are
    // left to the focus grab, so windows under an open panel stay usable.
    readonly property real shapeLeft: root.unified && !root.edgeToEdge
        ? Math.min(root.bandX, root.islandLeft) : root.islandLeft
    readonly property real shapeRight: root.unified && !root.edgeToEdge
        ? Math.max(root.bandX + root.bandWidth, root.islandRight) : root.islandRight
    readonly property bool wholeScreen: root.holding && ControlsService.editing

    // No input at all while desktop widgets are being arranged: dragging one
    // over the bar would move the pointer to this surface, and the desktop
    // would drop the widget. None either where nothing is painted.
    readonly property bool inert: !root.painted || root.away

    // Zen (`barHidden`): the bar waits above the screen and the island comes
    // down only for what it has to show — a panel, a notification, a
    // transient — with the sides left up there.
    readonly property bool zen: SettingsService.barHidden
    readonly property bool called: island.state.layer !== island.state.layerModules
        && island.state.layer !== island.state.layerSummary
    readonly property bool away: root.zen && !root.called

    mask: Region {
        width: root.inert ? 0 : root.width
        // In zen the band is empty, and only the island's shape takes input.
        height: root.inert ? 0
            : root.wholeScreen ? root.height
            : root.zen ? 0 : root.collapsedHeight

        Region {
            x: root.shapeLeft
            width: root.inert ? 0 : root.shapeRight - root.shapeLeft
            height: root.islandTopMargin + island.height + 12
        }
    }

    // The reserve is `BarReserve.qml`'s, one strip per screen that outlives
    // every bar, so a window holds still while the island changes screens.
    // Ignoring zones is what keeps the bar against the edge: a surface that
    // reserves nothing is pushed below whatever else reserved.
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"

    // ── FOCUS ───────────────────────────────────────────────────────────────
    //
    // On-demand keyboard focus plus a Hyprland focus grab while the island is
    // open. The grab keeps the keyboard here when the pointer crosses a window
    // (with `follow_mouse`, on-demand focus alone loses it), and a click on any
    // other surface clears it, which closes the island. The compositor
    // restores focus when the grab ends. Both stand down while the capture
    // surface is up, so an open panel waits under it instead of closing, and
    // while the session is locked, where a grab would keep the keyboard from
    // the other screens' lock.
    readonly property bool holdsKeyboard: root.live && island.expanded
        && !CaptureService.active

    // niri has no focus grab, so an open island takes the keyboard outright
    // and a transparent sheet under it catches the click that closes it.
    // focus-exclusive-ok: palette/island; niri has no focus grab (see above).
    WlrLayershell.keyboardFocus: root.holdsKeyboard
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    PanelWindow {
        screen: root.screen
        visible: root.holdsKeyboard
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "notch-catcher"
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.dismiss()
        }
    }

    HoverHandler {
        onHoveredChanged: if (hovered) root.claimed()
    }

    // ── OPENING A DETAIL ────────────────────────────────────────────────────
    //
    // Every activation on the bar comes through here
    // (`ModuleService.activate`). Clicking the open module again closes it; any
    // other replaces it.
    function activate(id: string): void {
        if (ModuleService.openId === id) {
            root.dismiss()
            return
        }

        // Always in the island, whatever the style or screen.
        ModuleService.openHost = "island"
        ModuleService.openId = id
        island.open("module")
    }

    function dismiss(): void {
        if (island.expanded)
            island.close()
        ModuleService.close()
    }

    // Every bar hears these; only the live one answers, since the panel opens
    // in its island.
    Connections {
        target: ModuleService
        enabled: root.live

        function onActivationRequested(id: string): void {
            root.activate(id)
        }

        // Bar buttons for panels (launcher, overview) toggle them.
        function onPanelToggled(panel: string): void {
            island.toggle(panel)
        }

        // The service closed the detail, e.g. the player went away.
        function onOpenIdChanged(): void {
            if (ModuleService.openId === "" && island.state.openPanel === "module")
                island.close()
        }
    }

    // Lets a bar button stay lit while its panel is open. One writer: the
    // live bar, since two bars binding the same property is a conflict.
    Binding {
        target: ModuleService
        property: "shownPanel"
        value: island.state.openPanel
        when: root.live
    }

    Connections {
        target: island.state

        // The island left the detail (Escape, a click outside, another panel).
        function onOpenPanelChanged(): void {
            if (island.state.openPanel !== "module" && ModuleService.openHost === "island")
                ModuleService.close()
        }
    }

    // Clicks on the bar outside the open island close it. The bar is inside
    // the focus grab, so the grab never sees them.
    MouseArea {
        anchors.fill: parent
        enabled: root.holding
        onClicked: root.dismiss()
    }

    // ── THE FACE ────────────────────────────────────────────────────────────
    //
    // Everything this bar draws. The surface stays on every screen whatever
    // `barEverywhere` says, so the reserve never moves and no window is ever
    // re-tiled by a hand crossing; what the setting decides is only whether
    // this is painted. Nothing is built or torn down either way.
    Item {
        id: face

        width: parent.width
        height: parent.height
        y: root.away ? -2 * root.collapsedHeight : 0
        visible: root.painted || face.opacity > 0
        opacity: root.painted ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
        }

        Behavior on y {
            NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
        }

        // ── SHADOW ──────────────────────────────────────────────────────────────
        //
        // The window shadow's numbers, on its own setting (`barShadow`). The
        // band, the island and the notch fillets touch, so they share one
        // flattened layer; separate shadows would draw a seam where they
        // overlap. The side capsules cast their own (`BarZone`).
        //
        // Cast from a copy of the shapes: layering the real bar would re-blur the
        // full-screen surface every time the clock or the spectrum repaints.
        //
        // The copy is grown by `Theme.shadowBarSpread` and blurred. MultiEffect's
        // `shadowEnabled` would also draw the source, showing the enlarged copy as
        // a black rim. `layer.effect` rather than a hidden `source` item, which
        // does not work inside a Repeater.
        Loader {
            anchors.fill: parent
            active: Theme.barShadowShown
            sourceComponent: shadowBody
        }

        Component {
            id: shadowBody

            // Under a ground that lets the screen through, the shapes are cut
            // out of their shadow, so it falls outside them and does not show
            // through.
            Item {
                layer.enabled: !Theme.solid
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskInverted: true
                    maskSource: cutout
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }

                Item {
                    id: cutout

                    anchors.fill: parent
                    visible: false
                    layer.enabled: !Theme.solid

                    Rectangle {
                        x: band.x
                        y: SettingsService.notched ? 0 : band.y
                        width: band.width
                        height: band.y + band.height - y
                        radius: band.radius
                        topLeftRadius: band.topLeftRadius
                        topRightRadius: band.topRightRadius
                        // Not `visible`: inside the hidden source it reads false
                        // and the band is left out of the mask.
                        opacity: root.unified && !root.edgeToEdge ? 1 : 0
                    }

                    // Attached, the shadow runs up to the screen's edge, so the
                    // cut does too while the island slides up into the notch.
                    Rectangle {
                        x: root.islandLeft
                        y: SettingsService.notched ? 0 : island.y
                        width: island.width
                        height: island.y + island.height - y
                        radius: island.radius
                        topLeftRadius: SettingsService.notched ? 0 : island.topLeftRadius
                        topRightRadius: SettingsService.notched ? 0 : island.topRightRadius
                        opacity: root.edgeToEdge ? 0 : 1
                    }

                    // The bezel cuts its whole silhouette out, corners and drop.
                    BezelShape {
                        width: root.width
                        height: root.height
                        opacity: root.edgeToEdge ? 1 : 0
                        bandHeight: band.height
                        corner: SettingsService.screenCorners ? Theme.screenRadius : 0
                        dropLeft: drop.x
                        dropRight: drop.x + drop.width
                        dropDepth: drop.visible ? drop.depth : 0
                        dropRadius: island.radius
                        color: "black"
                    }

                    Repeater {
                        model: [notchLeft, notchRight]

                        NotchFillet {
                            required property var modelData

                            x: modelData.x
                            y: modelData.y
                            width: modelData.width
                            height: modelData.height
                            opacity: modelData.visible && !root.edgeToEdge ? 1 : 0
                            mirrored: modelData.mirrored
                            color: "black"
                        }
                    }
                }

                Item {
                    id: caster

                    // Attached, the layer runs above the screen by the blur's reach and
                    // the shapes run up into it, so the blur reads the notch as going on
                    // past the edge and the shadow keeps its weight up to the top.
                    anchors.fill: parent
                    anchors.topMargin: -caster.pad
                    opacity: Theme.shadowOpacity

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1
                        blurMax: Theme.shadowBarRange - Theme.shadowBarSpread
                    }

                    readonly property int spread: Theme.shadowBarSpread
                    readonly property int pad: SettingsService.notched ? Theme.shadowBarRange : 0

                    Rectangle {
                        x: band.x - caster.spread
                        y: band.y - caster.spread
                        width: band.width + 2 * caster.spread
                        height: band.height + 2 * caster.spread + caster.pad
                        radius: band.radius + caster.spread
                        topLeftRadius: band.topLeftRadius > 0 ? band.topLeftRadius + caster.spread : 0
                        topRightRadius: band.topRightRadius > 0 ? band.topRightRadius + caster.spread : 0
                        visible: body.visible && !root.edgeToEdge
                        color: Theme.shadowColor
                    }

                    Rectangle {
                        x: root.islandLeft - caster.spread
                        y: island.y - caster.spread
                        width: island.width + 2 * caster.spread
                        height: island.height + 2 * caster.spread + caster.pad
                        radius: island.radius + caster.spread
                        topLeftRadius: island.topLeftRadius > 0 ? island.topLeftRadius + caster.spread : 0
                        topRightRadius: island.topRightRadius > 0 ? island.topRightRadius + caster.spread : 0
                        visible: !root.edgeToEdge
                        color: Theme.shadowColor
                    }

                    // The bezel casts from its whole silhouette, moved down by
                    // the spread: its top and sides are the screen's edges.
                    BezelShape {
                        y: caster.pad + caster.spread
                        width: root.width
                        height: root.height
                        visible: root.edgeToEdge && body.visible
                        bandHeight: band.height
                        corner: SettingsService.screenCorners ? Theme.screenRadius : 0
                        dropLeft: drop.x
                        dropRight: drop.x + drop.width
                        dropDepth: drop.visible ? drop.depth : 0
                        dropRadius: island.radius
                        color: Theme.shadowColor
                    }

                    // The fillets grown by the spread as the rectangles are: the same
                    // centre, a radius short by the spread, and a strip for the top
                    // edge moved up by it. Past the tip the strip runs on along the
                    // edge and fades out, or the shadow down the curve stops square
                    // where the curve meets the edge.
                    Repeater {
                        model: [notchLeft, notchRight]

                        Item {
                            required property var modelData

                            x: modelData.x
                            y: caster.pad + modelData.y
                            width: modelData.width
                            height: modelData.height
                            visible: modelData.visible && !root.edgeToEdge
                            opacity: modelData.opacity

                            // Solid only: along the edge of the screen a
                            // see-through notch would show it as a stain.
                            Rectangle {
                                y: -caster.pad
                                visible: Theme.solid
                                width: parent.width
                                height: caster.pad + caster.spread
                                color: Theme.shadowColor
                            }

                            Rectangle {
                                id: tail

                                readonly property bool mirrored: parent.modelData.mirrored

                                x: mirrored ? -width : parent.width
                                y: -caster.pad
                                visible: Theme.solid
                                width: parent.width * 2
                                height: caster.pad + caster.spread
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: tail.mirrored ? "transparent" : Theme.shadowColor }
                                    GradientStop { position: 1; color: tail.mirrored ? Theme.shadowColor : "transparent" }
                                }
                            }

                            NotchFillet {
                                x: parent.modelData.mirrored ? 0 : caster.spread
                                y: caster.spread
                                width: Math.max(0, parent.width - caster.spread)
                                height: Math.max(0, parent.height - caster.spread)
                                mirrored: parent.modelData.mirrored
                                color: Theme.shadowColor
                            }
                        }
                    }

                }
            }
        }

        // ── BAND ────────────────────────────────────────────────────────────────
        //
        // Two shapes of the same black: the band, and the island on top of it.
        // Neither has an outline, which would draw the seam between them.
        Item {
            id: body

            anchors.fill: parent
            visible: root.unified

            // Grows with the island; at rest both share height and radius.
            Rectangle {
                id: band

                x: root.bandX
                y: root.islandTopMargin
                width: root.bandWidth
                height: root.edgeToEdge ? root.bandRow : Math.max(root.bandRow, island.height)
                radius: island.radius
                topLeftRadius: SettingsService.notched ? 0 : band.radius
                topRightRadius: SettingsService.notched ? 0 : band.radius
                // Edge to edge, the screen's corners round it off below, so
                // its own ends come in square and round as it draws in.
                bottomLeftRadius: root.edgeToEdge ? 0 : band.radius
                bottomRightRadius: root.edgeToEdge ? 0 : band.radius
                color: island.surfaceColor

                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                // The band is the ground here, so it carries the glass.
                GlassSheen {
                    shape: band
                    visible: Theme.glass && !island.paper
                    edges: !SettingsService.notched
                }

                // Clicking the band opens the island. The sides sit above it and
                // take their own clicks.
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: island.open("controls")
                }
            }

            // The screen's top corners, under the band's ends, when the screen
            // is rounded.
            Repeater {
                model: root.edgeToEdge && SettingsService.screenCorners ? [0, 90] : []

                ScreenCorner {
                    required property int modelData

                    x: modelData === 0 ? band.x : band.x + band.width - width
                    y: band.y + band.height
                    turn: modelData
                    color: island.surfaceColor
                }
            }

            // Edge to edge, the part of the island below the band, in the
            // band's ground, and the two fillets joining it to the band.
            // Starts under the band, not behind it, so a see-through ground is
            // not laid twice. Its curves, and the fillets', never run deeper
            // than the drop itself: a few pixels out of the band is a few
            // pixels of flat edge, not two bumps.
            Rectangle {
                id: drop

                readonly property real depth: island.y + island.height - (band.y + band.height)

                visible: root.edgeToEdge && drop.depth > 0
                x: root.islandLeft
                y: band.y + band.height
                width: island.width
                height: drop.depth
                radius: Math.min(island.radius, drop.depth)
                topLeftRadius: 0
                topRightRadius: 0
                color: band.color
            }

            Repeater {
                model: drop.visible ? [true, false] : []

                NotchFillet {
                    required property bool modelData

                    width: Math.min(Theme.radiusNotch * 2, drop.depth)
                    height: width
                    x: modelData ? drop.x - width : drop.x + drop.width
                    y: drop.y
                    mirrored: modelData
                    color: band.color
                }
            }
        }

        DynamicIsland {
            id: island

            active: root.live
            hosted: root.unified
            roomForPanel: root.panelRoom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.islandTopMargin
            // Edge to edge, out of the band only as far as it drops.
            bottomLeftRadius: root.edgeToEdge ? Math.max(0, Math.min(island.radius, drop.depth)) : island.radius
            bottomRightRadius: root.edgeToEdge ? Math.max(0, Math.min(island.radius, drop.depth)) : island.radius

            Behavior on anchors.topMargin {
                enabled: island.animated
                NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
            }
        }

        // The island's hairline, drawn round the band once it takes the island's
        // shape. Above both, since the opaque island covers the band's own edge.
        // None at rest and none in paper mode.
        Rectangle {
            id: outline

            x: band.x
            y: band.y
            width: band.width
            height: band.height
            radius: band.radius
            topLeftRadius: band.topLeftRadius
            topRightRadius: band.topRightRadius
            visible: root.unified && !island.paper && !SettingsService.notched
            color: "transparent"
            border.width: 1
            border.color: root.islandTaken ? Theme.islandRim : "transparent"

            Behavior on border.color { ColorAnimation { duration: Theme.durationMedium } }
        }

        // Notch fillets flaring from the island's edges out to the screen edge.
        // In one capsule they follow whichever edge is further out, the band's or
        // the island's, since a spring curve can push the island past the band.
        NotchFillet {
            id: notchLeft

            x: (root.unified ? Math.min(root.bandX, root.islandLeft) : root.islandLeft) - width
            anchors.top: parent.top
            visible: SettingsService.notched
            mirrored: true
            color: island.surfaceColor
            sheenReach: root.notchSheen
        }

        NotchFillet {
            id: notchRight

            x: root.unified ? Math.max(root.bandX + root.bandWidth, root.islandRight) : root.islandRight
            anchors.top: parent.top
            visible: SettingsService.notched
            color: island.surfaceColor
            sheenReach: root.notchSheen
        }

        component BareShadow: MultiEffect {
            shadowEnabled: true
            blurMax: Theme.barShadowReach
            shadowBlur: 1
            shadowVerticalOffset: 1
            shadowColor: Theme.barShadow
        }

        // ── SIDES ───────────────────────────────────────────────────────────────
        //
        // Grouped, the sides are anchored to the island's animated edges, so they
        // move aside on its clock with nothing else to animate. Spread, they stay
        // in the corners. In one capsule they are the band's ends; while it morphs
        // they are clipped by it and fade out faster than it closes.
        Item {
            id: sides

            readonly property bool cropped: root.unified && root.bandInto > 0

            x: sides.cropped ? band.x : 0
            y: 0
            width: sides.cropped ? band.width : root.width
            height: root.height
            clip: sides.cropped
            opacity: root.zen ? 0 : 1
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.durationFast; easing.type: Theme.easing }
            }

            // On the wallpaper, the sides are cast twice: the shadow's own
            // shadow is what makes a thin dark edge dense enough to hold white
            // off a light picture, which one blurred copy of a small glyph is
            // not.
            layer.enabled: root.bare
            layer.effect: BareShadow {}

            BarZone {
                id: leftZone

                entries: SettingsService.barItems("left")
                chromeless: root.unified || root.bare
                overWallpaper: root.bare

                layer.enabled: root.bare
                layer.effect: BareShadow {}
                x: (root.unified ? root.bodyX + root.hostedInset
                    : root.spread ? root.edgeMargin
                    : root.islandLeft - Theme.capsuleSpacing - leftZone.width) - sides.x
                y: root.laneY
                opacity: root.sidesAway ? 0 : 1
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.unified && root.sidesAway ? Theme.durationFast : Theme.durationMedium
                        easing.type: Theme.easing
                    }
                }
            }

            BarZone {
                id: rightZone

                entries: SettingsService.barItems("right")
                chromeless: root.unified || root.bare
                overWallpaper: root.bare

                layer.enabled: root.bare
                layer.effect: BareShadow {}
                x: (root.unified ? root.bodyX + root.bodyWidth - root.hostedInset - rightZone.width
                    : root.spread ? root.width - root.edgeMargin - rightZone.width
                    : root.islandRight + Theme.capsuleSpacing) - sides.x
                y: root.laneY
                opacity: root.sidesAway ? 0 : 1
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.unified && root.sidesAway ? Theme.durationFast : Theme.durationMedium
                        easing.type: Theme.easing
                    }
                }
            }
        }
    }
}
