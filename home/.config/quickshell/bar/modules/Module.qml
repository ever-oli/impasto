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

// Maps a module id to its file, so the bar, the island and the services
// pass ids around as strings.
//
// Each module loads on its own from its file (idea from k4ditano/k4, MIT):
// one that fails to load is logged in ModuleService.failed and skipped, and
// the rest of the bar keeps working. `qs ipc call modules reload <id>`
// reloads it from disk. A new module needs a row here and in the catalogue.
Item {
    id: root

    property string moduleId: ""
    property bool compact: false

    readonly property var files: ({
        clock: "ClockModule.qml",
        volume: "VolumeModule.qml",
        network: "NetworkModule.qml",
        bluetooth: "BluetoothModule.qml",
        notifications: "NotificationsModule.qml",
        t3: "T3Module.qml",
        machine: "CloudModule.qml",
        idle: "CloudModule.qml",
        battery: "BatteryModule.qml",
        usage: "UsageModule.qml"
    })

    implicitWidth: holder.item ? holder.implicitWidth : 0
    implicitHeight: holder.item ? holder.implicitHeight : 0

    Loader {
        id: holder
        anchors.fill: parent
        active: root.moduleId !== "" && root.files[root.moduleId] !== undefined
        // The generation in the query makes a reload read the file again.
        source: active ? Qt.resolvedUrl(root.files[root.moduleId]) + "?g=" + ModuleService.generationOf(root.moduleId) : ""
        onLoaded: {
            if (item.compact !== undefined)
                item.compact = Qt.binding(() => root.compact)
            ModuleService.markLoaded(root.moduleId)
        }
        onStatusChanged: {
            if (status === Loader.Error)
                ModuleService.markFailed(root.moduleId, root.files[root.moduleId])
        }
    }
}
