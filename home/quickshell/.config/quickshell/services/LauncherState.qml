pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What the launcher remembers between opens (canvas note "Launcher family: flow": only history):
// app launches (frecency, recent row), calculator and command history, recent emoji, and when / where
// from each clipboard entry was copied (cliphist itself has no timestamps).
// Stored in ~/.local/state/glass-shell/launcher.json.
Singleton {
    id: root

    property alias launches: adapter.launches   // { appId: [ms, …] }, newest last
    property alias calc: adapter.calc           // [{ expr, result }], newest first
    property alias commands: adapter.commands   // [{ cmd, time }], newest first
    property alias emoji: adapter.emoji         // [glyph], newest first
    property alias clips: adapter.clips         // { cliphist id: { time, source } }

    readonly property real week: 7 * 24 * 3600 * 1000

    function recordLaunch(id: string) {
        const all = Object.assign({}, launches)
        all[id] = (all[id] ?? []).concat([Date.now()]).slice(-50)
        launches = all
    }
    function launchesThisWeek(id: string): int {
        const since = Date.now() - week
        return (launches[id] ?? []).filter(t => t > since).length
    }
    // Recent launches count more: this week ×1, this month ×0.5, older ×0.2.
    function frecency(id: string): real {
        const now = Date.now()
        return (launches[id] ?? []).reduce((s, t) => s + (now - t < week ? 1 : now - t < 4 * week ? 0.5 : 0.2), 0)
    }
    // App ids by last launch, newest first.
    function recentApps(n: int): var {
        return Object.keys(launches)
            .map(id => [id, launches[id][launches[id].length - 1] ?? 0])
            .sort((a, b) => b[1] - a[1]).slice(0, n).map(e => e[0])
    }

    function pushCalc(expr: string, result: string) {
        calc = [{ expr: expr, result: result }].concat(calc.filter(c => c.expr !== expr)).slice(0, 20)
    }
    function pushCommand(cmd: string) {
        commands = [{ cmd: cmd, time: Date.now() }].concat(commands.filter(c => c.cmd !== cmd)).slice(0, 30)
    }
    function pushEmoji(glyph: string) {
        emoji = [glyph].concat(emoji.filter(e => e !== glyph)).slice(0, 16)
    }
    // Forget entries cliphist no longer has.
    function pruneClips(ids: var) {
        const keep = new Set(ids), all = {}
        for (const id in clips) if (keep.has(id)) all[id] = clips[id]
        if (Object.keys(all).length !== Object.keys(clips).length) clips = all
    }

    // "4 min ago", "yesterday", "Mon", "3 days ago" (13-LauncherStates, 14-Modes).
    function ago(ms: real, weekday: bool): string {
        if (!ms) return ""
        const s = (Date.now() - ms) / 1000
        if (s < 60) return "just now"
        if (s < 3600) return Math.floor(s / 60) + " min ago"
        const d = new Date(ms), midnight = x => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime()
        const days = Math.round((midnight(new Date()) - midnight(d)) / 86400000)
        if (days === 0) return Math.floor(s / 3600) + " h ago"
        if (days === 1) return "yesterday"
        if (days < 7) return weekday ? Qt.formatDate(d, "ddd") : days + " days ago"
        return Qt.formatDate(d, "d MMM")
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/glass-shell/launcher.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: writeAdapter()   // first run: create the file

        JsonAdapter {
            id: adapter
            property var launches: ({})
            property var calc: []
            property var commands: []
            property var emoji: []
            property var clips: ({})
        }
    }
}
