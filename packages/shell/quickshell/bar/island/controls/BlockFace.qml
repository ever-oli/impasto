// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B L O C K   F A C E                                                    │
// │   maps a block id and size to its card                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

// Registry of control centre blocks: an id in, a card out. The card is told
// its cell count so blocks with several faces can pick one. A new block needs
// a row in `ControlsService.catalogue` and one here.
Item {
    id: root

    property string blockId: ""
    property string size: "2x2"

    // The grid row this face draws; only the toggles block needs it.
    property string blockKey: ""

    // Nothing is built for a block that is not on the grid.
    property bool active: true

    signal panelRequested(string panel)
    signal settingsRequested()
    signal dismissed()

    readonly property var shape: ControlsService.parse(root.size)

    readonly property var components: ({
        toggles: togglesBlock,
        volume: volumeBlock,
        textsize: textSizeBlock,
        notifications: notificationsBlock,
        clock: clockBlock,
        session: sessionBlock,
        shortcuts: shortcutsBlock,
        layouts: layoutsBlock
    })

    Loader {
        anchors.fill: parent
        active: root.active
        sourceComponent: root.components[root.blockId] ?? null
    }

    Component {
        id: togglesBlock
        TogglesBlock {
            blockKey: root.blockKey
            cols: root.shape.cols
            rows: root.shape.rows
            onPanelRequested: panel => root.panelRequested(panel)
            onDismissed: root.dismissed()
        }
    }

    // Sliders are shorter than a cell and centred in it.
    Component {
        id: volumeBlock
        Item {
            SliderRow {
                anchors.centerIn: parent
                width: parent.width
                height: Math.min(parent.height, 48)
                icon: AudioService.icon
                value: AudioService.volume
                available: AudioService.ready
                dimmed: AudioService.muted
                expandable: true
                onMoved: value => AudioService.setVolume(value)
                onIconClicked: AudioService.toggleMute()
                onExpandClicked: root.panelRequested("sound")
            }
        }
    }

    Component {
        id: textSizeBlock
        Item {
            SliderRow {
                anchors.centerIn: parent
                width: parent.width
                height: Math.min(parent.height, 48)
                icon: "󰛂"
                unit: " pt"
                from: FontSizeService.from
                to: FontSizeService.to
                value: FontSizeService.value
                onMoved: value => FontSizeService.preview(value)
                onIconClicked: Quickshell.execDetached(["qs", "ipc", "call", "fontsize", "open"])
            }
        }
    }

    Component {
        id: sessionBlock
        ButtonsBlock {
            kind: "session"
            onRan: root.dismissed()
        }
    }

    Component {
        id: shortcutsBlock
        ButtonsBlock {
            kind: "shortcuts"
            blockKey: root.blockKey
            onPanelRequested: panel => root.panelRequested(panel)
            onSettingsRequested: root.settingsRequested()
        }
    }

    Component {
        id: notificationsBlock
        NotificationList {}
    }

    Component {
        id: layoutsBlock
        LayoutsBlock {
            cols: root.shape.cols
            rows: root.shape.rows
        }
    }

    Component {
        id: clockBlock
        ClockBlock {
            cols: root.shape.cols
            rows: root.shape.rows
        }
    }

}
