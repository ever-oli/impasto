// ╭──────────────────────────────────────────────────────────────────────────╮
// │   O R B                                                                  │
// │   a radial menu at the pointer · `qs ipc call orb toggle`                │
// │                                                                          │
// │   Ported from tcballard/omarchy-plugin-orb (MIT, (c) 2026 Tom Ballard),  │
// │   see orb/LICENSE. Hyprland, installer and settings dropped; niri-only.  │
// ╰──────────────────────────────────────────────────────────────────────────╯
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../theme"
import "../services"
import "OrbModel.js" as Model

Scope {
    id: root

    property bool opened: false
    property bool positioned: false
    property int selected: -1
    property bool keyboardMode: false
    property point pointer: Qt.point(0, 0)
    property string placedBy: ""
    property string submenuTitle: ""
    property var submenuRows: []
    property int parentSelection: -1
    property int menuPage: 0
    property string lastAction: ""
    readonly property int diameter: Math.round(260 * Theme.fontScale)
    readonly property bool animate: Theme.motion > 0
    function ms(n) { return Math.round(n * Theme.motion) }

    readonly property string notch: Quickshell.env("HOME") + "/.local/bin/notch"
    readonly property var defaults: [
        { label: "Apps", icon: "app", command: [notch, "toggle", "launcher"] },
        { label: "Theme", icon: "themes", command: [notch, "picker", "theme"] },
        { label: "Ask", icon: "agents", command: [notch, "toggle", "ask"] },
        { label: "T3", icon: "create", command: [notch, "toggle", "t3"] },
        { label: "Terminal", icon: "terminal", command: ["ghostty"] },
        { label: "Files", icon: "files", command: ["nautilus", "--new-window"] },
        { label: "Settings", icon: "settings", command: [notch, "toggle", "controls"] }
    ]
    // Palette pins (Ctrl+K › Pin) fill the eighth slot as one submenu.
    readonly property var pinned: (LauncherService.prefs.pins ?? []).map(k => LauncherService.byKey(k)).filter(e => e)
        .slice(0, 12).map(e => ({ label: String(e.name).replace(/\s+✓$/, "").slice(0, 20),
            icon: e.kind === "app" ? "app" : "settings", entry: e }))
    readonly property var actions: pinned.length ? defaults.concat([{ label: "Pinned", icon: "screenshot", children: pinned }]) : defaults

    readonly property int pageCount: submenuTitle ? Math.max(1, Math.ceil(submenuRows.length / 6)) : 1
    readonly property var wheelActions: submenuTitle ? submenuRows.slice(menuPage * 6, menuPage * 6 + 6) : actions
    readonly property int selectionCount: wheelActions.length
    readonly property bool hubActive: keyboardMode ? selected === -2 : wheelMouse.atCentre

    function open() {
        selected = -1; keyboardMode = false; positioned = false; placedBy = "";
        submenuTitle = ""; parentSelection = -1; menuPage = 0; opened = true;
        fallback.restart();
    }
    function close() { opened = false; positioned = false; selected = -1; submenuTitle = ""; fallback.stop() }
    function toggle() { opened ? close() : open() }
    function placeAt(x, y, how) {
        if (!opened || positioned) return;
        pointer = Qt.point(x, y); placedBy = how; positioned = true; fallback.stop();
        Qt.callLater(() => keys.forceActiveFocus());
    }
    function select(delta) {
        if (!selectionCount) return;
        keyboardMode = true;
        selected = selected < 0 ? (delta > 0 ? 0 : selectionCount - 1) : (selected + delta + selectionCount) % selectionCount;
    }
    function turnPage(delta) {
        if (pageCount < 2) return;
        menuPage = (menuPage + delta + pageCount) % pageCount; selected = -1; keyboardMode = true;
    }
    function back() {
        if (!submenuTitle) { close(); return; }
        submenuTitle = ""; selected = parentSelection; keyboardMode = true;
    }
    function activate(index) {
        if (opened && index === -2) { if (submenuTitle) back(); else close(); return; }
        if (!opened || index < 0 || index >= selectionCount) return;
        const a = wheelActions[index];
        if (a.children) {
            parentSelection = index; submenuTitle = a.label; submenuRows = a.children;
            selected = -1; menuPage = 0; return;
        }
        lastAction = a.label; close();
        pending = a; launchDelay.restart();   // let the layer unmap first
    }
    property var pending: null
    Timer {
        id: launchDelay; interval: 120
        onTriggered: {
            const a = root.pending; root.pending = null;
            if (!a) return;
            if (a.entry) LauncherService.activate(a.entry);
            else Quickshell.execDetached(a.command);
        }
    }
    // No pointer event within 250 ms: centre it under the notch.
    Timer {
        id: fallback; interval: 250
        onTriggered: root.placeAt(panel.width / 2, Theme.capsuleHeight + Theme.barTopMargin + root.diameter / 2 + 24, "notch")
    }

    function status() {
        return JSON.stringify({ opened: opened, positioned: positioned, placedBy: placedBy,
            x: Math.round(pointer.x), y: Math.round(pointer.y), selected: selected,
            submenu: submenuTitle, page: menuPage, pages: pageCount,
            items: wheelActions.map(a => a.label), lastAction: lastAction, motion: Theme.motion });
    }

    IpcHandler {
        target: "orb"
        function toggle(): string { root.toggle(); return root.status() }
        function open(): string { root.open(); return root.status() }
        function close(): string { root.close(); return root.status() }
        function status(): string { return root.status() }
        // Test hooks: walk the wheel without typing into the session.
        function key(name: string): string {
            const k = { right: Qt.Key_Right, left: Qt.Key_Left, tab: Qt.Key_Tab, enter: Qt.Key_Return,
                esc: Qt.Key_Escape, pgdn: Qt.Key_PageDown, home: Qt.Key_Home }[name] ?? (/^[1-9]$/.test(name) ? Qt.Key_1 + Number(name) - 1 : 0)
            if (k) keys.press(k, 0)
            return root.status()
        }
        function at(x: int, y: int): string { root.placeAt(x, y, "ipc"); return root.status() }
    }

    PanelWindow {
        id: panel
        visible: root.opened
        screen: Quickshell.screens.find(s => s.name === NiriService.focusedMonitor) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notch-orb"
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        readonly property var placement: Model.placement(root.pointer.x, root.pointer.y, width, height,
            Theme.capsuleHeight + Theme.barTopMargin, root.diameter)

        // The pointer's enter event is the first thing a fresh surface hears:
        // it places the wheel where the pointer already is.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onPositionChanged: mouse => root.placeAt(mouse.x, mouse.y, "pointer")
            onEntered: if (containsMouse) root.placeAt(mouseX, mouseY, "pointer")
            onPressed: mouse => { if (!root.positioned) root.placeAt(mouse.x, mouse.y, "pointer") }
            onClicked: if (root.positioned) root.close()
        }
        Item {
            id: keys
            anchors.fill: parent
            focus: root.opened
            function press(key, mods) {
                if (key === Qt.Key_Escape || key === Qt.Key_Backspace || (root.submenuTitle && key === Qt.Key_Left)) root.back();
                else if (key === Qt.Key_Home) { root.keyboardMode = true; root.selected = -2; }
                else if (key === Qt.Key_PageDown) root.turnPage(1);
                else if (key === Qt.Key_PageUp) root.turnPage(-1);
                else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) root.activate(root.selected);
                else if (key === Qt.Key_Right || key === Qt.Key_Down || (key === Qt.Key_Tab && !(mods & Qt.ShiftModifier))) root.select(1);
                else if (key === Qt.Key_Left || key === Qt.Key_Up || key === Qt.Key_Backtab || key === Qt.Key_Tab) root.select(-1);
                else if (key >= Qt.Key_1 && key <= Qt.Key_8 && key - Qt.Key_1 < root.selectionCount) { root.keyboardMode = true; root.selected = key - Qt.Key_1; }
                else return false;
                return true;
            }
            Keys.onPressed: event => { event.accepted = press(event.key, event.modifiers) }
        }
        Item {
            id: wheel
            x: panel.placement.x; y: panel.placement.y
            width: panel.placement.size; height: width
            visible: root.positioned
            opacity: root.opened && root.positioned ? 1 : 0
            scale: opacity > 0 ? 1 : 0.92
            Behavior on opacity { NumberAnimation { duration: root.ms(150) } }
            Behavior on scale { NumberAnimation { duration: root.ms(190); easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.98; height: width; radius: width / 2
                color: Theme.island
                border.width: 1; border.color: Theme.islandBorder
            }
            Canvas {
                id: ring
                anchors.fill: parent
                antialiasing: true
                property color surface: Theme.island
                property color ink: Theme.textMuted
                property color selectedFill: Theme.islandSurfaceHover
                property color selectedOutline: Theme.accent
                property int selection: root.selected
                property int count: root.selectionCount
                onCountChanged: requestPaint(); onSurfaceChanged: requestPaint(); onInkChanged: requestPaint()
                onSelectedFillChanged: requestPaint(); onSelectedOutlineChanged: requestPaint()
                onSelectionChanged: requestPaint(); onWidthChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d"); c.reset();
                    const center = width / 2, outer = width * 0.48, inner = width * 0.18;
                    c.lineWidth = 1;
                    const step = 360 / Math.max(1, count);
                    for (let i = 0; i < count; i++) {
                        const start = (i * step - 90 - step / 2 + 1) * Math.PI / 180;
                        const end = (i * step - 90 + step / 2 - 1) * Math.PI / 180;
                        c.beginPath(); c.arc(center, center, outer, start, end);
                        c.arc(center, center, inner, end, start, true); c.closePath();
                        c.fillStyle = i === selection ? selectedFill : surface; c.fill();
                        c.strokeStyle = i === selection ? selectedOutline : Qt.rgba(ink.r, ink.g, ink.b, 0.30); c.stroke();
                        if (i === selection) {
                            c.beginPath(); c.arc(center, center, outer - 3, start + 0.025, end - 0.025);
                            c.strokeStyle = selectedOutline; c.lineWidth = 3; c.stroke(); c.lineWidth = 1;
                        }
                    }
                }
            }
            Repeater {
                model: root.wheelActions
                delegate: Item {
                    id: slot
                    required property int index
                    required property var modelData
                    readonly property real angle: (index * 360 / root.selectionCount - 90) * Math.PI / 180
                    readonly property bool chosen: root.selected === index
                    width: wheel.width * 0.28; height: Math.max(24, wheel.width * 0.09)
                    x: wheel.width / 2 + Math.cos(angle) * wheel.width * 0.33 - width / 2
                    y: wheel.height / 2 + Math.sin(angle) * wheel.width * 0.33 - height / 2
                    LineIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.height; height: width
                        name: slot.modelData.icon
                        ink: slot.chosen ? Theme.accent : Theme.text
                    }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.32; height: width; radius: width / 2
                color: root.hubActive ? Theme.islandSurfaceHover : Theme.islandSurface
                border.width: 1; border.color: root.hubActive ? Theme.accent : Theme.islandBorder
                Behavior on color { ColorAnimation { duration: root.ms(140) } }
                Text {
                    anchors.centerIn: parent
                    visible: !root.submenuTitle
                    text: "notch"; textFormat: Text.PlainText
                    font.family: Theme.fontBar; font.pixelSize: Math.round(13 * Theme.fontScale)
                    color: Theme.text
                }
                LineIcon {
                    visible: !!root.submenuTitle
                    anchors.centerIn: parent
                    width: parent.width * 0.42; height: width
                    name: "arrow-undo"; ink: root.hubActive ? Theme.accent : Theme.text
                }
            }
            MouseArea {
                id: wheelMouse
                readonly property bool atCentre: containsMouse && Math.hypot(mouseX - width / 2, mouseY - height / 2) < width * 0.16
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.AllButtons
                cursorShape: root.selected >= 0 || atCentre ? Qt.PointingHandCursor : Qt.ArrowCursor
                property point last: Qt.point(-1, -1)
                onPositionChanged: mouse => {
                    // The wheel opens under a still pointer: only a real move selects.
                    if (last.x < 0) { last = Qt.point(mouse.x, mouse.y); return }
                    if (Math.hypot(mouse.x - last.x, mouse.y - last.y) < 4) return
                    root.keyboardMode = false
                    root.selected = Model.hit(mouse.x, mouse.y, width, root.selectionCount)
                }
                onExited: { last = Qt.point(-1, -1); if (!root.keyboardMode) root.selected = -1 }
                onClicked: mouse => {
                    const i = Model.hit(mouse.x, mouse.y, width, root.selectionCount)
                    if (mouse.button === Qt.LeftButton && i >= 0) root.activate(i)
                    else if (mouse.button === Qt.LeftButton && atCentre) root.activate(-2)
                    else root.close()
                }
                onWheel: event => { root.turnPage(event.angleDelta.y < 0 ? 1 : -1); event.accepted = true }
            }
            Rectangle {
                anchors.top: parent.bottom; anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(wheel.width, hint.implicitWidth + 24); height: hint.implicitHeight + 10; radius: height / 2
                color: Theme.island; border.width: 1; border.color: Theme.islandBorder
                Text {
                    id: hint; anchors.centerIn: parent
                    text: root.selected >= 0 && root.selected < root.selectionCount ? root.wheelActions[root.selected].label
                        : root.hubActive ? (root.submenuTitle ? "Back" : "Close")
                        : root.pageCount > 1 ? `${root.submenuTitle} · page ${root.menuPage + 1} / ${root.pageCount}`
                        : root.submenuTitle ? root.submenuTitle : "1–8 · Tab · Enter · Esc"
                    textFormat: Text.PlainText
                    font.family: Theme.fontBar; font.pixelSize: Math.round(12 * Theme.fontScale)
                    color: root.selected >= 0 ? Theme.text : Theme.textMuted
                }
            }
        }
    }
}
