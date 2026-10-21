// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D Y N A M I C   I S L A N D                                            │
// │   morphing centre capsule · hosts every island layer                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import Quickshell
import "../../theme"
import "../../services"
import "../island"
import "../modules"
import "../../components"

// One capsule that changes shape to fit whatever it shows. IslandState picks
// the layer, this sizes the capsule for it, and a Loader swaps the contents;
// the shape animates while the contents cross-fade.
Rectangle {
    id: root

    // Settings is a separate window owned by `shell.qml`; the request is
    // passed up.
    signal settingsRequested()

    readonly property alias state: islandState
    readonly property bool expanded: islandState.expanded

    // The island is drawn on every screen; one of them is the one being
    // worked on (`Bar.live`) and the rest are this shape at rest. Only the
    // live one opens anything, and `IslandState` is where that is enforced.
    property bool active: true

    // While a note is open the island is the note: paper to the edge, with no
    // rim or padding.
    readonly property bool paper: false
    readonly property color paperColor: "transparent"
    // A module detail brings its own margins.
    readonly property int panelPad: root.paper
        ? 0 : (islandState.openPanel === "module" ? Theme.cardInset : Theme.panelPadding)

    // For the bar: attached, the notch fillets have to light with the island.
    readonly property bool hovered: hover.hovered
    // Lit where a click does something: the clock at rest. Not at rest in the
    // one-capsule style, where the band and the island are one shape and
    // cannot light separately; not the glance, which is drawn on the black
    // with a player's controls of its own; not over panels, which have their
    // own controls; and not while `landing` from one.
    readonly property bool lit: hover.hovered && !root.landing
        && islandState.layer === islandState.layerModules && !root.hosted
    // Solid, a floating island at rest is a shade off the black; on glass it
    // is the capsules' ground, since a lighter veil reads as another material.
    readonly property color surfaceColor: {
        if (!Theme.solid)
            return root.lit ? Theme.islandGroundLit : Theme.islandGround
        if (root.lit)
            return Theme.islandSurfaceHover
        return SettingsService.notched ? Theme.islandGround : Theme.islandSurface
    }

    // ── HOSTED ──
    //
    // In the one-capsule style the bar draws a band behind the island and puts
    // the sides on it. This flag only changes what the island paints at rest;
    // once it shows more than the clock, the band morphs into it
    // (`Bar.islandTaken`).
    property bool hosted: false

    // Width left between the bar's ends (`Bar.panelRoom`). Unconstrained by
    // default, so an island without a bar gets the size it asks for.
    property int roomForPanel: 100000


    // ── PANEL SIZES ──
    //
    // Declared rather than measured: the island has to reach its final shape
    // before the panel inside it is loaded.
    readonly property var panelSizes: ({
        controls:   { width: ControlsService.panelWidth, height: ControlsService.panelHeight },
        launcher:   { width: LauncherService.panelWidth,
                      height: LauncherService.panelHeight },
        // The control centre's volume, opened out.
        sound:      { width: AudioService.panelWidth, height: AudioService.panelHeight },
        microphone: { width: AudioService.panelWidth, height: AudioService.microphoneHeight },
        bluetooth:  { width: 420,  height: 500 },
        session:    { width: 720,  height: 180 },
        // A program asking for root (`PolkitService`).
        auth:       { width: 460,  height: 236 },
        // The key sheet's columns come from the compositor's bind list.
        keys:       { width: ShortcutService.sheetWidth, height: ShortcutService.sheetHeight },
        module:     root.moduleSize,
        tray:       { width: TrayService.menuWidth, height: TrayService.menuHeight },
        t3:         { width: T3Service.panelWidth, height: T3Service.panelHeight },
        picker:     { width: 900, height: 400 },
        // The radar, big.
        notchstorm: { width: 900, height: 560 },
        // Rows of posters, the big one at the top.
        anime:      { width: 1040, height: 640 },
    })


    // A module's detail, sized from the catalogue.
    readonly property var moduleSize: ModuleService.openSize(ModuleService.openId)

    readonly property var panelSize:
        root.panelSizes[islandState.openPanel] ?? root.panelSizes.controls

    // The bar's limit: the whole bar, or a spread bar's room between its
    // sides, which hide instead for a panel wider than that (`Bar.crowded`).
    readonly property int panelWidth: Math.min(root.panelSize.width, root.roomForPanel)
    readonly property int panelHeight: root.panelSize.height

    // One entry per layer: the capsule's size and the padding inside it.
    readonly property var layerSizes: ({
        modules:      { width: ModuleService.restWidth, height: Theme.capsuleHeight, padding: 0 },
        summary:      { width: ModuleService.summaryWidth,
                        height: ModuleService.summaryHeight,
                        padding: 0 },
        osd:          { width: 260, height: Theme.capsuleHeight, padding: 10 },
        notification: { width: NotificationService.toastWidth,
                        height: NotificationService.toastHeight,
                        padding: NotificationService.toastPadding },
        panel:        { width: root.panelWidth, height: root.panelHeight, padding: Theme.panelPadding }
    })

    readonly property var size: root.layerSizes[islandState.layer] ?? root.layerSizes.modules

    // Off for the first frame so the island does not animate in from nothing
    // at startup.
    property bool animated: false

    // Attached, only the shape reaches up to the screen edge; the contents keep
    // their padding, so nothing already drawn moves.
    readonly property int notchPad: SettingsService.notched ? Theme.barTopMargin : 0

    readonly property var layerComponents: ({
        modules: restLayer,
        summary: summaryLayer,
        osd: osdLayer,
        notification: notificationLayer
    })

    readonly property var panelComponents: ({
        controls: controlsPanel,
        launcher: launcherPanel,
        sound: soundDetail,
        microphone: microphoneDetail,
        bluetooth: bluetoothDetail,
        session: sessionPanel,
        auth: authPanel,
        keys: keysPanel,
        t3: t3Panel,
        picker: pickerPanel,
        notchstorm: notchstormPanel,
        anime: animePanel,
        module: moduleDetail,
        tray: trayMenu
    })

    function open(panel: string): void {
        islandState.open(panel)
    }

    function close(): void {
        islandState.close()
    }

    // Shortcuts toggle: the same key opens and closes.
    function toggle(panel: string): void {
        if (islandState.openPanel === panel)
            root.close()
        else
            root.open(panel)
    }

    // Under everything the island holds; a note's paper is not glass.
    GlassSheen {
        shape: root
        visible: Theme.glass && !root.paper && !root.hosted
        edges: !SettingsService.notched
    }

    IslandState {
        id: islandState

        active: root.active
    }

    // ── GLANCE ──
    //
    // Hovering opens the summary after a short intent delay, leaving closes it
    // after a grace period, and a click opens the control centre. 80 ms is
    // under a perceptible wait but longer than a moving pointer spends
    // crossing the clock; the grace period stops a pointer on the edge from
    // flapping it open and shut.
    //
    // Re-entering cancels the close. A click holds the glance off until the
    // pointer leaves, so a just-dismissed panel is not replaced by the summary.
    // A HoverHandler rather than the MouseArea because it stays hovered over
    // the sides' own click targets.
    HoverHandler {
        id: hover
    }

    property bool summaryHeld: false

    readonly property bool restBusy: islandState.layer === islandState.layerModules
        && (collapsedLoader.item?.busy ?? false)

    readonly property bool canSummarise: false && SettingsService.islandSummary
        && root.active
        && !root.summaryHeld
        && !root.landing
        && ModuleService.openId === ""
        && (islandState.layer === islandState.layerModules
            || islandState.layer === islandState.layerSummary)

    onCanSummariseChanged: {
        if (!root.canSummarise)
            islandState.summary = false
    }

    onRestBusyChanged: {
        if (root.restBusy)
            dwell.stop()
        else if (hover.hovered && !islandState.summary)
            dwell.restart()
    }

    Timer {
        id: dwell
        interval: 80
        onTriggered: {
            if (hover.hovered && root.canSummarise && !root.restBusy)
                islandState.summary = true
        }
    }

    // Set while the island shrinks back to rest from a panel, detail,
    // notification or OSD: opening the glance mid-morph would turn the shape
    // round halfway. The glance's own close is not a landing, since re-entering
    // should reverse it.
    property bool landing: false
    property string lastLayer: islandState.layerModules

    Connections {
        target: islandState

        function onLayerChanged(): void {
            if (islandState.layer === islandState.layerModules
                    && root.lastLayer !== islandState.layerSummary
                    && root.lastLayer !== islandState.layerModules) {
                root.landing = true
                Qt.callLater(root.checkLanded)
            }
            root.lastLayer = islandState.layer
        }
    }

    onSettledChanged: root.checkLanded()

    // Also called deferred: with motion off `settled` never changes, and the
    // glance would stay blocked.
    function checkLanded(): void {
        if (!root.landing || !root.settled || islandState.layer !== islandState.layerModules)
            return
        root.landing = false
        if (hover.hovered && !islandState.summary)
            dwell.restart()
    }

    Timer {
        id: grace
        interval: 260
        onTriggered: {
            if (!hover.hovered)
                islandState.summary = false
        }
    }

    Connections {
        target: hover

        function onHoveredChanged(): void {
            if (hover.hovered) {
                grace.stop()
                if (!islandState.summary)
                    dwell.restart()
            } else {
                dwell.stop()
                grace.restart()
                root.summaryHeld = false
            }
        }
    }

    width: root.size.width
    height: root.size.height + root.notchPad

    // True once the morph has reached its target size.
    readonly property bool settled: root.width === root.size.width
        && root.height === root.size.height + root.notchPad
    // A pill at capsule height, a rounded card once a module makes it taller.
    radius: islandState.expanded && islandState.openPanel !== "module"
        ? Theme.radiusLarge
        : Math.min(root.height / 2, Theme.radiusLarge + 4)

    // In one capsule the band behind is the ground and covers the island
    // whole; a see-through island painted over it would double the glass.
    color: {
        if (root.paper)
            return root.paperColor
        if (root.hosted && !Theme.solid)
            return "transparent"
        return islandState.expanded ? Theme.islandGround : root.surfaceColor
    }
    border.color: Theme.islandRim

    // No hairline in the one-capsule style: at rest the island's edges run
    // through the band's interior, and while growing the band is the outer
    // edge. `Bar.qml` draws the outline over both. Attached, `Bar.qml` draws
    // it too, down the fillets and open along the screen edge.
    readonly property bool inBand: root.hosted
    border.width: root.paper || root.inBand || SettingsService.notched ? 0 : 1
    clip: true

    // Attached, the upper corners go square: the curve is added outside the
    // island by NotchFillet, flaring away from it rather than cutting into it.
    topLeftRadius: SettingsService.notched ? 0 : root.radius
    topRightRadius: SettingsService.notched ? 0 : root.radius

    Behavior on topLeftRadius {
        enabled: root.animated
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }
    Behavior on topRightRadius {
        enabled: root.animated
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }

    Component.onCompleted: root.animated = true

    // One animated value per axis; everything the bar draws around the island
    // (band, sides, fillets) is derived from it. None of those gets its own
    // Behavior: animating a sum whose other term changes every frame restarts
    // on every change and settles late.
    Behavior on width {
        enabled: root.animated
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }
    Behavior on height {
        enabled: root.animated
        NumberAnimation { duration: Theme.durationMorph; easing.type: Theme.easing }
    }
    Behavior on radius {
        enabled: root.animated
        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
    }
    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    // ── COLLAPSED ──

    // An Item, not a second rounded rectangle, so the hover light and the
    // click target cover the whole island.
    Item {
        id: capsule

        anchors.fill: parent
        opacity: islandState.expanded ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            enabled: root.animated
            NumberAnimation { duration: 110; easing.type: Theme.easing }
        }

        // Declared before the layer so the layer's own controls (the media
        // play button) get clicks first; this still gets hover and the rest.
        MouseArea {
            id: capsuleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.summaryHeld = true
                root.open("launcher")
            }
        }

        Item {
            id: middle

            anchors.fill: parent

            // Fades each new layer in.
            Loader {
                id: collapsedLoader

                anchors.fill: parent
                // Attached, the contents are centred in the full height,
                // matching the bar's raised midline (`Bar.laneY`).
                anchors.topMargin: root.size.padding + root.notchPad / 2
                anchors.leftMargin: root.size.padding
                anchors.rightMargin: root.size.padding
                anchors.bottomMargin: root.size.padding + root.notchPad / 2
                sourceComponent: root.layerComponents[islandState.layer] ?? restLayer

                onSourceComponentChanged: fade.restart()

                NumberAnimation {
                    id: fade
                    target: collapsedLoader
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.durationFast
                    easing.type: Theme.easing
                }
            }
        }
    }

    // ── EXPANDED ──

    // A FocusScope, so one Escape handler covers every panel. A plain Item
    // holding focus here would take it from the launcher's search field; a
    // scope delegates inward, so the field keeps the keyboard and unhandled
    // keys bubble up here. Nothing inside sets `focus: true` for the same
    // reason: on the Loader it takes focus from the field a frame after the
    // field asks for it.
    FocusScope {
        id: panelScope

        anchors.fill: parent
        focus: islandState.expanded

        Keys.onEscapePressed: root.close()

        Loader {
            id: panelLoader

            anchors.fill: parent
            anchors.topMargin: root.panelPad + root.notchPad
            anchors.leftMargin: root.panelPad
            anchors.rightMargin: root.panelPad
            anchors.bottomMargin: root.panelPad
            active: islandState.expanded
            sourceComponent: root.panelComponents[islandState.openPanel] ?? controlsPanel
            opacity: islandState.expanded ? 1 : 0

            Behavior on opacity {
                enabled: root.animated
                NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
            }
        }
    }

    // Swallows clicks on the panel background so they do not reach the
    // dismiss area covering the rest of the bar. On the control centre's
    // margin the right button arranges it, as it does between its blocks.
    MouseArea {
        anchors.fill: parent
        enabled: islandState.expanded
        acceptedButtons: Qt.AllButtons
        z: -1
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton && islandState.openPanel === "controls")
                ControlsService.edit(!ControlsService.editing)
        }
    }

    // ── LAYERS ──

    Component {
        id: restLayer
        IslandRest {}
    }

    Component {
        id: summaryLayer
        Item {}
    }

    Component {
        id: moduleDetail
        DetailFace {
            moduleId: ModuleService.openId
            onClosed: root.close()
        }
    }

    Component {
        id: notificationLayer
        NotificationLayer {}
    }

    Component {
        id: osdLayer
        OsdLayer {
            icon: islandState.transientIcon
            label: islandState.transientLabel
            progress: islandState.transientProgress
        }
    }

    Component {
        id: controlsPanel
        ControlsPanel {
            onClosed: root.close()
            onPanelRequested: panel => root.open(panel)
            // Settings is a window: close the island, then pass it up.
            onSettingsRequested: {
                root.close()
                root.settingsRequested()
            }
        }
    }


    Component {
        id: pickerPanel
        PickerPanel { onClosed: root.close() }
    }

    Component {
        id: notchstormPanel
        NotchstormPanel { onClosed: root.close() }
    }

    Component {
        id: animePanel
        AnimePanel { onClosed: root.close() }
    }

    Component {
        id: launcherPanel
        LauncherPanel {
            onClosed: root.close()
            // `>` lists every panel, like the control centre.
            onPanelRequested: panel => root.open(panel)
            onSettingsRequested: {
                root.close()
                root.settingsRequested()
            }
        }
    }

    // Wi-Fi and Bluetooth are panels of their own rather than views inside the
    // control centre, because a panel's size is keyed on `openPanel`.

    Component {
        id: soundDetail
        SoundDetail { onBack: root.open("controls") }
    }

    Component {
        id: microphoneDetail
        MicrophoneDetail { onBack: root.open("controls") }
    }



    Component {
        id: bluetoothDetail
        BluetoothDetail { onBack: root.open("controls") }
    }

    Component {
        id: trayMenu
        TrayMenuPanel { onClosed: root.close() }
    }



    Component {
        id: sessionPanel
        SessionPanel { onClosed: root.close() }
    }

    Component {
        id: authPanel
        AuthPanel {}
    }









    Component {
        id: t3Panel
        T3Panel { onClosed: root.close() }
    }

    Component {
        id: keysPanel
        KeysPanel { onClosed: root.close() }
    }


    // A module asking for a panel: the arcade's detail opening the arcade.
    Connections {
        target: ModuleService

        function onPanelRequested(panel: string): void {
            root.open(panel)
        }
    }
}
