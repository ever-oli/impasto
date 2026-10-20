// `impasto open t3`: the T3 card on its own in the island.

import QtQuick

import "../../theme"
import "../modules"

Item {
    id: root

    signal closed()

    T3Module { anchors.fill: parent }

    Keys.onEscapePressed: root.closed()
}
