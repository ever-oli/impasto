// ╭──────────────────────────────────────────────────────────────────────────╮
// │   S H E L L   (notch)                                  │
// │   quickshell entry point · windows and top-level wiring                  │
// │                                                                          │
// │   github.com/ever-oli/notch  (branch main)                        │
// │   upstream: github.com/andreumassanet/impasto                            │
// ╰──────────────────────────────────────────────────────────────────────────╯

// Greyscale text: subpixel edges assume an opaque ground and fringe on a
// transparent surface.
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray

//@ pragma IconTheme Papirus

import QtQuick
import Quickshell

import "./bar"
import "./capture"
import "./orb"
import "./fontsize"
import "./services"

// The bar (with its island: launcher, control centre, notifications, OSD,
// the T3 card, keys, session, polkit), the capture surface and the IPC.
// niri binds keys to `notch …`, which calls the IPC below; there are no
// compositor-side global shortcuts.
ShellRoot {
    id: root

    Component.onCompleted: {
        void ThemeService.activeId          // reads theme.json
        void LauncherService.applications   // index ahead of the first open
        void ShortcutService.catalogue      // the key sheet's binds
        void PolkitService.asking           // the agent, from the start
        void ClipboardService.count         // the clipboard watcher
        void RecorderService.available      // a take left running
        void NotificationService.history    // the notification server
    }

    // The screen being worked on owns the live island; it follows niri's
    // focused output and waits while a panel is open.
    property string islandName: Quickshell.screens[0]?.name ?? ""

    readonly property string wantedIslandName: {
        const focused = NiriService.focusedMonitor
        for (const screen of Quickshell.screens)
            if (screen.name === focused)
                return focused
        return Quickshell.screens[0]?.name ?? ""
    }

    onWantedIslandNameChanged: root.claimIsland(root.wantedIslandName)

    function claimIsland(name: string): void {
        if (name === "" || root.islandName === name || (root.island?.expanded ?? false))
            return
        root.islandName = name
    }

    readonly property Connections islandRests: Connections {
        target: root.island
        function onExpandedChanged(): void { root.claimIsland(root.wantedIslandName) }
    }

    readonly property string liveScreenName: {
        for (const screen of Quickshell.screens)
            if (screen.name === root.islandName)
                return root.islandName
        return Quickshell.screens[0]?.name ?? ""
    }

    readonly property var island: {
        for (const bar of bars.instances)
            if (bar.live)
                return bar.island
        return null
    }

    Variants {
        model: Quickshell.screens

        BarReserve {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        id: bars

        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            live: modelData.name === root.liveScreenName
            onClaimed: root.claimIsland(modelData.name)
        }
    }

    // A program asking for root opens the island on its request, and the
    // island closes once it is answered.
    Connections {
        target: PolkitService

        function onRequested(): void {
            root.island?.open("auth")
        }

        function onSettled(): void {
            if (root.island?.state.openPanel === "auth")
                root.island?.close()
        }
    }

    // Always built rather than behind a Loader: creating a layer surface at
    // capture time flashes a black frame over the screen being captured.
    CaptureOverlay {}

    Connections {
        target: CaptureService

        function onRecordRequested(shape: string, geometry: string): void {
            RecorderService.startAt(shape, geometry)
        }
    }

    Commands {
        island: root.island
    }

    // The radial menu (Super+Alt+O, `qs ipc call orb toggle`).
    Orb {}

    // Text size slider (Style › Text size, `qs ipc call fontsize open`).
    FontSlider {}
}
