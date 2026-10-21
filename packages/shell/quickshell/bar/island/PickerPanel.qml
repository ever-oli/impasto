// ╭──────────────────────────────────────────────────────────────────────────╮
// │   P I C K E R   P A N E L                                                │
// │   the theme and wallpaper carousel, in the notch                         │
// ╰──────────────────────────────────────────────────────────────────────────╯
//
// The expanding-slice carousel is ported from Omarchy's image picker
// (shell/plugins/image-picker/ImagePicker.qml), MIT License,
// Copyright (c) David Heinemeier Hansson: the selected card opens wide, its
// neighbours stay as skewed slices that overlap, and moving slides them along.

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes

import "../../theme"
import "../../services"

ColumnLayout {
    id: root

    signal closed()

    spacing: 10

    readonly property int expandedWidth: 560
    readonly property int expandedHeight: 315
    readonly property int sliceWidth: 80
    readonly property int sliceHeight: 288
    readonly property int sliceSpacing: -22
    readonly property int skewOffset: 22

    Component.onCompleted: carousel.forceActiveFocus()
    // Closing without Enter (Escape, a click away) puts things back.
    Component.onDestruction: PickerService.revert()

    Item {
        id: carousel

        Layout.fillWidth: true
        Layout.preferredHeight: root.expandedHeight
        clip: true
        focus: true

        readonly property real itemStep: root.sliceWidth + root.sliceSpacing
        readonly property real previewX: (width - root.expandedWidth) / 2

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                PickerService.step(-1)
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                PickerService.step(1)
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                PickerService.keep()
                root.closed()
            } else if (event.key === Qt.Key_Escape && PickerService.filter !== "") {
                PickerService.refilter("")
            } else if (event.key === Qt.Key_Backspace) {
                PickerService.refilter(PickerService.filter.slice(0, -1))
            } else if (event.text.length === 1 && event.text >= " ") {
                PickerService.refilter(PickerService.filter + event.text)
            } else {
                event.accepted = false
                return
            }
            event.accepted = true
        }

        Repeater {
            model: PickerService.matching

            delegate: Item {
                id: card

                required property int modelData
                readonly property var entry: PickerService.items[modelData]
                readonly property int relative: PickerService.matching.indexOf(modelData)
                    - Math.max(0, PickerService.matching.indexOf(PickerService.index))
                readonly property bool selected: relative === 0

                x: selected ? carousel.previewX
                   : relative < 0 ? carousel.previewX + relative * carousel.itemStep
                   : carousel.previewX + root.expandedWidth + root.sliceSpacing + (relative - 1) * carousel.itemStep
                y: selected ? 0 : (root.expandedHeight - root.sliceHeight) / 2
                width: selected ? root.expandedWidth : root.sliceWidth
                height: selected ? root.expandedHeight : root.sliceHeight
                z: selected ? 100 : 50 - Math.abs(relative)

                Behavior on x { NumberAnimation { duration: Theme.durationMorph; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: Theme.durationMorph; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: Theme.durationMorph; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: Theme.durationMorph; easing.type: Easing.OutCubic } }

                Item {
                    id: mask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: "white"
                            strokeColor: "transparent"
                            startX: root.skewOffset; startY: 0
                            PathLine { x: card.width; y: 0 }
                            PathLine { x: card.width - root.skewOffset; y: card.height }
                            PathLine { x: 0; y: card.height }
                            PathLine { x: root.skewOffset; y: 0 }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: mask
                        maskThresholdMin: 0.3
                        maskSpreadAtMin: 0.3
                    }
                    Rectangle { anchors.fill: parent; color: Theme.islandSurface }
                    Image {
                        anchors.fill: parent
                        source: card.entry ? card.entry.image : ""
                        sourceSize.width: root.expandedWidth
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: card.selected ? 1 : 0.55
                        Behavior on opacity { NumberAnimation { duration: Theme.durationMorph } }
                    }
                }

                // The skewed outline: accent on the chosen card.
                Shape {
                    anchors.fill: parent
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: card.selected ? Theme.accent : Theme.islandBorder
                        strokeWidth: card.selected ? 2 : 1
                        startX: root.skewOffset; startY: 0
                        PathLine { x: card.width; y: 0 }
                        PathLine { x: card.width - root.skewOffset; y: card.height }
                        PathLine { x: 0; y: card.height }
                        PathLine { x: root.skewOffset; y: 0 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (card.selected) {
                            PickerService.keep()
                            root.closed()
                        } else
                            PickerService.step(card.relative)
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: {
                const it = PickerService.items[PickerService.index]
                const name = PickerService.matching.length ? (it ? it.label : "") : "No matches"
                return PickerService.filter !== "" ? `${name}   ·   “${PickerService.filter}”` : name
            }
            font.family: Theme.fontBar
            font.pixelSize: Theme.fs(16)
            color: Theme.text
        }
    }
    Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "←  →  preview     Enter  keep     Esc  revert     type to filter"
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeLabel
        color: Theme.textMuted
    }
}
