// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C L O C K   M O D U L E                                                │
// │   clock · the island's resting face                                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../theme"
import "../../services"

// The time, optionally with the date. It has no chip or layout slot: it is
// what the island shows at rest.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: Theme.capsuleHeight

    // Tick every second only when seconds are shown.
    SystemClock {
        id: clock
        precision: SettingsService.clockShowsSeconds
            ? SystemClock.Seconds : SystemClock.Minutes
    }

    // Seconds are appended to the chosen format so the two settings stay
    // independent.
    readonly property string format: SettingsService.clockShowsSeconds
        ? SettingsService.clockFormat.replace("mm", "mm:ss")
        : SettingsService.clockFormat

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    Component {
        id: detail

        Item {
            Row {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, root.format)
                    font.family: Theme.fontBar
                    font.pixelSize: Theme.fontSizeRegular
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                // The conversion the clock has not chosen: the 12-hour
                // beside the 24-hour, faint but legible at a glance.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: SettingsService.clockShows12h
                    text: Qt.formatDateTime(clock.date, SettingsService.clockOtherFormat)
                    font.family: Theme.fontBar
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: SettingsService.clockShowsDate
                    text: Qt.formatDateTime(clock.date, "ddd d MMM")
                    font.family: Theme.fontBar
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }
            }
        }
    }
}
