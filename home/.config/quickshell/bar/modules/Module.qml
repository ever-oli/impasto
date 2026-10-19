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
        media: mediaModule,
        timer: timerModule,
        t3: t3Module,
        battery: batteryModule,
        volume: volumeModule,
        brightness: brightnessModule,
        network: networkModule,
        bluetooth: bluetoothModule,
        stats: statsModule,
        notifications: notificationsModule
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
    Component { id: mediaModule;   MediaModule { compact: root.compact } }
    Component { id: timerModule;   TimerModule { compact: root.compact } }
    Component { id: t3Module;      T3Module { compact: root.compact } }
    Component { id: batteryModule; BatteryModule { compact: root.compact } }
    Component { id: volumeModule;     VolumeModule { compact: root.compact } }
    Component { id: brightnessModule; BrightnessModule { compact: root.compact } }
    Component { id: networkModule;    NetworkModule {} }
    Component { id: bluetoothModule;  BluetoothModule {} }
    Component { id: statsModule;      StatsModule { compact: root.compact } }
    Component { id: notificationsModule; NotificationsModule {} }
}
