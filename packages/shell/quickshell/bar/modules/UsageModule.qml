// ╭──────────────────────────────────────────────────────────────────────────╮
// │   U S A G E   M O D U L E                                                │
// │   OpenRouter credit, in the island                                       │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../services"
import "../../components"

Item {
    id: root

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    ModuleCard {
        id: card
        anchors.fill: parent
        title: "OpenRouter"
        subtitle: UsageService.ok ? (UsageService.isLow ? "Credit is low: top up at openrouter.ai/credits" : "OpenRouter credit (Pi uses :free models)")
                                  : `Unavailable (${UsageService.error || "loading"})`

        CardFact { name: "Credit left"; value: UsageService.money(UsageService.remaining) }
        CardFact { name: "Spent today"; value: UsageService.money(UsageService.today) }
        CardFact { name: "This month"; value: UsageService.money(UsageService.month) }
    }
}
