// The T3 Code card: whether the web service is up, the nightly that is
// installed against the newest release, and the three things to do about it.

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

Item {
    id: root

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    Component.onCompleted: T3Service.subscribe()
    Component.onDestruction: T3Service.release()

    function short(version: string): string {
        // 0.1.1-nightly.20261020.3411 → 20261020.3411
        const m = version.match(/nightly\.(\d+\.\d+)/)
        return m ? m[1] : (version || "—")
    }

    ModuleCard {
        id: card
        anchors.fill: parent
        title: "T3 Code Nightly"
        subtitle: T3Service.running ? "web service running"
            : T3Service.service === "unknown" ? "checking…"
            : T3Service.service === "paused" ? "paused (desktop app open)"
            : `web service ${T3Service.service}`
        figure: T3Service.updateAvailable ? "update" : (T3Service.installed ? "latest" : "")
        figureColor: T3Service.updateAvailable ? Theme.indicatorWarn : Theme.textMuted

        mark: RingIndicator {
            anchors.fill: parent
            thickness: 3
            progress: T3Service.running ? 1 : 0
            fillColor: T3Service.running ? Theme.indicator : Theme.indicatorBad
            trackColor: Theme.indicatorDim

            Text {
                anchors.centerIn: parent
                text: "󰚩"
                font.family: Theme.fontMono
                font.pixelSize: 18
                color: T3Service.running ? Theme.indicator : Theme.textMuted
            }
        }

        CardFact { name: "Installed"; value: root.short(T3Service.installed) }
        CardFact {
            name: "Latest"
            value: T3Service.error !== "" && T3Service.latest === "" ? "offline" : root.short(T3Service.latest)
            valueColor: T3Service.updateAvailable ? Theme.indicatorWarn : Theme.text
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.cardRowGap
            spacing: 8

            PillButton {
                text: "Open"
                icon: "󰏌"
                onClicked: T3Service.open()
            }
            PillButton {
                text: T3Service.running ? "Restart" : "Start"
                icon: "󰑓"
                onClicked: T3Service.startService()
            }
            PillButton {
                text: T3Service.updating ? "Updating…" : "Update"
                icon: "󰚰"
                active: T3Service.updateAvailable
                enabled: !T3Service.updating
                onClicked: T3Service.updateAvailable ? T3Service.update() : T3Service.refresh(true)
            }
        }

        Text {
            Layout.fillWidth: true
            visible: T3Service.updateLog !== ""
            text: T3Service.updateLog
            elide: Text.ElideRight
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
        }
    }
}
