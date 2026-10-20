// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O D U L E                                                            │
// │   maps a module id to its component                                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"

// Maps a module id to its component, so the bar, the island and the services
// pass ids around as strings.
//
// `compact` is the ring face for modules that have one
// (`ModuleService.ringed`); otherwise the detail is built. A new module needs a
// row here and one in the catalogue.
Item {
    id: root

    property string moduleId: ""
    property bool compact: false

    readonly property var components: ({
        clock: clockModule,
        volume: volumeModule,
        network: networkModule,
        bluetooth: bluetoothModule,
        notifications: notificationsModule,
        t3: t3Module
    })

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        active: root.moduleId !== ""
        sourceComponent: root.components[root.moduleId] ?? null
    }

    Component { id: clockModule;   ClockModule {} }
    Component { id: volumeModule;     VolumeModule { compact: root.compact } }
    Component { id: networkModule;    NetworkModule {} }
    Component { id: bluetoothModule;  BluetoothModule {} }
    Component { id: notificationsModule; NotificationsModule {} }
    Component { id: t3Module;         T3Module {} }
}
