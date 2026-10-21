// ╭──────────────────────────────────────────────────────────────────────────╮
// │   S E S S I O N   S E R V I C E   (lean)                                 │
// │   log out, reboot, shut down                                             │
// ╰──────────────────────────────────────────────────────────────────────────╯
//
// No lock or suspend: this runs on a cloud VM reached over RustDesk, where a
// lock screen only gets in the way and suspend is meaningless. The session
// block and the top row ask for confirmation, not this service.

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var actions: [
        { id: "logout",   icon: "󰗽", label: "Log out",   destructive: true },
        { id: "reboot",   icon: "󰜉", label: "Restart",   destructive: true },
        { id: "shutdown", icon: "󰐥", label: "Shut down", destructive: true }
    ]

    function run(actionId: string): void {
        switch (actionId) {
        case "logout":
            NiriService.quit()
            break
        case "reboot":
            Quickshell.execDetached(["systemctl", "reboot"])
            break
        case "shutdown":
            Quickshell.execDetached(["systemctl", "poweroff"])
            break
        default:
            console.warn("Unknown session action:", actionId)
        }
    }
}
