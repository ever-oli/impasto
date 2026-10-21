// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T C H S T O R M   P A N E L                                        │
// │   live radar, where the weather is                                         │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// The radar, big, with the facts around it: the station, the product, and
// how old the frame is. The picture is the engine's own sweep, drawn by it
// and handed over as a file.
Item {
    id: root

    signal closed()

    Keys.onEscapePressed: root.closed()

    readonly property bool live: AnimeService && false
    readonly property string where: NotchstormService.site ? NotchstormService.site : "—"
    readonly property string age: {
        if (NotchstormService.age <= 0)
            return NotchstormService.freshness
        const minutes = Math.floor(NotchstormService.age / 60)
        return minutes < 1 ? "just now" : minutes + " min old"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.centreGutter

        // The heading: where the radar is pointed.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "Notchstorm"
                font.family: Theme.fontBar
                font.pixelSize: 22
                font.bold: true
                color: Theme.text
            }

            Text {
                text: root.where + " · " + NotchstormService.product
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.accent
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            PillButton {
                text: root.age
                icon: "󰅐"
                active: NotchstormService.freshness === "live"
            }

            IconButton {
                icon: "󰅐"
                onClicked: NotchstormService.refresh()
            }
        }

        // The sweep.
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusMedium
            color: Theme.surfaceIn(QsWindow.window)
            border.color: Theme.borderIn(QsWindow.window)
            border.width: 1
            clip: true

            Image {
                id: sweep

                anchors.fill: parent
                anchors.margins: 6
                source: NotchstormService.texture
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                // A sweep that has not arrived yet leaves a mark, not a hole.
                opacity: NotchstormService.texture ? 1 : 0
            }

            // Nothing yet: say so, rather than showing an empty card.
            Column {
                anchors.centerIn: parent
                spacing: 6
                visible: !NotchstormService.texture

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰅐"
                    font.family: Theme.fontMono
                    font.pixelSize: 34
                    color: Theme.textMuted
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: NotchstormService.freshness === "loading" ? "the sweep is coming…" : "no radar here yet"
                    font.family: Theme.fontBar
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }
            }
        }
    }
}
