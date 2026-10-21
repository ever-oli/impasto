// What is playing in the island terminal: the title, the line that is
// being said, and how far the film has come.

import QtQuick

import "../../theme"
import "../../services"
import "../../components"

// The chip on the bar: a ring that fills as the film does, and the time
// that is left. The card in the island: the title, the line, and where
// it is.
Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    function clock(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds))
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        const rest = total % 60
        return hours > 0
            ? `${hours}:${String(minutes).padStart(2, "0")}`
            : `${minutes}:${String(rest).padStart(2, "0")}`
    }

    readonly property real progress: {
        const playing = PlayingService.playing
        if (!playing || !playing.duration)
            return 0
        return Math.max(0, Math.min(1, playing.position / playing.duration))
    }

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    Component {
        id: chip

        Item {
            Item {
                id: mark

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.capsuleHeight
                height: Theme.capsuleHeight

                RingIndicator {
                    anchors.fill: parent
                    thickness: 2.5
                    progress: root.progress
                    trackColor: Theme.indicatorDim
                    fillColor: Theme.indicator

                    Text {
                        anchors.centerIn: parent
                        text: "󰐊"
                        font.family: Theme.fontMono
                        font.pixelSize: Math.round(Theme.capsuleHeight * 0.38)
                        color: Theme.indicator
                    }
                }
            }
        }
    }

    Component {
        id: detail

        ModuleCard {
            title: "Now playing"
            subtitle: PlayingService.playing
                ? (PlayingService.playing.title || "—")
                    + (PlayingService.caption ? " · " + PlayingService.caption : "")
                : "Nothing is playing"
            figure: PlayingService.playing
                ? root.clock(PlayingService.playing.position) + " / " + root.clock(PlayingService.playing.duration)
                : ""
            figureColor: Theme.textMuted

            mark: RingIndicator {
                anchors.fill: parent
                thickness: 3
                progress: root.progress
                trackColor: Theme.indicatorDim
                fillColor: Theme.indicator
            }
        }
    }
}
