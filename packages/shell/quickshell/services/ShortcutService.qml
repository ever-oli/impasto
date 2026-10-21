// ╭──────────────────────────────────────────────────────────────────────────╮
// │   S H O R T C U T   S E R V I C E   (lean)                               │
// │   the key sheet, built from niri's binds                                 │
// ╰──────────────────────────────────────────────────────────────────────────╯
//
// niri has no IPC for its binds, so NiriService reads them out of the config
// (`hotkey-overlay-title="Group · Action"` names a row). Rebinding is done in
// the niri config itself; there is nothing to keep in sync here.

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Touched from shell.qml.
    readonly property bool catalogue: true

    // ── KEY SHEET ───────────────────────────────────────────────────────────
    //
    // The keys panel: everything bound right now, read from the niri config (scripts/niri_binds.py).
    // Binds sharing a category, modifiers and description up to a trailing
    // number or direction are folded into one row. Switches are left out.

    // Unlisted categories follow, in config order.
    readonly property var sheetOrder: ["Shell", "Applications", "Windows", "Workspaces",
                                       "Session", "Utilities", "Media"]

    readonly property var modifierCaps: [
        { bit: 4,  cap: "Ctrl" },
        { bit: 8,  cap: "Opt" },
        { bit: 64, cap: "Cmd" },
        { bit: 1,  cap: "Shift" }
    ]

    // Keycap labels where the xkb name will not do. Arrows come from the icon
    // font: the interface font lacks them and falls back to colour emoji.
    readonly property var keyCaps: ({
        left: "󰁍", right: "󰁔", up: "󰁝", down: "󰁅",
        TAB: "Tab", Return: "Enter", space: "Space", Escape: "Esc",
        comma: ",", period: ".", slash: "/", minus: "-", equal: "=",
        "mouse:272": "Left button", "mouse:273": "Right button",
        mouse_down: "Wheel down", mouse_up: "Wheel up",
        XF86AudioRaiseVolume: "Vol +", XF86AudioLowerVolume: "Vol −",
        XF86AudioMute: "Mute", XF86AudioMicMute: "Mic mute",
        XF86MonBrightnessUp: "Bright +", XF86MonBrightnessDown: "Bright −",
        XF86AudioPlay: "Play", XF86AudioNext: "Next", XF86AudioPrev: "Previous"
    })

    function capOf(key: string): string {
        if (root.keyCaps[key] !== undefined)
            return root.keyCaps[key]
        return key.startsWith("XF86") ? key.slice(4) : key
    }

    readonly property var sheet: {
        const groups = ({})
        const order = []
        for (const bind of NiriService.binds) {
            const key = bind.key || ""
            if (key === "" || key.startsWith("switch:"))
                continue
            const text = bind.description ?? ""
            const split = text.indexOf(" · ")
            const category = split < 0 ? "Other" : text.slice(0, split)
            const action = split < 0 ? (text || key) : text.slice(split + 3)

            // A trailing number or direction, which varies within a fold.
            const folded = action.match(/^(.*) (\d+|left|right|up|down)$/)
            const base = folded ? folded[1] : action
            const kind = !folded ? "" : (/^\d+$/.test(folded[2]) ? "digits" : "words")

            if (!groups[category]) {
                groups[category] = []
                order.push(category)
            }
            const rows = groups[category]
            const same = kind === "" ? null : rows.find(row => row.base === base
                && row.kind === kind && row.modmask === bind.modmask)
            if (same) {
                same.keys.push(key)
                continue
            }
            rows.push({ base: base, action: action, kind: kind,
                        modmask: bind.modmask, keys: [key] })
        }

        const ranked = order.slice().sort((a, b) => {
            const ia = root.sheetOrder.indexOf(a)
            const ib = root.sheetOrder.indexOf(b)
            return (ia < 0 ? 99 + order.indexOf(a) : ia) - (ib < 0 ? 99 + order.indexOf(b) : ib)
        })

        return ranked.map(category => ({
            name: category,
            // Opt (Alt) binds first; Cmd aliases after, config order kept within each.
            rows: groups[category].slice().sort((a, b) => ((a.modmask & 64) ? 1 : 0) - ((b.modmask & 64) ? 1 : 0)).map(row => {
                const caps = root.modifierCaps
                    .filter(modifier => row.modmask & modifier.bit)
                    .map(modifier => modifier.cap)
                const many = row.keys.length > 1
                if (many && row.kind === "digits")
                    caps.push(`${row.keys[0]}…${row.keys[row.keys.length - 1]}`)
                else
                    for (const key of row.keys)
                        caps.push(root.capOf(key))
                return { action: many ? row.base : row.action, caps: caps, keys: row.keys }
            })
        }))
    }

    readonly property int sheetCount: root.sheet.reduce((sum, group) => sum + group.rows.length, 0)

    // What a search term can start with: the words of the action and its
    // group, the caps, and the xkb names behind them (Return for Enter, each
    // digit of a folded run).
    function sheetWords(group: var, row: var): var {
        const words = `${group.name} ${row.action} ${row.caps.join(" ")} ${row.keys.join(" ")}`
            .toLowerCase().split(/[^a-z0-9]+/)
        for (const key of row.keys)
            words.push(key.toLowerCase())
        return words.filter(word => word !== "")
    }

    // The sheet as one list, headings between groups, keeping the rows every
    // term of `query` begins a word of. Terms split on spaces and on `+`.
    function sheetFind(query: string): var {
        const terms = query.toLowerCase().split(/[\s+]+/).filter(term => term !== "")
        const out = []
        for (const group of root.sheet) {
            const rows = group.rows.filter(row => {
                const words = root.sheetWords(group, row)
                return terms.every(term => words.some(word => word.startsWith(term)))
            })
            if (rows.length === 0)
                continue
            out.push({ heading: true, name: group.name })
            for (const row of rows)
                out.push({ heading: false, action: row.action, caps: row.caps })
        }
        return out
    }

    // Declared for the island: a field over a list that scrolls.
    readonly property int sheetWidth: 620
    readonly property int sheetHeight: 600
    readonly property int sheetFieldHeight: 36
    readonly property int sheetRowHeight: 36
    readonly property int sheetHeadingHeight: 32

    Component.onCompleted: NiriService.loadBinds()
}
