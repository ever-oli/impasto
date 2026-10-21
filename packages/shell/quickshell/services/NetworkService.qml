// ╭──────────────────────────────────────────────────────────────────────────╮
// │   N E T W O R K   S E R V I C E   (lean)                                 │
// │   the default route's link and address, from iproute2                    │
// ╰──────────────────────────────────────────────────────────────────────────╯
//
// The VM is wired and runs systemd-networkd, so there is no NetworkManager to
// ask: `ip -j` gives the interface carrying the default route and its address,
// and a ping-free check of that route stands in for "online". The Wi-Fi API is
// kept (always off) so the control centre and the detail panel still link.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string interfaceName: ""
    property string address: ""
    property string gateway: ""
    readonly property bool online: root.interfaceName !== ""
    readonly property bool wiredConnected: root.online
    readonly property string connectionName: root.online ? root.interfaceName : "Offline"
    readonly property string stateLine: root.online
        ? `${root.address}${root.gateway ? " via " + root.gateway : ""}` : "No default route"
    readonly property string icon: root.online ? "󰈀" : "󰈂"

    // No Wi-Fi on this machine.
    readonly property bool wifiEnabled: false
    readonly property bool wifiConnected: false
    readonly property bool radioOn: false
    readonly property bool scanning: false
    readonly property string busySsid: ""
    readonly property var networks: []
    function strengthIcon(strength: int): string { return "󰤯" }
    function toggleWifi(): void {}
    function setWifi(on: bool): void {}
    function scan(): void {}
    function connect(ssid: string, password: string): void {}
    function disconnect(): void {}

    function refresh(): void {
        if (!probe.running)
            probe.running = true
    }

    readonly property Timer poll: Timer {
        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    readonly property Process probe: Process {
        command: ["sh", "-c",
            "ip -j route get 1.1.1.1 2>/dev/null; echo; " +
            "dev=$(ip -j route get 1.1.1.1 2>/dev/null | sed -n 's/.*\"dev\":\"\\([^\"]*\\)\".*/\\1/p'); " +
            "[ -n \"$dev\" ] && ip -j -4 addr show dev \"$dev\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n").filter(line => line.trim() !== "")
                try {
                    const route = JSON.parse(parts[0] ?? "[]")[0] ?? null
                    root.interfaceName = route?.dev ?? ""
                    root.gateway = route?.gateway ?? ""
                    const addr = JSON.parse(parts[1] ?? "[]")[0]?.addr_info?.[0]
                    root.address = addr ? `${addr.local}/${addr.prefixlen}` : (route?.prefsrc ?? "")
                } catch (error) {
                    root.interfaceName = ""
                }
            }
        }
    }
}
