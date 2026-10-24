import QtQuick
import Quickshell
import qs.services
import qs.components
import "../../components/fuzzy.js" as Fuzzy

// Apps mode (12-Launcher, 13-LauncherStates top row) and the ! web mode.
// · Just opened: Recent apps (← → move) and Suggestions ("Last copied: …" opens the clipboard mode).
// · Typing: Best match + its desktop action ("New private window", Shift+Enter), more Apps, then
//   "Search the web for …". The first row is pre-selected, so Super+Space, f, Enter launches.
// · No results: install with pacman, search the web, or run it in kitty (never a dead end).
Column {
    id: root

    property var launcher
    property string query
    readonly property bool web: launcher?.mode === "web"
    readonly property string q: query.trim()
    readonly property bool fresh: q === "" && !web
    readonly property var results: !web && q !== "" ? Apps.search(q).slice(0, 4) : []
    readonly property bool none: !web && q !== "" && results.length === 0
    readonly property bool showChips: results.length > 0

    readonly property var hints: fresh ? [["← →", "recent"], ["Enter", "open"], ["Tab", "next mode"]]
                                       : [["↑↓", "select"], ["Enter", "open"], ["Tab", "next mode"]]
    readonly property var trailingHints: fresh ? [] : [["Esc", "close"]]

    // Everything selectable, in order: { type, section?, entry?, action?, indices? }.
    readonly property var items: {
        if (web) return q === "" ? [] : [{ type: "web" }]
        if (fresh) return recents.map(e => ({ type: "tile", entry: e }))
                          .concat(Clipboard.entries.some(c => !c.pinned) ? [{ type: "lastCopied", section: "Suggestions" }] : [])
        if (none) return [{ type: "install" }, { type: "web" }, { type: "kitty" }]
        const best = results[0]
        if (!best) return []   // results catching up with the query
        const out = [{ type: "app", section: "Best match", entry: best.entry, indices: best.indices }]
        for (const a of (best.entry.actions ?? []).slice(0, 1))
            out.push({ type: "action", entry: best.entry, action: a, indices: Fuzzy.match(q, best.entry.name)?.indices ?? [] })
        results.slice(1).forEach((r, i) => out.push({ type: "app", section: i === 0 ? "Apps" : "", entry: r.entry, indices: r.indices }))
        out.push({ type: "web" })
        return out
    }
    // Up to 7 recent apps, topped up alphabetically on a fresh install.
    readonly property var recents: {
        const seen = LauncherState.recentApps(7).map(id => Apps.byId(id)).filter(e => e)
        const more = Apps.all.filter(e => !seen.includes(e)).sort((a, b) => a.name.localeCompare(b.name))
        return seen.concat(more).slice(0, 7)
    }
    readonly property int tiles: fresh ? recents.length : 0

    property int sel: 0
    onQueryChanged: sel = 0
    onWebChanged: sel = 0

    function activate(i: int, alt: bool) {
        const it = items[i]
        if (!it) return
        const url = Config.searchUrl + encodeURIComponent(q)
        switch (it.type) {
        case "tile":
        case "app": Apps.launch(it.entry); break
        case "action": Apps.launchAction(it.entry, it.action); break
        case "web": Quickshell.execDetached(["xdg-open", url]); break
        case "install": Quickshell.execDetached(["kitty", "-e", "sudo", "pacman", "-S"].concat(q.split(/\s+/))); break
        case "kitty": Quickshell.execDetached(["kitty", "--hold", "sh", "-c", q]); break
        case "lastCopied": launcher.setMode("clipboard"); return
        }
        launcher.close()
    }
    function jump(n: int) { if (n < items.length) activate(n, false) }

    function key(e: var): bool {
        const ctrl = e.modifiers & Qt.ControlModifier
        const down = e.key === Qt.Key_Down || (ctrl && e.key === Qt.Key_J)
        const up = e.key === Qt.Key_Up || (ctrl && e.key === Qt.Key_K)
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            if (e.modifiers & Qt.ShiftModifier) {
                // The alternative: the best match's action, or "run in kitty" when nothing matched.
                const alt = items.findIndex(it => it.type === "action" || it.type === "kitty")
                activate(alt !== -1 ? alt : sel, true)
            } else activate(sel, false)
            return true
        }
        if (fresh && sel < tiles && (e.key === Qt.Key_Left || e.key === Qt.Key_Right)) {
            sel = Math.max(0, Math.min(tiles - 1, sel + (e.key === Qt.Key_Left ? -1 : 1)))
            return true
        }
        if (down || up) {
            if (fresh) sel = down ? (sel < tiles ? tiles : sel + 1) : (sel <= tiles ? 0 : sel - 1)
            else sel += down ? 1 : -1
            sel = Math.max(0, Math.min(items.length - 1, sel))
            return true
        }
        return false
    }

    // --- Just opened: recent apps.
    SectionLabel {
        visible: root.fresh
        text: "Recent"
        above: Theme.px(14)
        below: Theme.px(7)
    }
    Row {
        visible: root.fresh
        x: Theme.px(4)
        spacing: Theme.px(6)
        Repeater {
            model: root.fresh ? root.recents : []
            Item {
                id: tile
                required property var modelData
                required property int index
                readonly property bool selected: root.sel === index
                width: Theme.px(84)
                height: Theme.px(52 + 7) + name.implicitHeight
                AppTile {
                    anchors.horizontalCenter: parent.horizontalCenter
                    app: tile.modelData
                    size: Theme.px(52)
                    iconSize: Theme.px(22)
                    scale: mouse.pressed ? 0.95 : mouse.containsMouse ? 1.04 : 1
                    Behavior on scale { NumberAnimation { duration: Motion.micro; easing.type: Motion.easeMicro } }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -2
                        radius: parent.radius + 2
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.accent
                        opacity: tile.selected ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Motion.micro } }
                    }
                }
                Text {
                    id: name
                    y: Theme.px(52 + 7)
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.modelData.name
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: Theme.px(11.5)
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.activate(tile.index, false)
                }
            }
        }
    }

    // --- No results: what you can do instead.
    Column {
        visible: root.none
        width: parent.width
        topPadding: Theme.px(22)
        bottomPadding: Theme.px(14)
        spacing: Theme.px(4)
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: `No app called “${root.q}”`
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.px(14.5)
            font.weight: Font.Medium
            elide: Text.ElideMiddle
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Here's what you can do instead"
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.px(11.5)
        }
    }

    // --- Rows.
    Item { width: 1; height: Theme.px(root.web && root.items.length > 0 ? 12 : 0) }
    Repeater {
        model: root.items
        Column {
            id: entry
            required property var modelData
            required property int index
            readonly property var it: modelData
            visible: it.type !== "tile"
            width: root.width

            SectionLabel {
                visible: (entry.it.section ?? "") !== ""
                text: entry.it.section ?? ""
                above: Theme.px(entry.index === 0 ? 12 : 10)
                below: Theme.px(entry.it.type === "lastCopied" ? 6 : 4)
            }
            ResultRow {
                readonly property var it: entry.it
                readonly property bool app: it.type === "app" || it.type === "action"
                readonly property string browser: Apps.defaultBrowser?.name ?? "your browser"
                compact: root.none || root.fresh
                selected: root.sel === entry.index
                onClicked: root.activate(entry.index, false)
                tile.app: app ? it.entry : null
                // No results (13): install on a green-ish tile, web on the warm one, kitty neutral.
                tile.neutral: !(app || it.type === "install" || (root.none && it.type === "web")) || it.type === "action"
                tile.tintIndex: it.type === "install" ? 1 : it.type === "web" ? 0 : -1
                tile.icon: it.type === "action" ? (/private|incognito/i.test(it.action.name) ? "eye-off" : "app-window")
                         : it.type === "web" ? (root.none ? "globe-line" : "search")
                         : it.type === "install" ? "download" : it.type === "kitty" ? "terminal"
                         : it.type === "lastCopied" ? "clipboard" : ""
                title: it.type === "app" ? it.entry.name
                     : it.type === "action" ? `${it.entry.name} · ${it.action.name}`
                     : it.type === "web" ? `Search the web for “${root.q}”`
                     : it.type === "install" ? `Install with pacman <span style="font-family:'${Theme.fontMono}'; font-size:${Theme.px(11.5)}px; color:${Theme.textFaint}">sudo pacman -S ${Fuzzy.escape(root.q)}</span>`
                     : it.type === "kitty" ? `Run “${root.q}” in kitty`
                     : it.type === "lastCopied" ? `Last copied: <span style="font-family:'${Theme.fontMono}'; font-size:${Theme.px(12)}px">${Fuzzy.escape((Clipboard.entries.find(c => !c.pinned)?.title ?? "").slice(0, 48))}</span>` : ""
                richTitle: it.type === "install" || it.type === "lastCopied"
                indices: it.indices ?? []
                subtitle: it.type === "app" ? Apps.subtitle(it.entry)
                        : it.type === "action" ? "App action"
                        : it.type === "web" && !root.none ? `Opens in ${browser}` : ""
                key: it.type === "lastCopied" ? ";"
                   : selected ? "Enter" : it.type === "action" ? "Shift Enter" : `Alt ${entry.index + 1}`
            }
        }
    }
}
