// ╭──────────────────────────────────────────────────────────────────────────╮
// │   A S K   P A N E L                                                      │
// │   the notch assistant: a question, what it sees, a streamed answer       │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

ColumnLayout {
    id: root

    signal closed()

    spacing: 12

    Component.onCompleted: {
        AskService.bridge.running = true
        AskService.loadModes()
        field.forceActiveFocus()
    }

    // ── HEADER: what goes with the question ─────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: "󰚩"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fs(17)
            color: Theme.accent
        }
        Text {
            Layout.fillWidth: true
            text: AskService.busy ? (AskService.thought !== "" ? AskService.thought.replace(/\s+/g, " ") : "Thinking…") : "Ask"
            elide: Text.ElideLeft
            font.family: Theme.fontBar
            font.pixelSize: AskService.busy ? Theme.fontSizeSmall : 16
            font.italic: AskService.busy
            color: AskService.busy ? Theme.textMuted : Theme.text
        }
        // The mode, not an agent: General reads as plain "Mode: General"; other modes get the pill.
        PillButton { icon: AskService.mode === "general" ? "" : AskService.modeInfo.icon
            text: AskService.mode === "general" ? "Mode: General" : AskService.modeInfo.name
            active: AskService.mode !== "general"
            onClicked: AskService.stepMode() }
        PillButton { icon: "󰖟"; text: AskService.captured !== "" ? `Captured: ${AskService.captured.slice(0, 24)}` : "Page"
            active: AskService.captured !== ""
            onClicked: AskService.captured !== "" ? AskService.captured = "" : AskService.capture() }
        PillButton { icon: "󰹑"; text: ""; active: AskService.screen === "screen"
            onClicked: AskService.screen = AskService.screen === "screen" ? "none" : "screen" }
        PillButton { icon: "󰩭"; text: ""; active: AskService.screen === "region"
            onClicked: AskService.screen = AskService.screen === "region" ? "none" : "region" }
        PillButton { icon: "󰅍"; text: ""; active: AskService.context
            onClicked: AskService.context = !AskService.context }
        PillButton { icon: "󰍽"; text: ""; active: AskService.act
            onClicked: AskService.act = !AskService.act }
        IconButton { icon: AskService.busy ? "󰓛" : "󰎔"
            onClicked: AskService.busy ? AskService.cancel() : AskService.reset() }
    }

    // ── TRANSCRIPT ──────────────────────────────────────────────────────────
    ListView {
        id: transcript

        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 10
        model: AskService.messages
        onCountChanged: Qt.callLater(() => transcript.positionViewAtEnd())
        onContentHeightChanged: if (AskService.busy) transcript.positionViewAtEnd()

        delegate: Loader {
            required property var modelData
            width: ListView.view.width
            sourceComponent: modelData.role === "visual" && modelData.path ? picture : line

            Component {
                id: picture
                Image {
                    source: `file://${modelData.path}`
                    fillMode: Image.PreserveAspectFit
                    height: Math.min(implicitHeight * width / Math.max(1, implicitWidth), 300)
                    smooth: true
                }
            }
            Component { id: line; Text {
            width: parent ? parent.width : 0
            text: modelData.text
            wrapMode: Text.Wrap
            textFormat: modelData.role === "ai" ? Text.MarkdownText : Text.PlainText
            font.family: modelData.role === "tool" || modelData.role === "visual" ? Theme.fontMono : Theme.fontBar
            font.pixelSize: modelData.role === "tool" ? Theme.fontSizeSmall : 14
            font.weight: modelData.role === "you" ? Font.DemiBold : Font.Normal
            color: modelData.role === "ai" ? Theme.text : modelData.role === "you" ? Theme.accent : Theme.textMuted
            onLinkActivated: link => Quickshell.execDetached(["xdg-open", link])
        } }
        }

        // Quick actions while nothing has been asked.
        Flow {
            anchors.centerIn: parent
            width: parent.width
            visible: AskService.messages.length === 0
            spacing: 8
            Repeater {
                model: AskService.suggestions
                PillButton {
                    required property var modelData
                    icon: modelData.icon
                    text: modelData.text
                    onClicked: AskService.ask(modelData.text, modelData.screen)
                }
            }
        }
    }

    // ── APPROVAL ────────────────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: approval.implicitHeight + 20
        visible: AskService.permission !== null
        radius: Theme.radiusMedium
        color: Theme.islandSurface
        border.color: Theme.yellow
        border.width: 1

        RowLayout {
            id: approval
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: AskService.permission ? `${AskService.permission.title}\n${AskService.permission.detail}` : ""
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.text
            }
            PillButton { text: "Deny"; onClicked: AskService.answer(false) }
            PillButton { text: "Always"; onClicked: { AskService.auto = true; AskService.answer(true) } }
            PillButton { text: "Approve"; active: true; onClicked: AskService.answer(true) }
        }
    }

    // ── FIELD ───────────────────────────────────────────────────────────────
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.islandBorder }

    TextInput {
        id: field

        Layout.fillWidth: true
        Layout.preferredHeight: 28
        verticalAlignment: TextInput.AlignVCenter
        font.family: Theme.fontBar
        font.pixelSize: Theme.fs(16)
        color: Theme.text
        clip: true
        selectByMouse: true
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText

        function submit(): void {
            AskService.ask(text, AskService.screen)
            text = ""
        }
        Keys.onReturnPressed: field.submit()
        Keys.onEnterPressed: field.submit()
        // Escape stops an answer first; the island closes the panel after.
        Keys.onEscapePressed: event => {
            event.accepted = AskService.busy
            if (event.accepted)
                AskService.cancel()
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: field.text === ""
            text: AskService.messages.length ? "Ask a follow-up…" : "Ask anything…"
            color: Theme.textMuted
            font: field.font
        }
    }
}
