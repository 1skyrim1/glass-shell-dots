pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../components/apps.js" as AppIcons

// Clipboard history (; mode, 14-Modes) on top of cliphist. Hyprland's conf/session.lua runs
// `wl-paste --watch sh -c 'cliphist store; qs ipc call clipboard stored'`, so stored() sees every copy
// and notes when and where from it came (cliphist keeps neither).
// Pins live outside cliphist (its ids change when something is copied again): each pinned entry is a
// file in ~/.local/state/glass-shell/clip-pins/ plus a line in index.json there.
Singleton {
    id: root

    // [{ id, preview, kind, title, sub, time, source, pinned, file, size }]: pins first, then newest first.
    property var entries: []
    property var pins: []
    property var raw: []   // [{ id, preview }] from the last `cliphist list`

    readonly property string pinDir: Quickshell.env("HOME") + "/.local/state/glass-shell/clip-pins"
    readonly property string cacheDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/glass-shell/clip"

    // A refresh asked for while `cliphist list` still runs (copies in quick succession) runs right after.
    function refresh() { if (list.running) list.again = true; else list.running = true }

    function stored() {
        pendingSource = sourceName()
        refresh()
    }
    property string pendingSource: ""

    function sourceName(): string {
        const cls = AppIcons.classOf(Hyprland.activeToplevel)
        if (!cls) return ""
        return DesktopEntries.heuristicLookup(cls)?.name ?? cls
    }

    // What an entry is, from cliphist's one-line preview.
    function classify(preview: string): var {
        const img = preview.match(/^\[\[ binary data (.+?) (png|jpe?g|webp|gif|bmp) (\d+)x(\d+) \]\]$/)
        if (img) return { kind: "image", title: "Image", sub: `image · ${img[3]}×${img[4]}`, ext: img[2] }
        if (/^\[\[ binary data/.test(preview)) return { kind: "file", title: "Binary data", sub: "data" }
        const t = preview.trim()
        if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(t)) return { kind: "colour", title: t.toUpperCase(), sub: "colour", swatch: t }
        // The colour picker's other formats (Capture: rgb(230 182 255), hsl(279 100% 86%)).
        const rgb = t.match(/^rgba?\(\s*(\d+)[\s,]+(\d+)[\s,]+(\d+)\s*\)$/)
        if (rgb) return { kind: "colour", title: t, sub: "colour", swatch: Qt.rgba(rgb[1] / 255, rgb[2] / 255, rgb[3] / 255, 1) }
        const hsl = t.match(/^hsla?\(\s*(\d+)[\s,]+(\d+)%[\s,]+(\d+)%\s*\)$/)
        if (hsl) return { kind: "colour", title: t, sub: "colour", swatch: Qt.hsla(hsl[1] / 360, hsl[2] / 100, hsl[3] / 100, 1) }
        if (/^(https?:\/\/|www\.)\S+$/.test(t)) return { kind: "link", title: t.replace(/^https?:\/\/(www\.)?/, ""), sub: "link" }
        const codey = (t.match(/[{}()\[\];=<>"'`]/g) ?? []).length
        if (codey >= 4 || /^(import|local|function|def|const|let|var|class|#include|fn|pub)\b/.test(t))
            return { kind: "code", title: t, sub: "code" }
        return { kind: "text", title: t, sub: "text" }
    }

    function rebuild() {
        const pinnedPreviews = new Set(pins.map(p => p.preview))
        const fromPins = pins.map(p => {
            const c = classify(p.preview)
            return Object.assign(c, { id: "", preview: p.preview, time: p.time, source: p.source ?? "", pinned: true, file: p.file,
                                      title: c.kind === "image" ? "Image " + Qt.formatTime(new Date(p.time), "HH:mm") : c.title })
        })
        const fromHistory = raw.filter(r => !pinnedPreviews.has(r.preview)).map(r => {
            const c = classify(r.preview), meta = LauncherState.clips[r.id] ?? {}
            return Object.assign(c, { id: r.id, preview: r.preview, time: meta.time ?? 0, source: meta.source ?? "", pinned: false, file: "",
                                      title: c.kind === "image" && meta.time ? "Image " + Qt.formatTime(new Date(meta.time), "HH:mm") : c.title })
        })
        entries = fromPins.concat(fromHistory)
    }
    onPinsChanged: rebuild()
    Connections {
        target: LauncherState
        function onClipsChanged() { root.rebuild() }
    }

    // --- Actions. Paste and copy go through wl-copy; paste then presses Ctrl+V (Ctrl+Shift+V in a
    // terminal) once the launcher has handed the keyboard back.
    function copy(e: var, done: var) {
        if (e.pinned) sh(`wl-copy ${e.kind === "image" ? "-t image/png" : ""} < "$1"`, [e.file], done)
        else sh(`cliphist decode "$1" | wl-copy`, [e.id], done)
    }
    // Presses paste once the clipboard holds the entry and the window has the keyboard back.
    function paste(e: var) {
        const terminal = AppIcons.iconFor(AppIcons.classOf(Hyprland.activeToplevel)) === "terminal"
        copy(e, () => sh(`sleep 0.2; wtype ${terminal ? "-M ctrl -M shift -k v -m shift -m ctrl" : "-M ctrl -k v -m ctrl"}`, []))
    }
    function remove(e: var) {
        if (e.pinned) unpin(e)
        if (e.id !== "") sh(`printf '%s\\t%s\\n' "$1" "$2" | cliphist delete`, [e.id, e.preview], () => refresh())
        else refresh()
    }
    function togglePin(e: var) { e.pinned ? unpin(e) : pin(e) }
    function pin(e: var) {
        const file = `${pinDir}/${Date.now()}.${e.kind === "image" ? "png" : "txt"}`
        sh(`mkdir -p "$(dirname "$2")" && cliphist decode "$1" > "$2"`, [e.id, file], () => {
            pins = [{ file: file, preview: e.preview, time: e.time || Date.now(), source: e.source }].concat(pins)
            savePins()
        })
    }
    function unpin(e: var) {
        sh(`rm -f "$1"`, [e.file])
        pins = pins.filter(p => p.file !== e.file)
        savePins()
    }
    function savePins() { pinIndex.setText(JSON.stringify(pins, null, 1)) }

    // Full content for the preview pane: text (first 4 kB) or an image file path.
    property var preview: ({ text: "", image: "", lines: 0 })
    function load(e: var) {
        if (!e) { preview = { text: "", image: "", lines: 0 }; return }
        if (e.kind === "image") {
            if (e.pinned) { preview = { text: "", image: e.file, lines: 0 }; return }
            const f = `${cacheDir}/${e.id}.png`
            sh(`mkdir -p "$(dirname "$2")"; [ -s "$2" ] || cliphist decode "$1" > "$2"`, [e.id, f], () => {
                preview = { text: "", image: f, lines: 0 }
            })
            return
        }
        loader.want = e.pinned ? e.file : e.id
        loader.command = e.pinned ? ["head", "-c", "4000", e.file] : ["sh", "-c", `cliphist decode "$1" | head -c 4000`, "sh", e.id]
        loader.running = true
    }

    // Runs a shell snippet with arguments ($1, $2, …), then `done`.
    function sh(script: string, args: var, done: var) {
        const p = runner.createObject(root, { command: ["sh", "-c", script, "sh"].concat(args) })
        p.exited.connect(() => { if (done) done(); p.destroy() })
        p.running = true
    }
    Component {
        id: runner
        Process {}
    }

    Process {
        id: list
        property bool again: false
        command: ["cliphist", "list"]
        onExited: if (again) { again = false; running = true }
        stdout: StdioCollector {
            onStreamFinished: {
                const old = root.raw
                root.raw = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const i = l.indexOf("\t")
                    return { id: l.slice(0, i), preview: l.slice(i + 1) }
                })
                // Fresh copies have no meta yet; the newest came from the window that had focus. Something
                // copied again keeps where it first came from.
                const fresh = {}
                root.raw.filter(r => !LauncherState.clips[r.id]).forEach((r, i) => {
                    const before = old.find(o => o.preview === r.preview && o.id !== r.id)
                    const was = before ? LauncherState.clips[before.id] : null
                    fresh[r.id] = { time: Date.now(), source: was?.source || (r === root.raw[0] ? root.pendingSource : "") }
                })
                if (Object.keys(fresh).length > 0) LauncherState.clips = Object.assign({}, LauncherState.clips, fresh)
                root.pendingSource = ""
                LauncherState.pruneClips(root.raw.map(r => r.id))
                root.rebuild()
            }
        }
    }

    Process {
        id: loader
        property string want: ""
        stdout: StdioCollector {
            onStreamFinished: root.preview = { text: text, image: "", lines: text.replace(/\n$/, "").split("\n").length }
        }
    }

    FileView {
        id: pinIndex
        path: root.pinDir + "/index.json"
        printErrors: false
        onLoaded: { try { root.pins = JSON.parse(text()) } catch (e) { root.pins = [] } }
        onSaveFailed: root.sh(`mkdir -p "$1"`, [root.pinDir], () => pinIndex.setText(JSON.stringify(root.pins, null, 1)))
    }

    Component.onCompleted: refresh()
}
