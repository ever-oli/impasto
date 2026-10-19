// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S H E L L                                                              │
// │   quickshell entry point · windows and top-level wiring                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// │   EVER LEAN: the desktop widget layer, the deck, capture, the lock       │
// │   screens and the monitor/shortcut/profile services are gone.            │
// ╰──────────────────────────────────────────────────────────────────────────╯

// Greyscale text: subpixel edges assume an opaque ground and fringe on a
// transparent surface.
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

import "./bar"
import "./dock"
import "./services"
import "./settings"
import "./theme"

// Entry point: the windows, the services that must start at boot, and the
// wiring between services that may not reference each other.
ShellRoot {
    id: root

    // Singletons are built on first use. Each of these has to be running from
    // boot, not from the moment a panel first reads it.
    Component.onCompleted: {
        // Restores the saved palette.
        void ThemeService.activeId
        // Builds the launcher index ahead of the first open.
        void LauncherService.applications
        // Keeps history, so the graph has data before the panel opens.
        void StatsService.ready
        // Registers the polkit agent, so a request is answered from the start.
        void PolkitService.asking
        // Probes for hyprpicker, so the first press is not the one that asks.
        void PickerService.available
        // Starts the clipboard watcher.
        void ClipboardService.count
    }

    // ── SCREENS ─────────────────────────────────────────────────────────────
    //
    // Every surface is a Variants over the screens. A PanelWindow whose
    // ShellScreen is destroyed (output unplugged) does not recover when handed
    // a new one; Variants destroys and rebuilds the window with the list,
    // which does.

    // The island is the same bar on every screen, and one of them is LIVE: the
    // screen being worked on. It changes hands the moment the focus does.
    // The first screen is the fallback.
    property string islandName: root.fallbackScreenName

    readonly property string fallbackScreenName:
        Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""

    readonly property string wantedIslandName: {
        const focused = HyprlandService.focusedMonitor
        for (const screen of Quickshell.screens)
            if (screen.name === focused)
                return focused
        return root.fallbackScreenName
    }

    onWantedIslandNameChanged: root.settleIsland()

    function settleIsland(): void {
        root.claimIsland(root.wantedIslandName)
    }

    // A bar saying the pointer is on it (`Bar.claimed`), which is the same
    // answer the compositor's focus gives a moment earlier — except when the
    // pointer was warped there rather than walked.
    function claimIsland(name: string): void {
        if (name === "" || root.islandName === name || (root.island?.expanded ?? false))
            return
        root.islandName = name
    }

    readonly property Connections islandRests: Connections {
        target: root.island

        function onExpandedChanged(): void {
            root.settleIsland()
        }
    }

    // `islandName` with a screen that is not plugged in resolved away, so an
    // output leaving never leaves every bar inert.
    readonly property string liveScreenName: {
        for (const screen of Quickshell.screens)
            if (screen.name === root.islandName)
                return root.islandName
        return root.fallbackScreenName
    }

    // The live bar's island. Notifiable through `instances` and through each
    // bar's own `live`, so it follows the flag rather than a window.
    readonly property var island: {
        for (const bar of bars.instances)
            if (bar.live)
                return bar.island
        return null
    }

    // ── BARS ────────────────────────────────────────────────────────────────
    //
    // One bar per screen, exactly one of them live.

    // The space the bars keep, held per screen and never rebuilt, so swapping
    // one kind of bar for another moves no windows.
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

    // A dock on every screen, each drawn or not by `dockEverywhere` and
    // which screen is live.
    Variants {
        model: Quickshell.screens

        Dock {
            required property var modelData

            screen: modelData
            live: modelData.name === root.liveScreenName

            // The dock cannot see the island, so it asks.
            onLauncherRequested: root.island?.toggle("launcher")
        }
    }

    // A normal window rather than an island panel, so the island stays
    // visible while its settings change.
    SettingsWindow {
        id: settingsWindow

        // The palette and wallpaper pickers live on the island.
        onPanelRequested: panel => root.island?.open(panel)
    }

    // The control centre's gear. The island has already closed itself.
    Connections {
        target: root.island

        function onSettingsRequested(): void {
            settingsWindow.open()
        }
    }

    // The bar's settings button, which closes the window it opened.
    Connections {
        target: ModuleService

        function onSettingsRequested(): void {
            root.toggleSettings()
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

    // Global shortcuts: the compositor binds a key to the name, and the action
    // lives here, so a new panel needs no compositor config.
    GlobalShortcut {
        name: "launcher"
        description: "Open the island launcher"
        onPressed: root.island?.toggle("launcher")
    }

    GlobalShortcut {
        name: "controls"
        description: "Open the island quick controls"
        onPressed: root.island?.toggle("controls")
    }

    // The brightness keys act on the focused screen, which only the shell
    // knows how to dim. A held key repeats the press.
    GlobalShortcut {
        name: "brightnessUp"
        description: "Raise the focused screen's brightness"
        onPressed: BrightnessService.step(5)
    }

    GlobalShortcut {
        name: "brightnessDown"
        description: "Lower the focused screen's brightness"
        onPressed: BrightnessService.step(-5)
    }

    GlobalShortcut {
        name: "overview"
        description: "Open the workspace overview"
        onPressed: root.island?.toggle("overview")
    }

    GlobalShortcut {
        name: "stats"
        description: "Open the system statistics"
        onPressed: root.island?.toggle("stats")
    }

    GlobalShortcut {
        name: "session"
        description: "Open the session menu"
        onPressed: root.island?.toggle("session")
    }

    // An open panel holds the keyboard exclusively, which beats a normal
    // window, so the island closes first or the window cannot be typed in.
    function toggleSettings(): void {
        if (!settingsWindow.shown)
            root.island?.close()
        settingsWindow.toggle()
    }

    GlobalShortcut {
        name: "settings"
        description: "Open the settings window"
        onPressed: root.toggleSettings()
    }

    GlobalShortcut {
        name: "appearance"
        description: "Open the island appearance panel"
        onPressed: root.island?.toggle("appearance")
    }

    // Same panel, on the palette strip. Each name only closes from its own
    // strip.
    GlobalShortcut {
        name: "palette"
        description: "Open the island appearance panel on the palettes"
        onPressed: root.island?.toggle("palette")
    }

    GlobalShortcut {
        name: "keys"
        description: "Show every key"
        onPressed: {
            // EVER LEAN: the keys sheet went with ShortcutService; the
            // overview is the nearest thing that still answers.
            root.island?.toggle("overview")
        }
    }

    GlobalShortcut {
        name: "zen"
        description: "Hide or show the bar"
        onPressed: SettingsService.set("barHidden", !SettingsService.barHidden)
    }

    GlobalShortcut {
        name: "game"
        description: "Turn game mode on or off"
        onPressed: {
            const on = !SettingsService.gameMode
            SettingsService.set("gameMode", on)
            OsdService.requested("󰺵", Tr.t(on ? "Game mode on" : "Game mode off"), -1)
        }
    }

    // The clipboard and the emoji are launcher modes: pressed again on that
    // mode it closes, pressed on another mode it switches. The query is set
    // before opening because with `launcherFits` the panel's height depends on
    // it, and the island is sized before the panel exists.
    function openLauncherOn(mode: string): void {
        const sigil = SettingsService.launcherPrefix(mode)
        const showing = root.island?.state.openPanel === "launcher"
        if (showing && LauncherService.query.startsWith(sigil)) {
            root.island?.close()
            return
        }
        LauncherService.query = sigil
        root.island?.open("launcher")
    }

    GlobalShortcut {
        name: "clipboard"
        description: "Open the launcher on the clipboard"
        onPressed: root.openLauncherOn("clipboard")
    }

    GlobalShortcut {
        name: "emoji"
        description: "Open the launcher on the emoji"
        onPressed: root.openLauncherOn("emoji")
    }

    // hyprpicker freezes a screenshot of the screen, so an open panel has to
    // finish closing before it starts.
    GlobalShortcut {
        name: "picker"
        description: "Pick a colour off the screen"
        onPressed: {
            const wasOpen = root.island?.expanded ?? false
            root.island?.close()
            PickerService.pick(wasOpen ? PickerService.settle : 0)
        }
    }

    // A new wallpaper re-derives the adaptive palette. Wired here so the
    // dependency runs one way: the theme knows about wallpapers, not the
    // reverse.
    Connections {
        target: WallpaperService

        function onApplied(path: string): void {
            ThemeService.reloadAdaptiveColors()
        }
    }

    // ── IPC ─────────────────────────────────────────────────────────────────
    //
    // Everything the impasto command and `qs ipc call` can reach. Every
    // palette push hangs off WallpaperService.applied, which only fires
    // inside this process, so Thunar's "Set as Wallpaper" comes in here too:
    //   qs ipc call wallpaper set <path>
    Commands {
        island: root.island
    }

}
