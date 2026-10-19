// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T 3   M O D U L E                                                      │
// │   code agent pulse · today's sessions and the week's messages            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// │   EVER LEAN: replaced ClaudeModule; the card reads the collector file.    │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

Item {
    id: root

    property bool compact: false

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: root.compact ? chip : detail
    }

    // Ring face; `ChipFace` draws the name beside it.
    Component {
        id: chip

        Item {
            RingIndicator {
                width: Theme.capsuleHeight
                height: Theme.capsuleHeight
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                thickness: 3
                progress: T3Service.gauge
                fillColor: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: "󰔟"
                    font.family: Theme.fontMono
                    font.pixelSize: parent.height * 0.42
                    color: T3Service.measured ? Theme.accent : Theme.textMuted
                }
            }
        }
    }

    Component {
        id: detail

        ModuleCard {
            title: "T3 Code"
            subtitle: T3Service.available ? Tr.t("Agent usage this machine") : Tr.t("No collector record")
            figure: T3Service.measured ? `${Math.round(T3Service.gauge * 100)}%` : "—"
            figureColor: T3Service.measured ? Theme.text : Theme.textMuted

            mark: Item {
                anchors.fill: parent

                RingIndicator {
                    anchors.fill: parent
                    thickness: 3
                    progress: T3Service.gauge
                    fillColor: Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: "󰔟"
                        font.family: Theme.fontMono
                        font.pixelSize: parent.height * 0.36
                        color: T3Service.measured ? Theme.accent : Theme.textMuted
                    }
                }
            }

            Repeater {
                model: T3Service.rows

                CardFact {
                    required property var modelData

                    name: modelData.label
                    value: modelData.value
                }
            }
        }
    }
}
