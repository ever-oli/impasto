// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L A Y O U T S   B L O C K                                              │
// │   per-desktop presets · a plan drawn as a small diagram                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell
import Quickshell.Io

import "../../../theme"
import "../../../services"
import "../../../components"

// The Control centre block for `notch-layout`: a tile per preset, drawn as
// the arrangement it makes, so a plan reads as a shape rather than a name.
// Tapping applies it to the focused desktop; the status row says which
// desktop and which preset.
//
// Applying is the script's job (it names the desktop, stamps the include
// and reloads niri); the block reads the facts with one process call on
// open and after each tap.
Item {
    id: root

    property int cols: 2
    property int rows: 2

    // `notch-layout list --json`: { presets: [{name,label,icon,plan}],
    // state: {"1": "zen"}, focused: n }
    property var facts: null

    readonly property bool ready: root.facts !== null && root.facts.presets !== undefined
    readonly property var presets: root.ready ? root.facts.presets : []
    readonly property string applied: root.ready
        ? (root.facts.state[String(root.facts.focused ?? 0)] ?? "")
        : ""
    readonly property string nameOf: {
        const hit = root.presets.find(p => p.name === root.applied)
        return hit ? hit.label : "Default"
    }

    property bool running: false

    function refresh(): void {
        lister.running = false
        lister.running = true
    }
    function run(args: var): void {
        if (!args.length || root.running)
            return
        root.running = true
        live.command = ["notch-layout"].concat(args)
        live.running = true
    }

    Component.onCompleted: root.refresh()

    // Facts reader.
    Process {
        id: lister

        command: ["notch-layout", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.facts = text.trim() ? JSON.parse(text) : null
                root.running = false
            }
        }
    }

    // One apply at a time; the result re-reads the facts.
    Process {
        id: live

        onRunningChanged: if (!running) root.refresh()
    }

    Column {
        anchors.fill: parent
        spacing: Theme.centreGutter

        // Fixed split so the grid and the status row depend only on the
        // block's own height: grid gets everything above the status line.
        readonly property int statusH: 40

        GridView {
            id: grid

            width: parent.width
            height: parent.height - parent.statusH - Theme.centreGutter
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            cellWidth: (width - (root.cols - 1) * Theme.centreGutter) / root.cols
            // The rows the presets need, and the height each may take: the
            // block holds them all rather than clipping the last one.
            readonly property int rows: Math.max(1, Math.ceil(root.presets.length / root.cols))
            cellHeight: Math.max(40, Math.floor((height - (rows - 1) * Theme.centreGutter) / rows))
            model: ScriptModel {
                values: root.presets
            }

            delegate: Item {
                id: cell

                required property var modelData
                required property int index

                width: grid.cellWidth
                height: grid.cellHeight

                readonly property bool chosen: root.applied === cell.modelData.name

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: cell.chosen ? Theme.accent : "transparent"
                    opacity: cell.chosen ? 0.16 : 0
                    border.color: cell.chosen ? Theme.accent : Theme.hairline
                    border.width: 1
                }

                // The arrangement, drawn: a column per plan number, the
                // windows stacked in it. The rectangles are worked out in
                // one go, so a plan reads as a shape.
                Item {
                    id: diagram

                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(46, parent.width - 8 - 74)
                    height: Math.min(26, parent.height - 8)

                    readonly property real gap: 2
                    readonly property var steps: cell.modelData.plan
                    readonly property int columns: steps.length

                    // One rectangle per window: its column and its place in
                    // that column's stack.
                    readonly property var rects: {
                        const out = []
                        const gap = diagram.gap
                        const columnWidth = columns > 0 ? width / columns : width
                        for (let column = 0; column < columns; column++) {
                            const rows = Math.max(1, steps[column])
                            const rowHeight = height / rows
                            for (let row = 0; row < rows; row++) {
                                out.push({
                                    x: column * columnWidth,
                                    y: row * rowHeight,
                                    w: columnWidth - gap,
                                    h: rowHeight - gap
                                })
                            }
                        }
                        return out
                    }

                    Repeater {
                        model: diagram.rects

                        delegate: Rectangle {
                            required property var modelData

                            x: modelData.x
                            y: modelData.y
                            width: modelData.w
                            height: modelData.h
                            radius: 2
                            color: cell.chosen ? Theme.accent : Theme.textMuted
                            opacity: cell.chosen ? 0.9 : 0.55
                        }
                    }
                }

                // The name, and the glyph when the preset has no plan.
                Text {
                    anchors.left: diagram.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    font.family: Theme.fontBar
                    font.pixelSize: Theme.fontSizeSmall
                    color: cell.chosen ? Theme.accent : Theme.text
                    text: {
                        const steps = cell.modelData.plan
                        return steps.length ? cell.modelData.label
                                            : `${cell.modelData.icon} ${cell.modelData.label}`
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.running
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.run([cell.modelData.name])
                }
            }
        }

        // Which desktop and which preset; tapping lifts the preset. A plain
        // row, not a tile: the block is narrow and the tile's icon and
        // detail do not fit beside each other.
        Item {
            id: status

            width: parent.width
            height: parent.statusH

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - hint.width - 16
                elide: Text.ElideRight
                font.family: Theme.fontBar
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.text
                text: {
                    const desk = root.ready ? (root.facts.focused ?? 0) : 0
                    return `${desk} · ${root.nameOf}`
                }
            }

            Text {
                id: hint

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.fontBar
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
                text: "lift"
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.ready
                cursorShape: Qt.PointingHandCursor
                onClicked: root.run(["clear"])
            }
        }
    }
}
