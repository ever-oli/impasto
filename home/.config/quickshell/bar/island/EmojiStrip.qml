// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   E M O J I   S T R I P                                                  │
// │   the emoji mode's nine groups and the recent picks, each a glyph        │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"

RowLayout {
    id: root

    // Tab steps the groups with the keyboard; a click is the pointer's way.
    // The panel keeps the focus: after a click the search field takes it back.
    signal chosen()

    visible: LauncherService.showsStrip
    spacing: 2

    Repeater {
        model: EmojiService.groups

        delegate: Rectangle {
            id: chip

            required property var modelData
            readonly property bool chosen: EmojiService.group === chip.modelData.id

            Layout.preferredWidth: LauncherService.stripHeight + 2
            Layout.preferredHeight: LauncherService.stripHeight
            radius: Theme.radiusSmall
            color: chip.chosen || chipMouse.containsMouse
                ? Theme.surfaceHoverIn(QsWindow.window) : "transparent"

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }

            Text {
                anchors.centerIn: parent
                text: chip.modelData.mark
                font.family: Theme.fontBar
                font.pixelSize: Theme.fs(16)
                opacity: chip.chosen ? 1 : 0.6
            }

            MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    EmojiService.group = chip.modelData.id
                    root.chosen()
                }
            }
        }
    }

    Item { Layout.fillWidth: true }
}
