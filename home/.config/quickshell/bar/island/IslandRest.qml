// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I S L A N D   R E S T                                                  │
// │   resting island · the clock and running activities                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Widgets

import "../../theme"
import "../../services"
import "../../components"
import "../modules"

// The island at rest: the clock in the middle, with a countdown or
// track either side while one is running (one item split across both sides,
// mark leading and figure trailing, or one item per side).
Item {
    id: root

    readonly property var activities: ModuleService.activities
    readonly property bool split: root.activities.length === 1

    // A side under the pointer holds the glance off, so a click on the dot
    // never lands on a summary that opened under it.
    readonly property bool busy: leading.hovered || trailing.hovered

    // What did not fit takes a slot at the trailing end; the time keeps
    // the middle of the rest.
    readonly property int spare: ModuleService.overflow > 0 ? ModuleService.overflowWidth : 0

    ClockModule {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -root.spare / 2
        width: root.activities.length > 0 ? ModuleService.clockCore : parent.width
        height: Theme.capsuleHeight
    }

    Segment {
        id: leading

        anchors.left: parent.left
        width: ModuleService.activitySide
        height: parent.height
        visible: root.activities.length > 0
        activityId: root.activities[0] ?? ""
        part: root.split ? "mark" : "both"
    }

    Segment {
        id: trailing

        anchors.right: parent.right
        anchors.rightMargin: root.spare
        width: ModuleService.activitySide
        height: parent.height
        visible: root.activities.length > 0
        activityId: root.split ? (root.activities[0] ?? "") : (root.activities[1] ?? "")
        part: root.split ? "figure" : "both"
    }

    // How many more are running than fit; the glance lists them.
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: ModuleService.overflow > 0
        width: ModuleService.overflowWidth - 6
        height: 18
        radius: height / 2
        color: Theme.islandSurface

        Text {
            anchors.centerIn: parent
            text: `+${ModuleService.overflow}`
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            font.weight: Font.DemiBold
            color: Theme.textMuted
        }
    }

    component Segment: Item {
        id: segment

        property string activityId: ""

        // "mark", "figure", or "both".
        property string part: "both"

        readonly property alias hovered: mouse.containsMouse

        readonly property var marks: ({
            timer: timerMark, media: mediaMark, workspace: workspaceMark
        })
        readonly property var figures: ({
            timer: timerFigure, media: mediaFigure, workspace: workspaceFigure
        })

        // Centred on its side, except the privacy mark split across both:
        // its glyphs and the program's name each keep to their outer edge,
        // by the same margin, so the pair is symmetric about the time.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: !segment.hugs ? (parent.width - width) / 2
                : segment.part === "mark" ? ModuleService.activityInset
                : parent.width - width - ModuleService.activityInset
            spacing: 7

            Loader {
                anchors.verticalCenter: parent.verticalCenter
                active: segment.part !== "figure" && segment.activityId !== ""
                visible: active
                sourceComponent: segment.marks[segment.activityId] ?? null
            }


            Loader {
                anchors.verticalCenter: parent.verticalCenter
                active: segment.part !== "mark" && segment.activityId !== ""
                visible: active
                sourceComponent: segment.figures[segment.activityId] ?? null
            }
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            enabled: segment.activityId !== ""
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (segment.activityId === "workspace")
                    ModuleService.togglePanel("overview")
                else
                    ModuleService.activate(segment.activityId)
            }
        }

        // ── COUNTDOWN ───────────────────────────────────────────────────────
        Component {
            id: timerMark

            RingIndicator {
                width: 16
                height: 16
                thickness: 2
                progress: TimerService.progress
                trackColor: Theme.indicatorDim
                fillColor: TimerService.tint
            }
        }

        Component {
            id: timerFigure

            Text {
                text: TimerService.display
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: TimerService.paused ? Theme.textMuted : Theme.text
            }
        }

        // ── TRACK ───────────────────────────────────────────────────────────
        //
        // The artwork.
        Component {
            id: mediaMark

            ClippingRectangle {
                width: 20
                height: 20
                radius: width * Theme.pictureCorner
                // None behind a picture: a player may send its logo on transparency.
                color: art.visible ? "transparent" : Theme.surfaceHoverIn(QsWindow.window)

                Component.onCompleted: MediaService.subscribe()
                Component.onDestruction: MediaService.release()

                Image {
                    id: art
                    anchors.fill: parent
                    source: MediaService.artUrl
                    visible: source != "" && status === Image.Ready
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 40
                    sourceSize.height: 40
                }

                Text {
                    anchors.centerIn: parent
                    visible: !art.visible
                    text: "󰎇"
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    color: Theme.indicator
                }
            }
        }

        Component {
            id: mediaFigure

            // EVER LEAN: the cava spectrum went with cava; the playing
            // glyph keeps the slot.
            Text {
                text: MediaService.playing ? "▶" : "⏸"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.indicator

                Component.onCompleted: MediaService.subscribe()
                Component.onDestruction: MediaService.release()
            }
        }

        // ── WORKSPACE ───────────────────────────────────────────────────────
        //
        // The one this screen shows, for a bar without the workspaces strip:
        // its number, or its name when it has one, in the privacy name's type.
        // A click opens the overview.
        Component {
            id: workspaceMark

            Text {
                text: "󰕰"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeRegular + 1
                color: Theme.textMuted
            }
        }

        Component {
            id: workspaceFigure

            // A new label slides in from below when the workspace is further
            // along and from above when it is back, and the old one out the
            // other way.
            Item {
                id: shown

                readonly property string screenName: QsWindow.window && QsWindow.window.screen
                    ? QsWindow.window.screen.name : ""
                readonly property int number: HyprlandService.activeOn(shown.screenName)
                    || HyprlandService.activeId
                readonly property string label: {
                    const found = HyprlandService.named.find(workspace => workspace.id === shown.number)
                    const name = found && typeof found.name === "string" ? found.name : ""
                    return name !== "" && name !== `${shown.number}` ? name : `${shown.number}`
                }

                property int was: 0
                property string settled: ""
                property string leaving: ""
                property real travel: 0

                width: Math.min(Math.max(incoming.implicitWidth, outgoing.visible ? outgoing.implicitWidth : 0),
                                ModuleService.activitySide - 2 * ModuleService.activityInset)
                height: incoming.implicitHeight
                clip: true

                onNumberChanged: {
                    const forward = shown.number > shown.was
                    shown.leaving = shown.settled
                    shown.settled = shown.label
                    shown.was = shown.number
                    slide.stop()
                    shown.travel = forward ? 1 : -1
                    slide.start()
                }

                Component.onCompleted: {
                    shown.was = shown.number
                    shown.settled = shown.label
                }

                NumberAnimation {
                    id: slide

                    target: shown
                    property: "travel"
                    to: 0
                    duration: Theme.durationMedium
                    easing.type: Theme.easing
                }

                Text {
                    id: outgoing

                    visible: shown.travel !== 0
                    y: (shown.travel - Math.sign(shown.travel)) * shown.height
                    width: shown.width
                    text: shown.leaving
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeRegular
                    font.weight: Font.DemiBold
                    color: Theme.textMuted
                }

                Text {
                    id: incoming

                    y: shown.travel * shown.height
                    width: shown.width
                    text: shown.label
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeRegular
                    font.weight: Font.DemiBold
                    color: Theme.textMuted
                }
            }
        }
    }
}
