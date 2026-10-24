import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "../../components/fuzzy.js" as Fuzzy

// Files mode (/ prefix, 13-LauncherStates "Files"): fd searches ~ (respecting .gitignore, hidden folders
// included) 150 ms after the last key; best name match first, then the most recently edited.
// Enter opens, Ctrl+Enter opens the folder, Ctrl+C copies the path.
Column {
    id: root

    property var launcher
    property string query
    readonly property string q: query.trim()
    readonly property string home: Quickshell.env("HOME")
    property var files: []   // [{ path, name, dir, mtime, indices }]
    property int sel: 0
    readonly property bool showChips: false
    readonly property var hints: [["Enter", "open"], ["Ctrl Enter", "open folder"], ["Ctrl C", "copy path"]]
    readonly property var trailingHints: []

    onQChanged: { sel = 0; debounce.restart() }

    function tilde(p: string): string { return p.startsWith(home) ? "~" + p.slice(home.length) : p }

    function activate(i: int, folder: bool) {
        const f = files[i]
        if (!f) return
        Quickshell.execDetached(["xdg-open", folder ? f.dir : f.path])
        launcher.close()
    }
    function jump(n: int) { activate(n, false) }

    function key(e: var): bool {
        const ctrl = e.modifiers & Qt.ControlModifier
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { activate(sel, ctrl); return true }
        if (ctrl && e.key === Qt.Key_C && files[sel]) {
            Quickshell.execDetached(["wl-copy", "--", files[sel].path])
            launcher.close()
            return true
        }
        const down = e.key === Qt.Key_Down || (ctrl && e.key === Qt.Key_J)
        const up = e.key === Qt.Key_Up || (ctrl && e.key === Qt.Key_K)
        if (down || up) { sel = Math.max(0, Math.min(files.length - 1, sel + (down ? 1 : -1))); return true }
        return false
    }

    Timer {
        id: debounce
        interval: 150
        onTriggered: {
            fd.running = false
            if (root.q === "") { root.files = []; return }
            // Hidden folders too (dotfiles live in ~/.config), minus caches, trash and .git.
            fd.command = ["sh", "-c", 'fd -i -F -H --type f --max-results 80 -E .git -E .cache -E Trash -E .mozilla -E .librewolf -0 -- "$1" "$HOME" | xargs -0 -r stat -c "%Y\t%n"', "sh", root.q]
            fd.running = true
        }
    }
    Process {
        id: fd
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const [t, path] = [l.slice(0, l.indexOf("\t")), l.slice(l.indexOf("\t") + 1)]
                    const name = path.slice(path.lastIndexOf("/") + 1), dir = path.slice(0, path.lastIndexOf("/") + 1)
                    const m = Fuzzy.match(root.q, name)
                    return { path: path, name: name, dir: dir, mtime: Number(t) * 1000, indices: m?.indices ?? [], score: m?.score ?? 0 }
                })
                // Name match in bands of 10, then newest first.
                found.sort((a, b) => Math.floor(b.score / 10) - Math.floor(a.score / 10) || b.mtime - a.mtime)
                root.files = found.slice(0, 6)
            }
        }
    }

    Item { width: 1; height: Theme.px(8) }

    Text {
        visible: root.q !== "" && root.files.length === 0 && !fd.running && !debounce.running
        width: parent.width
        topPadding: Theme.px(14)
        bottomPadding: Theme.px(10)
        horizontalAlignment: Text.AlignHCenter
        text: `No file called “${root.q}” in ~`
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.px(12.5)
    }

    Repeater {
        model: root.files
        ResultRow {
            required property var modelData
            required property int index
            compact: true
            implicitHeight: Theme.px(index === 0 ? 46 : 52)
            selected: root.sel === index
            onClicked: root.activate(index, false)
            tile.icon: "file"
            tile.neutral: !selected
            tile.tintIndex: 2
            title: modelData.name
            indices: modelData.indices
            subtitle: root.tilde(modelData.dir)
            monoSubtitle: true
            note: "edited " + LauncherState.ago(modelData.mtime, false)
        }
    }
}
