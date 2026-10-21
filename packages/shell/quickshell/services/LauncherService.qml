// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   L A U N C H E R   S E R V I C E                                        │
// │   application index · search and activation                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

// Application index and launcher query logic.
//
// The first character selects the mode: plain text searches applications, and
// a sigil switches to calculator, shell entries (`>`), windows, timer,
// clipboard or emoji. Modes are explicit so `100` or `5:30` is never misread as a sum
// or a duration.
QtObject {
    id: root

    readonly property int maxResults: SettingsService.launcherResults

    // The prefix-less mode must be last. Sigils come from the settings
    // (`SettingsService.launcherPrefixDefaults`).
    readonly property var modes: [
        { id: "calculate", prefix: SettingsService.launcherPrefix("calculate"),
          label: "Calculate", icon: "󰃬",
          hint: "Work something out",  empty: "An expression — 12 * 34, (5 + 5) / 2" },
        { id: "desk",      prefix: SettingsService.launcherPrefix("desk"),
          label: "Desk",      icon: "󰍜",
          hint: "Open a panel or an action",
          empty: "Nothing on the desk by that name" },
        { id: "windows",   prefix: SettingsService.launcherPrefix("windows"),
          label: "Windows",   icon: "󰖯",
          hint: "Find an open window", empty: "No window by that name is open" },
        { id: "clipboard", prefix: SettingsService.launcherPrefix("clipboard"),
          label: "Clipboard", icon: "󰅍",
          hint: "Copy something again",
          empty: ClipboardService.entries.length === 0
              ? "Nothing has been copied yet" : "Nothing copied says that" },
        { id: "emoji",     prefix: SettingsService.launcherPrefix("emoji"),
          label: "Emoji",     icon: "󰇲",
          hint: "Copy an emoji",       empty: "No emoji by that name" },
        { id: "files",     prefix: SettingsService.launcherPrefix("files"),
          label: "Files",     icon: "󰈞",
          hint: "Find a file in your home", empty: "Type part of a path — Enter opens, Shift+Enter opens a terminal there" },
        { id: "apps",      prefix: "",  label: "Apps",      icon: "󰀻",
          hint: "Search applications",
          empty: `No application matches. Type ${SettingsService.launcherPrefix("desk")} for what the shell itself can do.` }
    ]

    function modeFor(query: string): var {
        const raw = query ?? ""
        for (const mode of root.modes) {
            if (mode.prefix !== "" && raw.startsWith(mode.prefix))
                return mode
        }
        return root.modes[root.modes.length - 1]
    }

    function termFor(query: string): string {
        return (query ?? "").slice(root.modeFor(query).prefix.length).trim()
    }

    // ── QUERY AND SIZE ──────────────────────────────────────────────────────
    //
    // The query lives here, not in the panel, because with `launcherFits` the
    // panel height depends on the results and the island must know its size
    // before the panel exists. Cleared when the panel closes.
    property string query: ""
    onQueryChanged: {
        const mode = root.modeFor(root.query)
        const raw = root.termFor(root.query)
        if (mode.id === "files")
            FinderService.findFiles(raw)
        else if (mode.id === "calculate" || mode.id === "apps")
            FinderService.calculate(raw)
    }

    readonly property var results: root.search(root.query)

    // Panel metrics, shared with the layout so the height math stays in sync.
    readonly property int fieldHeight: 34
    readonly property int rowHeight: 48
    readonly property int rowSpacing: 2
    readonly property int gap: 12

    // The emoji mode's row of groups, under the field.
    readonly property int stripHeight: 30
    readonly property bool showsStrip: root.modeFor(root.query).id === "emoji"

    // The emoji mode is a grid of glyphs rather than rows: square cells, as
    // many to a line as the panel holds.
    readonly property int emojiCell: 52
    readonly property int emojiColumns:
        Math.floor((root.panelWidth - 2 * Theme.panelPadding) / root.emojiCell)

    // Field, divider, and the gap on either side of the divider, plus the
    // strip and its gap when it shows.
    readonly property int chromeHeight: root.fieldHeight + 2 * root.gap + 1
        + (root.showsStrip ? root.stripHeight + root.gap : 0)

    // At least one row, for the "no results" line. The grid counts lines of
    // glyphs, capped at the same number as a list of rows.
    readonly property int rows: root.showsStrip
        ? Math.max(1, Math.min(Math.ceil(root.results.length / root.emojiColumns),
                               root.maxResults))
        : Math.max(1, Math.min(root.results.length, root.maxResults))

    function listHeight(rows: int): int {
        return rows * root.rowHeight + (rows - 1) * root.rowSpacing
    }

    // A full grid stops where a full list does, strip included, so the two
    // modes open to one height; the grid scrolls under its last partial line.
    function heightFor(rows: int): int {
        const list = root.showsStrip
            ? Math.min(rows * root.emojiCell,
                       root.listHeight(root.maxResults) - root.stripHeight - root.gap)
            : root.listHeight(rows)
        return root.chromeHeight + list + 2 * Theme.panelPadding
    }

    readonly property int panelWidth: 560

    // Fixed height with a scrolling list, or (`launcherFits`) sized to the
    // results up to `maxResults` rows.
    readonly property int panelHeight:
        SettingsService.launcherFits ? root.heightFor(root.rows) : 520

    // Whitelist: the expression is passed to a JavaScript evaluator.
    readonly property var arithmetic: /^[0-9+\-*/(). %]+$/

    property var applications: []

    // ── LAUNCH HISTORY ──────────────────────────────────────────────────────
    //
    // Results are ranked by a launch count with exponential decay (frecency),
    // stored in the state directory.
    readonly property string order: SettingsService.launcherOrder

    readonly property real halfLife: 30 * 24 * 3600 * 1000

    // Mirrors the adapter; reading a JsonAdapter back in the same turn as a
    // write returns the old value.
    property var launches: ({})

    readonly property FileView historyFile: FileView {
        path: `${SettingsService.stateDirectory}/launcher-history.json`
        watchChanges: true

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: root.launches = history.launches ?? ({})
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter()
        }

        JsonAdapter {
            id: history

            // Desktop id -> { count, last }. Decay is applied on read.
            property var launches: ({})
        }
    }

    function scoreOf(id: string): real {
        const row = root.launches[id]
        if (!row || !row.count)
            return 0
        const age = Date.now() - (row.last ?? 0)
        return row.count * Math.pow(0.5, age / root.halfLife)
    }

    function record(id: string): void {
        if (!id)
            return
        const next = Object.assign({}, root.launches)
        next[id] = { count: root.scoreOf(id) + 1, last: Date.now() }
        root.launches = next
        history.launches = next
    }

    // ── PALETTE PREFS ───────────────────────────────────────────────────────
    //
    // Pins, aliases, hidden rows, learned terms (typed query -> the row picked
    // for it) and recent queries, keyed by `keyOf`. One small JSON file.
    property var prefs: ({ pins: [], aliases: {}, hidden: [], learned: {}, recent: [] })

    readonly property FileView prefsFile: FileView {
        path: `${SettingsService.stateDirectory}/palette.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: root.prefs = Object.assign({ pins: [], aliases: {}, hidden: [], learned: {}, recent: [] }, prefsAdapter.prefs ?? {})
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter { id: prefsAdapter; property var prefs: ({}) }
    }

    function keyOf(e: var): string {
        if (!e) return ""
        if (e.key) return e.key
        if (e.kind === "app") return `app:${e.id}`
        if (e.kind === "menu" || e.kind === "command") return `cmd:${e.node?.path ?? ""}/${e.node?.name ?? e.name}`
        return `${e.kind}:${e.id}`
    }

    function savePrefs(change: var): void {
        const next = Object.assign({}, root.prefs, change)
        root.prefs = next
        prefsAdapter.prefs = next
    }

    function togglePin(e: var): void {
        const k = root.keyOf(e), pins = root.prefs.pins.filter(p => p !== k)
        root.savePrefs({ pins: pins.length === root.prefs.pins.length ? pins.concat([k]) : pins })
    }
    function hide(e: var): void { root.savePrefs({ hidden: root.prefs.hidden.concat([root.keyOf(e)]) }) }
    function unhideAll(): void { root.savePrefs({ hidden: [] }) }
    function setAlias(alias: string, e: var): void {
        const a = Object.assign({}, root.prefs.aliases); a[alias.toLowerCase()] = root.keyOf(e)
        root.savePrefs({ aliases: a })
    }
    function learn(term: string, e: var): void {
        const t = term.trim().toLowerCase()
        if (t === "" || !e) return
        const l = Object.assign({}, root.prefs.learned); l[t] = root.keyOf(e)
        root.savePrefs({ learned: l, recent: [term].concat(root.prefs.recent.filter(r => r !== term)).slice(0, 20) })
        root.record(root.keyOf(e))
    }

    // Every pickable row at the root: apps and every palette leaf.
    function catalogue(): var {
        const rows = MenuService.leaves.map(MenuService.row).map(root.mark)
        return rows.concat(root.applications)
    }
    function byKey(k: string): var {
        return root.catalogue().find(e => root.keyOf(e) === k) ?? null
    }

    // ✓ on toggles that are on.
    property bool nightOn: false
    readonly property Process nightProbe: Process {
        command: ["pgrep", "-x", "wlsunset"]
        onExited: code => root.nightOn = code === 0
    }
    function mark(row: var): var {
        const on = row.node?.on
        if (!on) return row
        const lit = on === "dnd" ? NotificationService.doNotDisturb
            : on === "bar" ? !SettingsService.barHidden : root.nightOn
        return lit ? Object.assign({}, row, { name: row.name + "  ✓" }) : row
    }

    // Pinned and learned rows to the front, hidden ones out, web rows when
    // nothing else matched.
    function arrange(list: var, term: string): var {
        const hidden = root.prefs.hidden
        let out = list.filter(e => hidden.indexOf(root.keyOf(e)) < 0)
        const boost = e => {
            const k = root.keyOf(e)
            return (root.prefs.aliases[term] === k ? 2000 : 0) + (root.prefs.learned[term] === k ? 1000 : 0)
                + (root.prefs.pins.indexOf(k) >= 0 ? 5 : 0) + (e.kind === "app" ? 0 : root.scoreOf(k))
        }
        for (const k of [root.prefs.aliases[term], root.prefs.learned[term]]) {
            if (k && !out.some(e => root.keyOf(e) === k)) {
                const e = root.byKey(k)
                if (e && hidden.indexOf(k) < 0) out = [e].concat(out)
            }
        }
        const front = out.filter(e => boost(e) >= 1).sort((a, b) => boost(b) - boost(a))
        const rest = out.filter(e => boost(e) < 1)
        out = front.concat(rest)
        if (out.length === 0 && term !== "")
            out = root.webRows(term)
        return out
    }

    function webRows(term: string): var {
        return [["DuckDuckGo", "https://duckduckgo.com/?q="], ["Google", "https://www.google.com/search?q="]]
            .map(([n, u]) => ({ kind: "web", id: u + encodeURIComponent(term), icon: "󰖟",
                                name: `Search ${n} for “${term}”`, subtitle: "Opens in Helium" }))
    }

    // ── ACTION PANEL (Ctrl+K) ───────────────────────────────────────────────
    property var actionTarget: null
    property var aliasTarget: null
    signal pickRequested(int index)

    function actionRows(e: var): var {
        const pinned = root.prefs.pins.indexOf(root.keyOf(e)) >= 0
        return [
            { kind: "act", id: "open", icon: "󰐊", name: "Open", subtitle: e.name },
            { kind: "act", id: "copy", icon: "󰆏", name: "Copy name", subtitle: "Ctrl+Enter does this from the list" },
            { kind: "act", id: "pin", icon: "󰐃", name: pinned ? "Unpin" : "Pin to the top", subtitle: "Shown first on an empty search" },
            { kind: "act", id: "alias", icon: "󰌌", name: "Set an alias…", subtitle: "Type a short word, then Enter" },
            { kind: "act", id: "hide", icon: "󰈉", name: "Hide from search", subtitle: "Toggle › Show hidden commands brings it back" }
        ]
    }

    // ── FAVOURITES ──────────────────────────────────────────────────────────
    //
    // The dock's pinned apps, read from the settings rather than `DockService`
    // (which depends on this service). They get a bonus of one launch.
    readonly property var favourites: SettingsService.dockPinned ?? []

    function weightOf(app: var): real {
        return root.scoreOf(app.id)
            + (root.favourites.indexOf(app.id) >= 0 ? 1 : 0)
    }

    readonly property Process applicationsProcess: Process {
        command: [Quickshell.shellPath("scripts/applications.py")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "")
                    return
                try {
                    root.applications = JSON.parse(text)
                } catch (error) {
                    console.warn("Cannot parse the application list:", error)
                }
            }
        }
    }

    // Launches use execDetached, not Process: a Process child dies with a
    // config reload, and gtk-launch run that way exits 0 without launching.

    function refresh(): void {
        root.applicationsProcess.running = true
        root.nightProbe.running = true
    }

    function search(query: string): var {
        if (root.actionTarget)
            return root.actionRows(root.actionTarget)
        if (root.aliasTarget) {
            const a = (query ?? "").trim()
            return [{ kind: "act", id: "alias-save", icon: "󰌌", alias: a,
                      name: a ? `Alias “${a}” → ${root.aliasTarget.name}` : `Type an alias for ${root.aliasTarget.name}`,
                      subtitle: "Enter saves, Esc cancels" }]
        }
        const mode = root.modeFor(query)
        const raw = root.termFor(query)
        const term = raw.toLowerCase()

        switch (mode.id) {
        case "calculate":
            return root.calculate(raw)
        case "files":
            return root.fileRows()
        case "desk":
            return root.desk(term)
        case "windows":
            return root.windows(term)
        case "clipboard":
            return root.clipboard(term)
        case "emoji":
            return root.emoji(term)
        }

        // Inside a palette folder the tree answers; at the top the folders
        // (and, once typed, every command under them) sit with the apps.
        if (MenuService.top?.apps)
            return root.rank(term)
        if (MenuService.top)
            return MenuService.results(term)
        const ask = { kind: "panel", id: "ask", panel: "ask", icon: "󰚩", name: "Ask",
                      subtitle: "The assistant, with your screen as context" }
        const windowsFolder = { kind: "mode", id: "windows", icon: "󰖯", name: "Windows",
                                subtitle: "Switch to an open window", sigil: SettingsService.launcherPrefix("windows") }
        if (term === "") {
            const pins = root.prefs.pins.map(root.byKey).filter(e => e)
                .map(e => Object.assign({}, e, { key: root.keyOf(e), subtitle: "󰐃 Pinned" + (e.subtitle ? "  ·  " + e.subtitle : "") }))
            return pins.concat(MenuService.tree.slice(0, 1).map(MenuService.row).concat([ask, windowsFolder],
                MenuService.tree.slice(1).map(MenuService.row), root.rank(term)))
        }
        const top = root.calculate(raw).concat(root.quicklinkRows(raw))
        const extras = root.snippetRows(term).concat(root.sshRows(term), root.windows(term).slice(0, 3), root.bindRows(term))
        const commands = MenuService.filter(MenuService.leaves, term).map(MenuService.row).map(root.mark)
        const lead = commands.filter(c => c.name.toLowerCase().startsWith(term))
        const rest = commands.filter(c => !c.name.toLowerCase().startsWith(term))
        const asks = "ask".startsWith(term) ? [ask] : []
        const folders = root.fuzzyName(windowsFolder.name, term) ? [windowsFolder] : []
        return root.arrange(top.concat(asks, lead, root.rank(term).slice(0, root.maxResults), extras, folders, rest), term)
    }

    // All applications matching `term`, sorted by:
    //
    //   1. name starts with the term (applies in every order)
    //   2. weight: decayed launches plus the favourite bonus
    //   3. dock order, between two favourites of equal weight
    //   4. name
    //
    // With `order` set to alphabetical only 1 and 4 apply.
    function rank(term: string): var {
        const found = []
        for (const app of root.applications) {
            if (term !== "" && !app.name.toLowerCase().includes(term)
                    && !app.keywords.includes(term))
                continue
            found.push(app)
        }

        const byUse = root.order !== "alphabetical"
        found.sort((a, b) => {
            if (term !== "") {
                const leadA = a.name.toLowerCase().startsWith(term) ? 0 : 1
                const leadB = b.name.toLowerCase().startsWith(term) ? 0 : 1
                if (leadA !== leadB)
                    return leadA - leadB
            }
            if (byUse) {
                const weight = root.weightOf(b) - root.weightOf(a)
                if (Math.abs(weight) > 0.0001)
                    return weight
                const keptA = root.favourites.indexOf(a.id)
                const keptB = root.favourites.indexOf(b.id)
                if (keptA >= 0 && keptB >= 0 && keptA !== keptB)
                    return keptA - keptB
            }
            return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1
        })
        return found
    }

    // qalc answers asynchronously (`FinderService`); the row appears when it does.
    function calculate(expression: string): var {
        const value = FinderService.calcFor(expression)
        if (value === "")
            return []
        return [{
            kind: "calculation", id: "", icon: "󰃬",
            name: value, subtitle: `${expression}  ·  Enter copies it`
        }]
    }

    function fuzzyName(name: string, term: string): bool {
        return FinderService.fuzzy(name, term) >= 0
    }

    function quicklinkRows(raw: string): var {
        const hit = FinderService.quicklinkFor(raw)
        return hit ? [{ kind: "quicklink", id: hit.link.key, icon: "󰖟", link: hit.link, term: hit.term,
                        name: `${hit.link.name}: ${hit.term}`, subtitle: "Enter opens it in Helium" }] : []
    }

    function snippetRows(term: string): var {
        return FinderService.snippets
            .map(sn => ({ sn: sn, score: Math.min(...[sn.name, sn.keyword ?? ""].map(h => {
                const v = FinderService.fuzzy(h, term); return v < 0 ? 99 : v })) }))
            .filter(x => x.score < 4).sort((a, b) => a.score - b.score).slice(0, 4)
            .map(x => ({ kind: "snippet", id: x.sn.name, icon: "󰅪", text: x.sn.text,
                         name: x.sn.name, subtitle: `${x.sn.keyword ? x.sn.keyword + "  ·  " : ""}Enter types: ${x.sn.text.replace(/\n/g, " ⏎ ").slice(0, 60)}` }))
    }

    // ── KEYBINDS (idea from k4ditano/k4, MIT) ──────────────────────────────
    // Every niri bind as a row, found by what it does. Enter runs it unless the
    // action is one that ends something (quit, close, power, session).
    readonly property var unsafeBind: /^(quit|close-window|power-off-monitors|suspend)\b|"(systemctl|loginctl|poweroff|reboot)"|"session"/
    function bindRows(term: string): var {
        if (term.length < 2)
            return []
        return NiriService.binds
            .map(b => ({ b: b, score: FinderService.fuzzy(b.description, term) }))
            .filter(x => x.score >= 0 && x.score < 4).sort((a, b) => a.score - b.score).slice(0, 4)
            .map(x => {
                const safe = !!x.b.action && !root.unsafeBind.test(x.b.action)
                return { kind: "bind", id: x.b.description, icon: "󰌌", action: x.b.action, safe: safe,
                         name: x.b.description,
                         subtitle: `${NiriService.spell(x.b)}  ·  ${safe ? "Enter runs it" : "shown only"}` }
            })
    }
    function runBind(action: string): void {
        const args = (action.match(/"[^"]*"|\S+/g) ?? []).map(a => a.replace(/^"|"$/g, ""))
        if (args[0] === "spawn")
            Quickshell.execDetached(args.slice(1))
        else if (args[0] === "spawn-sh")
            Quickshell.execDetached(["sh", "-c", args.slice(1).join(" ")])
        else if (args.length)
            Quickshell.execDetached(["niri", "msg", "action"].concat(args))
    }

    // ── SSH QUICK-CONNECT (idea from k4ditano/k4, MIT) ─────────────────────
    // `Host` entries of ~/.ssh/config (and its Includes); Enter opens Ghostty on it.
    property var sshHosts: []
    readonly property Process sshProcess: Process {
        running: true
        command: ["sh", "-c", "cat ~/.ssh/config ~/.ssh/config.d/* 2>/dev/null | awk 'tolower($1)==\"host\"{for(i=2;i<=NF;i++) if($i !~ /[*?!]/) print $i}' | sort -u"]
        stdout: StdioCollector { onStreamFinished: root.sshHosts = text.split("\n").filter(h => h) }
    }
    function sshRows(term: string): var {
        if (term === "")
            return []
        if (term.length < 3 && !"ssh".startsWith(term))
            return []
        sshProcess.running = true
        const bare = term.replace(/^ssh\s*/, "")
        return root.sshHosts.filter(h => bare === "" || FinderService.fuzzy(h, bare) >= 0).slice(0, 5)
            .map(h => ({ kind: "ssh", id: h, icon: "󰣀", name: `SSH: ${h}`, subtitle: "Enter opens Ghostty connected to it" }))
    }

    function fileRows(): var {
        return FinderService.files.map(path => {
            const slash = path.replace(/\/$/, "").lastIndexOf("/")
            const isDir = path.endsWith("/")
            return { kind: "file", id: path, icon: isDir ? "󰉋" : "󰈔",
                     name: path.replace(/\/$/, "").slice(slash + 1),
                     subtitle: path.slice(0, slash).replace(FinderService.home, "~") }
        })
    }

    // ── DESK MODE ───────────────────────────────────────────────────────────
    //
    // The `>` list: the control centre's doors, the other launcher modes, and
    // the one-shot tiles (`closes`). Stateful toggles are left out since a
    // list row cannot show their state, as are the launcher itself and
    // anything unavailable. Matches on label and subtitle.
    function desk(term: string): var {
        const lead = []
        const rest = []

        function offer(entry) {
            if (term === "") {
                rest.push(entry)
                return
            }
            const name = entry.name.toLowerCase()
            if (name.startsWith(term))
                lead.push(entry)
            else if (name.includes(term) || entry.subtitle.toLowerCase().includes(term))
                rest.push(entry)
        }

        for (const door of ControlsService.doors) {
            if (door.id === "launcher")
                continue
            offer({
                kind: "panel", id: door.id, icon: door.icon,
                name: door.label, subtitle: door.detail, panel: door.panel
            })
        }

        // The four ink themes, applied by `notch-theme`.
        for (const theme of ThemeService.themes) {
            const title = theme.split("-").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ")
            offer({
                kind: "theme", id: theme, icon: theme === ThemeService.activeId ? "󰄬" : "󰏘",
                name: `Theme: ${title}`, subtitle: theme === ThemeService.activeId
                    ? "In use" : "Shell, terminal, Helix, niri, fuzzel, wallpaper"
            })
        }

        for (const mode of root.modes) {
            // Skip the current mode and the plain-text one.
            if (mode.id === "desk" || mode.prefix === "")
                continue
            // Not advertised while history is off; the sigil still works.
            if (mode.id === "clipboard" && !SettingsService.clipboardHistory)
                continue
            offer({
                kind: "mode", id: mode.id, icon: mode.icon,
                name: mode.label, subtitle: mode.hint, sigil: mode.prefix
            })
        }

        // Indexed: `toggleCatalogue` is a QML list, not a JS array.
        for (let index = 0; index < ControlsService.toggleCatalogue.length; index++) {
            const tile = ControlsService.toggleCatalogue[index]
            if (!tile.closes || !tile.available)
                continue
            offer({
                kind: "action", id: tile.key, icon: tile.icon,
                name: tile.label, subtitle: tile.detail
            })
        }

        // Not truncated to `maxResults`: the list is short, and cutting it
        // would hide the actions behind the doors. The panel still caps its
        // visible height; the rest scrolls.
        return lead.concat(rest)
    }


    // Clipboard history, newest first (ordering is `ClipboardService`'s).
    function clipboard(term: string): var {
        const found = []
        for (const entry of ClipboardService.search(term, root.maxResults)) {
            found.push({
                kind: "clip", id: entry.key, icon: "󰅍",
                name: ClipboardService.title(entry),
                subtitle: ClipboardService.describe(entry),
                // Images show a thumbnail instead of a glyph, and can be
                // opened in imv.
                picture: entry.kind === "image" ? `file://${entry.file}` : "",
                file: entry.kind === "image" ? entry.file : ""
            })
        }
        return found
    }

    // Recent picks first when the term is empty; the glyph, in the chosen
    // skin tone, is the whole cell, and the name is only searched. Not cut to
    // `maxResults`: a group is browsed as much as searched, and the list only
    // builds the cells in view.
    function emoji(term: string): var {
        return EmojiService.search(term).map(item => ({
            kind: "emoji", id: item.glyph, icon: "", item: item,
            glyph: EmojiService.glyphOf(item), name: item.name, subtitle: ""
        }))
    }

    // Open windows filtered by title or class. The client list is loaded when
    // the launcher opens.
    function windows(term: string): var {
        const found = []
        for (const client of NiriService.clients) {
            if (found.length >= root.maxResults)
                break
            const title = (client.title ?? "").toLowerCase()
            const cls = (client.class ?? "").toLowerCase()
            if (term !== "" && !title.includes(term) && !cls.includes(term)
                    && FinderService.fuzzy(title, term) < 0 && FinderService.fuzzy(cls, term) < 0)
                continue
            found.push({
                kind: "window", id: client.address, icon: "󰖯", appIcon: client.class,
                name: client.title || client.class,
                subtitle: `${client.class}  ·  workspace ${client.workspace.id}`
            })
        }
        return found
    }

    function spell(milliseconds: real): string {
        const total = Math.round(milliseconds / 1000)
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        const seconds = total % 60
        const parts = []
        if (hours > 0) parts.push(`${hours}h`)
        if (minutes > 0) parts.push(`${minutes}m`)
        if (seconds > 0) parts.push(`${seconds}s`)
        return parts.join(" ") || "0s"
    }

    function evaluate(expression: string): var {
        try {
            const value = Function(`"use strict"; return (${expression})`)()
            return Number.isFinite(value) ? value : null
        } catch (error) {
            return null
        }
    }

    function activate(entry: var): void {
        if (!entry)
            return
        if (entry.kind === "app") {
            // Recorded here, not in `launchDesktop`, so dock launches do not
            // count towards the ranking.
            root.record(entry.id)
            root.launchDesktop(entry.id)
        }
        else if (entry.kind === "action") {
            const tile = ControlsService.tileOf(entry.id)
            if (tile)
                tile.activate()
        }
        else if (entry.kind === "theme")
            ThemeService.setTheme(entry.id)
        else if (entry.kind === "window")
            NiriService.focusWindow(entry.id)
        else if (entry.kind === "calculation")
            root.copy(entry.name)
        else if (entry.kind === "clip")
            ClipboardService.copy(entry.id)
        else if (entry.kind === "emoji")
            EmojiService.copy(entry.item)
        else if (entry.kind === "quicklink")
            FinderService.openLink(entry.link, entry.term)
        else if (entry.kind === "snippet")
            FinderService.paste(entry.text)
        else if (entry.kind === "file")
            FinderService.open(entry.id)
        else if (entry.kind === "bind" && entry.safe)
            root.runBind(entry.action)
        else if (entry.kind === "ssh")
            Quickshell.execDetached(["ghostty", "--gtk-single-instance=false", "-e", "ssh", entry.id])
        else if (entry.kind === "web")
            Quickshell.execDetached(["helium-browser", entry.id])
        // `panel` and `mode` entries are handled by the launcher panel: the
        // service does not know about the island, and a mode row keeps the
        // launcher open.
    }

    function copy(text: string): void {
        Quickshell.execDetached(["wl-copy", "--", text])
    }

    function launchDesktop(desktopId: string): void {
        if (!desktopId)
            return
        Quickshell.execDetached(["gtk-launch", desktopId])
    }
}
