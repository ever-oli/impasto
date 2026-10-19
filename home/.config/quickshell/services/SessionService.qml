// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S E S S I O N   S E R V I C E                                          │
// │   log out, reboot, suspend, shut down                                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// │   EVER LEAN: the lock layer is gone (VPS, no lock needed); suspend       │
// │   suspends directly, and every sleep inhibitor with it.                  │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Session actions as data, rendered from one list. `destructive` marks the
// ones that end the session; the session block (`ButtonsBlock`) and the top
// row (`TopButtons`) ask for confirmation, not this service.
Singleton {
    id: root

    readonly property var actions: [
        { id: "suspend",  icon: "󰤄", label: "Suspend",   destructive: false },
        { id: "logout",   icon: "󰗽", label: "Log out",   destructive: true },
        { id: "reboot",   icon: "󰜉", label: "Restart",   destructive: true },
        { id: "shutdown", icon: "󰐥", label: "Shut down", destructive: true }
    ]

    readonly property Process runner: Process {}

    function run(actionId: string): void {
        switch (actionId) {
        case "suspend":
            root.exec(["systemctl", "suspend"])
            break
        case "logout":
            // NIRI PORT: hl.dsp.exit() becomes niri's quit action.
            HyprlandService.dispatch(["quit"])
            break
        case "reboot":
            root.exec(["systemctl", "reboot"])
            break
        case "shutdown":
            root.exec(["systemctl", "poweroff"])
            break
        default:
            console.warn("Unknown session action:", actionId)
        }
    }

    function exec(command: var): void {
        root.runner.command = command
        root.runner.running = true
    }
}
