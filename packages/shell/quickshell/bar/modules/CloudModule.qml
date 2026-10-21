// ╭──────────────────────────────────────────────────────────────────────────╮
// │   C L O U D   M O D U L E                                                │
// │   cpu, memory and the idle auto-stop, for the machine and idle chips     │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

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
        title: "Cloud desktop"
        subtitle: `Auto-stop in ${CloudService.idleText} if idle`

        CardFact { name: "CPU"; value: `${CloudService.cpu}%` }
        CardFact { name: "Memory"; value: `${CloudService.mem}%` }
        CardFact { name: "Auto-stop"; value: "after 2 h under 10% CPU" }
    }
}
