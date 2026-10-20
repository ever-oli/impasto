// ╭──────────────────────────────────────────────────────────────────────────╮
// │   T E X T   S I Z E                                                      │
// │   a slider under the notch · `qs ipc call fontsize open`                 │
// │   Drag previews in the shell; release (debounced) runs notch-font.       │
// ╰──────────────────────────────────────────────────────────────────────────╯
// Sizes here are fixed pixels so the card does not grow under the pointer
// while it rescales everything else.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../theme"
import "../services"

Scope {
    id: root
    property bool opened: false
    property int original: 11

    function open() { original = FontSizeService.value; opened = true; Qt.callLater(() => keys.forceActiveFocus()) }
    function close() { FontSizeService.applyNow(); opened = false }
    function cancel() { FontSizeService.preview(original); FontSizeService.applyNow(); opened = false }
    function status() {
        return JSON.stringify({ opened: opened, value: FontSizeService.value, applied: FontSizeService.applied,
            pending: FontSizeService.pending, from: FontSizeService.from, to: FontSizeService.to });
    }

    IpcHandler {
        target: "fontsize"
        function open(): string { root.open(); return root.status() }
        function close(): string { root.close(); return root.status() }
        function toggle(): string { root.opened ? root.close() : root.open(); return root.status() }
        function status(): string { return root.status() }
        function set(n: int): string { FontSizeService.preview(n); return root.status() }
        function key(name: string): string {
            const k = { right: Qt.Key_Right, left: Qt.Key_Left, up: Qt.Key_Up, down: Qt.Key_Down,
                home: Qt.Key_Home, end: Qt.Key_End, enter: Qt.Key_Return, esc: Qt.Key_Escape }[name] ?? 0;
            if (k) keys.press(k); return root.status()
        }
    }

    PanelWindow {
        id: panel
        visible: root.opened
        screen: Quickshell.screens.find(s => s.name === NiriService.focusedMonitor) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notch-fontsize"
        // OnDemand, never Exclusive: the overlay takes keys only when opened or
        // clicked, and closes itself the moment focus goes to another window,
        // so it can never swallow typing meant for something else.
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        MouseArea { anchors.fill: parent; onClicked: root.close() }

        Item {
            id: keys
            anchors.fill: parent
            focus: root.opened
            property bool hadFocus: false
            onActiveFocusChanged: {
                if (activeFocus) hadFocus = true;
                else if (hadFocus && root.opened) { hadFocus = false; root.close() }
            }
            function press(k) {
                if (k === Qt.Key_Escape) root.cancel();
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.close();
                else if (k === Qt.Key_Right || k === Qt.Key_Up || k === Qt.Key_Plus || k === Qt.Key_Equal) FontSizeService.step(1);
                else if (k === Qt.Key_Left || k === Qt.Key_Down || k === Qt.Key_Minus) FontSizeService.step(-1);
                else if (k === Qt.Key_Home) FontSizeService.preview(11);
                else if (k === Qt.Key_End) FontSizeService.preview(FontSizeService.to);
                else return false;
                return true;
            }
            Keys.onPressed: e => { e.accepted = press(e.key) }
        }

        Rectangle {
            id: card
            width: 420; height: 116; radius: 22
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.capsuleHeight + Theme.barTopMargin + 10
            color: Theme.island
            border.width: 1; border.color: Theme.islandBorder
            opacity: root.opened ? 1 : 0
            MouseArea { anchors.fill: parent }   // clicks on the card stay open

            Text {
                x: 20; y: 16
                text: "󰛂  Text size"
                font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 20; y: 14
                text: FontSizeService.value + (FontSizeService.value === 11 ? "  default" : "")
                font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.Bold
                color: Theme.text
            }
            Text {
                x: 20; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                text: "←/→ adjust · Enter keep · Esc undo"
                font.family: Theme.fontFamily; font.pixelSize: 11
                color: Theme.textMuted
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 20
                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                text: FontSizeService.pending ? "applying…" : "applied"
                font.family: Theme.fontFamily; font.pixelSize: 11
                color: Theme.textMuted
            }

            // Track: small A on the left, big A on the right, ticks per size.
            Item {
                id: track
                x: 48; width: parent.width - 96; y: 52; height: 28
                readonly property real frac: (FontSizeService.value - FontSizeService.from) / (FontSizeService.to - FontSizeService.from)
                Text { anchors.right: parent.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    text: "A"; font.pixelSize: 11; font.family: Theme.fontFamily; color: Theme.text }
                Text { anchors.left: parent.right; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                    text: "A"; font.pixelSize: 20; font.family: Theme.fontFamily; color: Theme.text }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 6; radius: 3; color: Theme.islandSurfaceHover
                    Rectangle { width: parent.width * track.frac; height: parent.height; radius: 3; color: Theme.accent }
                }
                Repeater {
                    model: FontSizeService.to - FontSizeService.from + 1
                    Rectangle {
                        required property int index
                        x: track.width * index / (FontSizeService.to - FontSizeService.from) - 1
                        y: parent.height - 3; width: 2; height: 3; color: Theme.islandBorder
                    }
                }
                Rectangle {
                    id: knob
                    width: 22; height: 22; radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    x: track.width * track.frac - width / 2
                    color: Theme.accent
                    border.width: 2; border.color: Theme.accentText
                }
                MouseArea {
                    anchors.fill: parent; anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    function at(mx) {
                        const f = Math.max(0, Math.min(1, (mx - 10) / track.width));
                        FontSizeService.preview(FontSizeService.from + f * (FontSizeService.to - FontSizeService.from));
                    }
                    onPressed: m => at(m.x)
                    onPositionChanged: m => { if (pressed) at(m.x) }
                    onReleased: FontSizeService.applyNow()
                    onWheel: w => FontSizeService.step(w.angleDelta.y > 0 ? 1 : -1)
                }
            }
        }
    }
}
