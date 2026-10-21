// ╭──────────────────────────────────────────────────────────────────────────╮
// │   M E N U   S E R V I C E                                                │
// │   the Omarchy-style command tree behind the palette                      │
// ╰──────────────────────────────────────────────────────────────────────────╯
//
// A node is { icon, name, subtitle } plus one of:
//   items            a folder of nodes
//   source + each    a folder filled from a shell command's lines
//                    ("label<TAB>value"), each running `each` with {} = value
//   input            a folder whose typed text becomes a row (input.row(term))
//   sh | term | url | panel | fn   what a leaf does
// `confirm: true` puts a yes/cancel step in front of a leaf.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    function q(text: string): string {
        return "'" + String(text).replace(/'/g, "'\\''") + "'"
    }

    readonly property string home: Quickshell.env("HOME")
    readonly property string done: '; echo; read -rsn1 -p "Done. Press a key to close."'

    // ── TREE ────────────────────────────────────────────────────────────────
    // Pending pacman + AUR updates (notch-updates), checked at start and hourly.
    property int updates: 0
    readonly property Process updateCheck: Process {
        command: ["sh", "-c", `PATH="$HOME/.local/bin:$PATH"; notch-updates count`]
        running: true
        stdout: StdioCollector { onStreamFinished: root.updates = parseInt(text) || 0 }
    }
    readonly property Timer updateTimer: Timer { interval: 3600000; repeat: true; running: true; onTriggered: root.updateCheck.running = true }

    readonly property var tree: [
        // Listed by LauncherService (`apps`), which owns the application index.
        { icon: "󰀻", name: "Apps", subtitle: "Every installed application", apps: true, items: [] },
    ].concat(root.updates > 0 ? [
        { icon: "󰚰", name: `Updates available (${root.updates})`, subtitle: "pacman + AUR · Enter runs yay -Syu", term: "notch-updates run" }
    ] : []).concat([
        { icon: "󰚩", name: "The agent", subtitle: "Profile, modes, reference files", items: [
            { icon: "󰑓", name: "Hand this to T3", subtitle: "The notch's context on the clipboard, T3 in front",
              sh: "qs ipc call context hand" },
            { icon: "󰀄", name: "Edit profile", subtitle: "Your CV, for the agent to read", sh: "ghostty -e helix ~/.config/notch/profile.md" },
            { icon: "󰘦", name: "Modes folder", subtitle: "The agent's modes: drop a .md file to add one", sh: "ghostty --working-directory=$HOME/.config/opencode/skill/notch/modes" },
            { icon: "󰈙", name: "Reference files", subtitle: "files/<mode>/ — PDF, DOCX, text", sh: "mkdir -p ~/.config/notch/files && xdg-open ~/.config/notch/files" }
        ] },
        { icon: "󰋖", name: "Learn", subtitle: "Keys, wikis, cheat sheets", items: [
            { icon: "󰌌", name: "Keys sheet", subtitle: "Every bind", panel: "keys" },
            { icon: "󰣇", name: "Arch wiki", url: "https://wiki.archlinux.org" },
            { icon: "󰕰", name: "niri wiki", url: "https://yalter.github.io/niri/" },
            { icon: "", name: "tmux cheat sheet", url: "https://tmuxcheatsheet.com" },
            { icon: "", name: "bash cheat sheet", url: "https://devhints.io/bash" }
        ] },
        { icon: "󰄀", name: "Capture", subtitle: "Screenshot, record, OCR, colour", items: [
            { icon: "󰩭", name: "Screenshot region", sh: "notch capture region" },
            { icon: "󰹑", name: "Screenshot screen", sh: "notch capture" },
            { icon: "󰕧", name: "Record screen", sh: "notch record" },
            { icon: "󱄽", name: "Copy text from screen", subtitle: "OCR a region",
              sh: 'g=$(slurp) && grim -g "$g" - | tesseract stdin - 2>/dev/null | wl-copy && notify-send "Text copied" "$(wl-paste | head -c 120)"' },
            { icon: "󰈊", name: "Colour picker", subtitle: "Copies the hex",
              sh: 'c=$(hyprpicker -a -n) && notify-send "Colour copied" "$c"' }
        ] },
        { icon: "󰔡", name: "Toggle", subtitle: "Do not disturb, bar, night light", items: [
            { icon: "󰂛", name: "Do not disturb", on: "dnd", sh: "notch focus toggle" },
            { icon: "󰍜", name: "Show or hide the bar", on: "bar", fn: "bar" },
            { icon: "󰖔", name: "Night light", subtitle: "Warm screen, 4000 K", on: "night",
              sh: "pkill -x wlsunset || setsid -f wlsunset -t 4000 -T 4001 -S 00:00 -s 00:01 -d 1" },
            { icon: "󰈈", name: "Show hidden commands", subtitle: "Bring back everything hidden with Ctrl+K", fn: "unhide" }
        ] },
        { icon: "󰀠", name: "Reminders", subtitle: "Set, list, clear", items: [
            { icon: "󰀠", name: "Set a reminder", subtitle: "Type minutes then text: 10 stretch",
              input: { hint: "10 stretch", row: term => {
                  const m = /^(\d+)\s+(.+)$/.exec(term)
                  return m ? { icon: "󰀠", name: `In ${m[1]} min: ${m[2]}`,
                      sh: `systemd-run --user --unit=reminder-$(date +%s) --on-active=${m[1]}m notify-send -u critical Reminder ${root.q(m[2])} && notify-send "Reminder set" ${root.q(`In ${m[1]} min`)}` }
                      : { icon: "󰀠", name: "Minutes then text", subtitle: "10 stretch" }
              } } },
            { icon: "󰃰", name: "Show reminders", itemIcon: "󰀠",
              source: "systemctl --user list-timers 'reminder-*' --no-legend | awk '{print $1\" \"$2\" \"$3\"\\t\"$(NF-1)}'",
              each: "systemctl --user stop {}" },
            { icon: "󰎟", name: "Clear all reminders", sh: "systemctl --user stop 'reminder-*.timer' && notify-send 'Reminders cleared'" }
        ] },
        { icon: "󰒖", name: "Share", subtitle: "LocalSend", items: [
            { icon: "󰒖", name: "Open LocalSend", sh: "localsend" },
            { icon: "󰅍", name: "Send the clipboard", subtitle: "Opens LocalSend with it as text",
              sh: "f=/tmp/clipboard-$(date +%s).txt; wl-paste > $f && localsend $f" }
        ] },
        { icon: "󰏘", name: "Style", subtitle: "Theme, font, wallpaper, corners", items: [
            { icon: "󰏘", name: "Theme", subtitle: "Carousel: arrows preview, Enter keeps", sh: "notch picker theme" },
            { icon: "󰛖", name: "Font", subtitle: "Terminal", itemIcon: "󰛖",
              source: "fc-list : family | grep 'Nerd Font Mono' | cut -d, -f1 | sort -u",
              each: "notch-font {}" },
            { icon: "󰛂", name: "Font size", subtitle: "Slider: drag to preview, applies to every app", sh: "qs ipc call fontsize open" },
            { icon: "󰸉", name: "Wallpaper", subtitle: "Carousel of this theme's backgrounds", sh: "notch picker wallpaper" },
            { icon: "󰢡", name: "Corners", items: [
                { icon: "󰝤", name: "Sharp windows", sh: "sed -i 's/geometry-corner-radius [0-9]*/geometry-corner-radius 0/' ~/.config/niri/config.kdl" },
                { icon: "󰢡", name: "Round windows", sh: "sed -i 's/geometry-corner-radius [0-9]*/geometry-corner-radius 14/' ~/.config/niri/config.kdl" }
            ] }
        ] },
        { icon: "󰒓", name: "Setup", subtitle: "Audio, defaults, DNS, niri", items: [
            { icon: "󰕾", name: "Audio output", subtitle: "Devices and volume", panel: "sound" },
            { icon: "󰖟", name: "Default browser", itemIcon: "󰖟",
              source: "grep -l 'Categories=.*WebBrowser' /usr/share/applications/*.desktop ~/.local/share/applications/*.desktop 2>/dev/null | xargs -n1 basename",
              each: "xdg-settings set default-web-browser {} && notify-send 'Default browser' {}" },
            { icon: "", name: "Default editor", subtitle: "$EDITOR in ~/.config/environment.d",
              term: "${EDITOR:-helix} ~/.config/environment.d/editor.conf" },
            { icon: "󰖩", name: "DNS", items: [
                { icon: "󰖩", name: "Cloudflare", term: "printf '[Resolve]\\nDNS=1.1.1.1 1.0.0.1\\n' | sudo tee /etc/systemd/resolved.conf.d/dns.conf && sudo systemctl restart systemd-resolved" },
                { icon: "󰖩", name: "Google", term: "printf '[Resolve]\\nDNS=8.8.8.8 8.8.4.4\\n' | sudo tee /etc/systemd/resolved.conf.d/dns.conf && sudo systemctl restart systemd-resolved" },
                { icon: "󰖩", name: "Automatic (DHCP)", term: "sudo rm -f /etc/systemd/resolved.conf.d/dns.conf && sudo systemctl restart systemd-resolved" }
            ] },
            { icon: "󰘳", name: "Edit niri config", sh: "ghostty -e helix ~/.config/niri/config.kdl" }
        ] },
        { icon: "󰏓", name: "Install", subtitle: "Packages from pacman and the AUR", items: [
            { icon: "󰏓", name: "Install package", subtitle: "pacman", term: "pacman -Slq | fzf --multi --preview 'pacman -Si {1}' | xargs -ro sudo pacman -S" },
            { icon: "󰏓", name: "Install from the AUR", term: "yay -Slqa | fzf --multi --preview 'yay -Si {1}' | xargs -ro yay -S" },
            { icon: "󰆴", name: "Remove package", term: "pacman -Qqe | fzf --multi --preview 'pacman -Qi {1}' | xargs -ro sudo pacman -Rns" }
        ] },
        { icon: "󰐱", name: "Extras", subtitle: "Tailscale, Ollama, Docker, mise", items: [
            { icon: "󰖂", name: "Tailscale up", term: "sudo systemctl enable --now tailscaled && sudo tailscale up" },
            { icon: "󱚤", name: "Install Ollama", term: "sudo pacman -S --needed ollama && sudo systemctl enable --now ollama" },
            { icon: "󰡨", name: "Install Docker", term: "sudo pacman -S --needed docker docker-compose && sudo systemctl enable --now docker && sudo usermod -aG docker $USER" },
            { icon: "", name: "Node LTS via mise", term: "mise use -g node@lts" }
        ] },
        { icon: "󰚰", name: "Update", subtitle: "System, shell, portal, audio, time zone", items: [
            { icon: "󰚰", name: "Update the system", term: "yay -Syu" },
            { icon: "󰑓", name: "Restart the shell", sh: "pkill -x qs; sleep 0.5; setsid -f qs -n" },
            { icon: "󰹑", name: "Restart screen sharing", sh: "systemctl --user restart xdg-desktop-portal-wlr && notify-send 'Screen sharing restarted'" },
            { icon: "󰕾", name: "Restart audio", sh: "systemctl --user restart pipewire pipewire-pulse wireplumber && notify-send 'Audio restarted'" },
            { icon: "󰥔", name: "Time zone", itemIcon: "󰥔", source: "timedatectl list-timezones", each: "timedatectl set-timezone {}" }
        ] },
        { icon: "󰐥", name: "System", subtitle: "Lock, log out, restart, shut down", items: [
            { icon: "󰌾", name: "Lock", sh: "swaylock -f -c 000000" },
            { icon: "󰗽", name: "Log out", confirm: true, sh: "niri msg action quit --skip-confirmation" },
            { icon: "󰜉", name: "Restart", confirm: true, sh: "systemctl reboot" },
            { icon: "󰐥", name: "Shut down", confirm: true, sh: "systemctl poweroff" }
        ] }
    ])

    // Recount a few minutes after an update was started from the palette.
    readonly property Timer refreshAfterUpdate: Timer { interval: 300000; onTriggered: root.updateCheck.running = true }

    // ── NAVIGATION ──────────────────────────────────────────────────────────
    property var stack: []
    property var loaded: []
    readonly property var top: root.stack.length ? root.stack[root.stack.length - 1] : null
    readonly property string trail: root.stack.map(n => n.name).join("  ›  ")

    function push(node: var): void {
        root.stack = root.stack.concat([node])
        root.load()
    }
    function pop(): void {
        root.stack = root.stack.slice(0, -1)
        root.load()
    }
    function reset(): void {
        root.stack = []
        root.loaded = []
    }
    function load(): void {
        root.loaded = []
        if (root.top?.source) {
            lines.running = false
            lines.command = ["sh", "-c", `PATH="$HOME/.local/bin:$PATH"; ${root.top.source}`]
            lines.running = true
        }
    }

    readonly property Process lines: Process {
        stdout: StdioCollector {
            onStreamFinished: root.loaded = text.split("\n").filter(l => l.trim() !== "")
        }
    }

    function childrenOf(node: var): var {
        if (node.items)
            return node.items
        if (node.source)
            return root.loaded.map(line => {
                const [label, value] = line.split("\t")
                return { icon: node.itemIcon ?? "", name: label, subtitle: value && value !== label ? value : "",
                         sh: node.each.replace(/\{\}/g, root.q(value ?? label)) }
            })
        return []
    }

    // Every leaf under the root, for a search typed at the top.
    readonly property var leaves: {
        const out = []
        const walk = (nodes, path) => {
            for (const n of nodes) {
                if (n.items)
                    walk(n.items, path.concat([n.name]))
                out.push(Object.assign({}, n, { path: path.join("/"), subtitle: path.length ? path.concat([n.name]).join(" › ") + (n.subtitle ? "  ·  " + n.subtitle : "") : n.subtitle }))
            }
        }
        walk(root.tree, [])
        return out
    }

    // Subsequence match: contiguous and word-start hits score higher; -1 is no match.
    function fuzzy(term: string, text: string): real {
        if (term === "")
            return 0
        const t = text.toLowerCase()
        const at = t.indexOf(term)
        if (at >= 0)
            return 100 - at + (at === 0 || t[at - 1] === " " ? 50 : 0)
        let i = 0, score = 0, last = -2
        for (let j = 0; j < t.length && i < term.length; j++) {
            if (t[j] !== term[i])
                continue
            score += (j === last + 1 ? 3 : 1) + (j === 0 || t[j - 1] === " " ? 2 : 0)
            last = j
            i++
        }
        return i === term.length ? score : -1
    }

    function filter(nodes: var, term: string): var {
        if (term === "")
            return nodes
        return nodes.map(n => ({ n: n, s: root.fuzzy(term, n.name + " " + (n.subtitle ?? "")) }))
            .filter(x => x.s >= 0).sort((a, b) => b.s - a.s).map(x => x.n)
    }

    function row(node: var): var {
        const folder = !!(node.items || node.source || node.input)
        return { kind: folder ? "menu" : "command", id: node.name, node: node,
                 icon: node.icon ?? "", name: node.name, subtitle: node.subtitle ?? "",
                 sigil: folder ? "›" : "" }
    }

    // What the palette lists inside a folder.
    function results(term: string): var {
        const node = root.top
        let found = root.filter(root.childrenOf(node), term)
        if (node.input)
            found = term !== "" ? [node.input.row(term)] : [{ icon: node.icon, name: node.subtitle ?? node.name, subtitle: "Type, then Enter" }]
        return found.slice(0, 200).map(root.row)
    }

    // ── RUNNING ─────────────────────────────────────────────────────────────
    // Answers "stay" (the palette moved), "close", or a panel name.
    function run(node: var): string {
        if (node.items || node.source || node.input) {
            root.push(node)
            return "stay"
        }
        if (node.confirm) {
            root.push({ icon: node.icon, name: node.name, items: [
                Object.assign({}, node, { confirm: false, name: `Yes, ${node.name.toLowerCase()}` }),
                { icon: "󰜺", name: "Cancel", fn: "back" }
            ] })
            return "stay"
        }
        if (node.fn === "back") {
            root.pop()
            return "stay"
        }
        if (node.fn === "unhide")
            LauncherService.unhideAll()
        else if (node.fn === "bar")
            SettingsService.set("barHidden", !SettingsService.barHidden)
        else if (node.panel)
            return node.panel
        else if (node.url)
            Quickshell.execDetached(["xdg-open", node.url])
        else if (node.term)
            Quickshell.execDetached(["ghostty", "-e", "bash", "-c", `PATH="$HOME/.local/bin:$PATH"; ${node.term}${root.done}`])
        if (node.term && node.term.indexOf("notch-updates run") >= 0)
            root.refreshAfterUpdate.restart()
        else if (node.sh)
            Quickshell.execDetached(["sh", "-c", `PATH="$HOME/.local/bin:$PATH"; ${node.sh}`])
        else
            return "stay"
        return "close"
    }
}
