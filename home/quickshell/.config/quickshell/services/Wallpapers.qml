pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Wallpapers and their themes (DESIGN.md §3.6, §5.3; one wallpaper = one matugen theme).
// Browsing the switcher previews a palette without touching any file: Theme.preview gets it (a matugen
// --dry-run dump, made once per wallpaper), GlassSync moves Hyprland's border along, and kitty, which
// can't read our palette, is recoloured through matugen's preview.toml once browsing pauses.
// Enter runs the full pipeline (matugen config.toml: Quickshell, greeter, Hyprland, kitty, GTK, Qt) while
// Background ripples the new wallpaper in. Closing the switcher any other way reverts.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.local/share/wallpapers"
    // Same flags everywhere, so the preview palette is exactly what the full run writes.
    readonly property var flags: ["-m", "dark", "--prefer", "darkness"]

    property var items: []        // [{ file, path, name }] by file name
    property var palettes: ({})   // file → roles, keyed like colors.json
    property int selected: -1
    readonly property var selectedItem: items[selected] ?? null
    readonly property var selectedPalette: selectedItem ? palettes[selectedItem.file] ?? null : null

    // The applied wallpaper. colors.json holds the resolved path (into the repo), so match by file name.
    readonly property string appliedFile: Theme.wallpaper.split("/").pop()
    readonly property int appliedIndex: items.findIndex(i => i.file === appliedFile)

    // The ripple, played by Background on every screen; rippleId counts applies. rippleFrom is the
    // thumbnail's centre on rippleScreen ("" = each screen ripples from its bottom centre).
    property int rippleId: 0
    property string incoming: ""
    property string rippleScreen: ""
    property point rippleFrom
    property string pending: ""   // file being applied, until colors.json has it

    // Enter in the sheet and `qs ipc call wallpaper apply`; the sheet answers with the thumbnail's position.
    signal applyRequested()

    readonly property bool open: Shell.panel === "wallpaper"
    onOpenChanged: {
        if (open) {
            selected = Math.max(0, appliedIndex)
            computePalettes()
        } else if (pending === "") {
            revert()
        }
    }

    function nameOf(file: string): string {
        const base = file.replace(/\.[^.]+$/, "").replace(/^[\d\s_-]+/, "").replace(/[_-]+/g, " ")
        return base.charAt(0).toUpperCase() + base.slice(1)
    }

    function select(i: int) {
        if (i < 0 || i >= items.length) return
        selected = i
        preview()
    }
    function browse(step: int) { select(Math.max(0, Math.min(items.length - 1, selected + step))) }
    function random() {
        if (items.length < 2) return
        let i = Math.floor(Math.random() * (items.length - 1))
        if (i >= selected) i++
        select(i)
    }

    function preview() {
        if (!open || !selectedItem) return
        Theme.preview = selected === appliedIndex ? null : selectedPalette
        kittyTo(selectedItem.file)
    }
    function revert() {
        Theme.preview = null
        kittyTo(appliedFile)
    }

    function apply(from: point, screen: string) {
        const item = selectedItem
        if (!item) return
        if (item.file !== appliedFile) {
            pending = item.file
            incoming = item.path
            rippleFrom = from
            rippleScreen = screen
            rippleId++
            kittyShown = item.file   // the full run writes kitty too
            kittyWant = item.file
            applyProc.command = ["matugen", "image", item.path, ...flags, "--continue-on-error", "-q"]
            applyProc.running = true
        }
        Shell.close("wallpaper")
    }
    // Applies a wallpaper by name without the sheet (IPC); it ripples from the bottom centre.
    function applyNamed(name: string): bool {
        const i = items.findIndex(it => it.name.toLowerCase() === name.toLowerCase() || it.file === name)
        if (i < 0) return false
        selected = i
        apply(Qt.point(0, 0), "")
        return true
    }

    onAppliedFileChanged: if (pending !== "" && appliedFile === pending) done()
    function done() {
        pending = ""
        Theme.preview = null
    }
    Process {
        id: applyProc
        // colors.json is reloaded by Theme's file watch; if that never shows the new wallpaper (matugen
        // failed), stop previewing anyway so the shell shows the real theme.
        onExited: (code) => { if (root.pending !== "") giveUp.start() }
    }
    Timer {
        id: giveUp
        interval: 1500
        onTriggered: if (root.pending !== "") { Theme.reload(); root.done() }
    }

    // --- kitty preview: at most one matugen run at a time, the last wish wins.
    property string kittyShown: appliedFile
    property string kittyWant: ""
    function kittyTo(file: string) {
        kittyWant = file
        kittyTimer.restart()
    }
    Timer {
        id: kittyTimer
        interval: Motion.kittyPreview
        onTriggered: {
            const item = root.items.find(i => i.file === root.kittyWant)
            if (!item || root.kittyWant === root.kittyShown || kittyProc.running || applyProc.running) return
            root.kittyShown = item.file
            kittyProc.command = ["matugen", "-c", Quickshell.env("HOME") + "/.config/matugen/preview.toml",
                                 "image", item.path, ...root.flags, "-q"]
            kittyProc.running = true
        }
    }
    Process {
        id: kittyProc
        onExited: if (root.kittyWant !== root.kittyShown) kittyTimer.restart()
    }

    // --- Palettes: one matugen --dry-run per wallpaper (~130 ms), queued.
    property var queue: []
    function computePalettes() {
        queue = items.filter(i => !palettes[i.file]).map(i => i.file)
        nextPalette()
    }
    function nextPalette() {
        if (paletteProc.running || queue.length === 0) return
        const item = items.find(i => i.file === queue[0])
        queue = queue.slice(1)
        if (!item) return nextPalette()
        paletteProc.file = item.file
        paletteProc.command = ["matugen", "image", item.path, ...flags, "--dry-run", "-j", "hex", "-q"]
        paletteProc.running = true
    }
    Process {
        id: paletteProc
        property string file
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const colors = JSON.parse(text).colors
                    const roles = {}
                    for (const k in colors) roles[k] = colors[k].default.color
                    const p = Object.assign({}, root.palettes)
                    p[paletteProc.file] = roles
                    root.palettes = p
                    if (root.selectedItem?.file === paletteProc.file) root.preview()
                } catch (e) {
                    console.warn("Wallpapers: no palette for", paletteProc.file, e)
                }
            }
        }
        onExited: Qt.callLater(root.nextPalette)
    }

    FolderListModel {
        id: folder
        folder: "file://" + root.dir
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
        sortField: FolderListModel.Name
        onStatusChanged: if (status === FolderListModel.Ready) root.rebuild()
        onCountChanged: root.rebuild()
    }
    function rebuild() {
        const list = []
        for (let i = 0; i < folder.count; i++) {
            const file = folder.get(i, "fileName")
            list.push({ file: file, path: folder.get(i, "filePath"), name: nameOf(file) })
        }
        const keep = selectedItem?.file
        items = list
        selected = keep ? Math.max(0, list.findIndex(i => i.file === keep)) : selected
        computePalettes()
    }
}
