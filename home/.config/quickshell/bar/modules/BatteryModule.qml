// ╭──────────────────────────────────────────────────────────────────────────╮
// │   B A T T E R Y   M O D U L E                                            │
// │   charge level and what the machine is doing about it                    │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../../components"

Item {
    id: root

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    ModuleCard {
        id: card
        anchors.fill: parent
        title: "Battery"
        subtitle: BatteryService.has
            ? (BatteryService.charging ? "Charging" : `On battery · ${BatteryService.percent}%`)
            : "No battery on this machine"

        CardFact {
            name: "Level"
            value: BatteryService.has ? `${BatteryService.percent}%` : "—"
        }
        CardFact {
            name: "Source"
            value: BatteryService.has ? (BatteryService.charging ? "External power" : "The cell") : "—"
        }
    }
}
