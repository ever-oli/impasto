// ╭──────────────────────────────────────────────────────────────────────────╮
// │   A S K   S E R V I C E                                                  │
// │   the notch assistant: one ACP session through scripts/ask.py            │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // { role: "you" | "ai" | "tool", text }
    property var messages: []
    property bool busy: false
    property string thought: ""
    // { id, title, detail } while the agent waits for a yes or no.
    property var permission: null

    // What goes with the next question.
    property string screen: "none"      // none · screen · region
    property bool context: true         // focused window, clipboard, selection
    property bool act: false            // may operate the desktop, with approval
    property bool auto: false           // approve every action this session

    // ~/.config/impasto/modes/*.md, read by the bridge. A dropped file is a mode.
    property var modes: []
    property string mode: "general"
    readonly property var modeInfo: root.modes.find(m => m.id === root.mode) ?? { name: "General", icon: "󰚩" }
    // The Helium tab captured for the next question (Alt+Y).
    property string captured: ""

    function loadModes(): void { modesProcess.running = true }
    function stepMode(): void {
        const at = root.modes.findIndex(m => m.id === root.mode)
        if (root.modes.length)
            root.mode = root.modes[(at + 1) % root.modes.length].id
    }
    function capture(): void { root.send({ op: "capture" }) }

    readonly property Process modesProcess: Process {
        command: ["python3", Quickshell.shellPath("scripts/ask.py"), "modes"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { root.modes = JSON.parse(text) } catch (error) {} }
        }
    }

    readonly property var suggestions: [
        { icon: "󰹑", text: "Explain what's on my screen", screen: "screen" },
        { icon: "󰅍", text: "Summarise what I copied", screen: "none" },
        { icon: "󰨰", text: "Fix the error on screen", screen: "screen" },
        { icon: "󰗋", text: "Draft a reply to this", screen: "screen" }
    ]

    function push(role: string, text: string): void {
        root.messages = root.messages.concat([{ role: role, text: text }])
    }

    function appendAi(text: string): void {
        const last = root.messages[root.messages.length - 1]
        if (last && last.role === "ai") {
            const next = root.messages.slice(0, -1)
            next.push({ role: "ai", text: last.text + text })
            root.messages = next
        } else
            root.push("ai", text)
    }

    function send(cmd: var): void {
        bridge.running = true
        bridge.write(JSON.stringify(cmd) + "\n")
    }

    function ask(text: string, screen: string): void {
        const said = text.trim()
        if (said === "" || root.busy)
            return
        root.push("you", said)
        root.busy = true
        root.thought = ""
        root.send({ op: "ask", text: said, screen: screen ?? root.screen, context: root.context, act: root.act, mode: root.mode })
        root.screen = "none"
        root.captured = ""
    }

    function cancel(): void {
        root.send({ op: "cancel" })
        root.permission = null
    }

    function answer(allow: bool): void {
        if (!root.permission)
            return
        root.send({ op: "answer", id: root.permission.id, allow: allow })
        root.push("tool", `${allow ? "󰄬" : "󰅖"} ${root.permission.detail}`)
        root.permission = null
    }

    function reset(): void {
        root.cancel()
        root.send({ op: "reset" })
        root.messages = []
        root.busy = false
        root.auto = false
    }

    readonly property Process bridge: Process {
        command: ["python3", Quickshell.shellPath("scripts/ask.py")]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                let event
                try { event = JSON.parse(line) } catch (error) { return }
                switch (event.type) {
                case "chunk": root.thought = ""; root.appendAi(event.text); break
                case "thought": root.thought = (root.thought + event.text).slice(-160); break
                case "tool":
                    if (event.status === "pending" || event.status === "failed" || event.status === "")
                        root.push("tool", event.title)
                    break
                case "permission":
                    if (root.auto) {
                        root.send({ op: "answer", id: event.id, allow: true })
                        root.push("tool", `󰄬 ${event.detail}`)
                    } else
                        root.permission = event
                    break
                case "captured": root.captured = event.title; break
                case "visual":
                    if (event.path)
                        root.messages = root.messages.map(m => m.role === "ai"
                            ? { role: "ai", text: m.text.replace("```" + event.kind + "\n" + event.source + "```", "") } : m)
                    root.messages = root.messages.concat([{ role: "visual", text: event.source, path: event.path }])
                    break
                case "rolled": root.push("tool", "󰁨 Older turns summarised; the conversation goes on"); break
                case "done": root.busy = false; root.thought = ""; break
                case "error": root.busy = false; root.push("tool", `󰅚 ${event.text}`); break
                }
            }
        }
        onExited: {
            root.busy = false
            root.permission = null
        }
    }
}
