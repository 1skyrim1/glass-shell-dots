pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../components/fuzzy.js" as Fuzzy

// Installed apps (desktop entries) for the launcher's Apps mode: fuzzy search ranked with frecency,
// launching (recorded in LauncherState), and their desktop actions ("New private window").
Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    function byId(id: string): var { return all.find(e => e.id === id) ?? null }

    // The default browser's entry ("Opens in LibreWolf").
    property var defaultBrowser: null
    Process {
        running: true
        command: ["xdg-settings", "get", "default-web-browser"]
        stdout: StdioCollector {
            onStreamFinished: root.defaultBrowser = DesktopEntries.byId(text.trim().replace(/\.desktop$/, ""))
        }
    }

    // [{ entry, indices, score }], best first. The name match gives the highlighted letters; generic
    // name, keywords and comment count less and highlight nothing.
    function search(query: string): var {
        const out = []
        for (const e of all) {
            const m = Fuzzy.match(query, e.name)
            let best = m ? { score: m.score, indices: m.indices } : null
            for (const other of [e.genericName, (e.keywords ?? []).join(" "), e.id]) {
                const o = Fuzzy.match(query, other)
                if (o && o.score >= 60 && (!best || o.score * 0.6 > best.score)) best = { score: o.score * 0.6, indices: [] }
            }
            if (!best) continue
            out.push({ entry: e, indices: best.indices, score: best.score + Math.min(20, 4 * Math.log2(1 + LauncherState.frecency(e.id))) })
        }
        return out.sort((a, b) => b.score - a.score)
    }

    // "Web browser · opened 12 times this week"
    function subtitle(e: var): string {
        const what = e.genericName || e.comment || ""
        const n = LauncherState.launchesThisWeek(e.id)
        const opened = n > 1 ? `opened ${n} times this week` : ""
        return [what, opened].filter(s => s !== "").join(" · ")
    }

    function launch(e: var) {
        LauncherState.recordLaunch(e.id)
        if (e.runInTerminal)
            Quickshell.execDetached({ command: ["kitty", "-e"].concat(e.command), workingDirectory: e.workingDirectory })
        else
            e.execute()
    }
    function launchAction(e: var, action: var) {
        LauncherState.recordLaunch(e.id)
        action.execute()
    }
}
